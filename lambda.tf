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
  bucket = "dnsdetectives-lambda-code-bucket"
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
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_lambda_function" "dnsdetectives_lambda_function" {
  function_name = "dnsdetectives_lambda_function"
  s3_bucket     = "dnsdetectives-lambda-code-bucket"
  s3_key        = aws_s3_object.lambda_code.key
  handler       = "lambda.handler"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_execution_role.arn

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

resource "aws_security_group" "dnsdetectives_lambda_sg" {
  vpc_id = aws_vpc.dnsdetectives_vpc.id
  name   = "dnsdetectives-lambda-sg"

  # Wide outbound rules to allow Lambda to access other services
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 signifies all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "allow_lambda_to_rds" {
  type                     = "ingress"
  from_port                = 5432 # PostgreSQL default port
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.dnsdetectives_security_group.id
  source_security_group_id = aws_security_group.dnsdetectives_lambda_sg.id
}
