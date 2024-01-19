resource "null_resource" "zip_lambda_function" {
  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}
      zip -r lambda.zip lambda.js node_modules
    EOT
  }
}

resource "aws_s3_object" "lambda_code" {
  bucket = "${var.company}-${var.environment}-lambda-code-bucket"
  key    = "lambda-${timestamp()}.zip"
  source = "${path.module}/lambda.zip"

  depends_on = [null_resource.zip_lambda_function]
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "${lower(var.company)}-${lower(var.environment)}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
    }]
  })
}

resource "aws_iam_role_policy" "lambda_vpc_access" {
  name = "${var.company}_${var.environment}_lambda_vpc_access"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.company}_${var.environment}_lambda_function"
  s3_bucket     = "${var.company}-${var.environment}-lambda-code-bucket"
  s3_key        = aws_s3_object.lambda_code.key
  handler       = "lambda.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_execution_role.arn

  environment {
    variables = {
      DB_HOST     = aws_db_instance.db_instance.address
      DB_DATABASE = aws_db_instance.db_instance.db_name
      DB_PASSWORD = aws_db_instance.db_instance.password
      DB_USERNAME = aws_db_instance.db_instance.username
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  depends_on = [null_resource.zip_lambda_function]
}

resource "aws_security_group" "lambda_sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "${var.company}-${var.environment}-lambda-sg"

  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.rds_sg.id]
  }
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*/${var.company}-path"
}

resource "aws_lambda_invocation" "test_lambda" {
  function_name = aws_lambda_function.lambda_function.function_name
  input = jsonencode({
    message = "secret message",
    target  = "google.com"
  })

  depends_on = [aws_lambda_function.lambda_function]
}
