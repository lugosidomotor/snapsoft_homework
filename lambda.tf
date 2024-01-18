resource "aws_s3_bucket" "lambda_code_bucket" {
  bucket = "dnsdetectives-lambda-code"
  // Removed ACL configuration
}

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
  bucket = aws_s3_bucket.lambda_code_bucket.bucket
  key    = "lambda-${timestamp()}.zip"
  source = "${path.module}/lambda.zip"

  depends_on = [null_resource.zip_lambda_function]
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "dnsdetectives_lambda_execution_role"

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
  name = "dnsdetectives_lambda_vpc_access"
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
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "dnsdetectives_lambda_function" {
  function_name    = "dnsdetectives_lambda_function"
  s3_bucket        = aws_s3_bucket.lambda_code_bucket.bucket
  s3_key           = aws_s3_object.lambda_code.key
  handler          = "lambda.handler"
  runtime          = "nodejs18.x"
  role             = aws_iam_role.lambda_execution_role.arn

  environment {
    variables = {
      DB_HOST     = aws_db_instance.dnsdetectives_db.address
      DB_DATABASE = aws_db_instance.dnsdetectives_db.db_name
      DB_PASSWORD = aws_db_instance.dnsdetectives_db.password
      DB_USERNAME = aws_db_instance.dnsdetectives_db.username
    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.dnsdetectives_subnet1.id, aws_subnet.dnsdetectives_subnet2.id]
    security_group_ids = [aws_security_group.dnsdetectives_lambda_sg.id]
  }

  depends_on = [null_resource.zip_lambda_function]
}
