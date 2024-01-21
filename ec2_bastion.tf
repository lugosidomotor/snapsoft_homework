# Data source for the latest Ubuntu AMI
data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# IAM Role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "${var.company}-${var.environment}-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach the SSM policy to the role
resource "aws_iam_role_policy_attachment" "ssm_role_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# Instance profile for SSM
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "${var.company}-${var.environment}-ssm-instance-profile"
  role = aws_iam_role.ssm_role.name
}

# Security Group for EC2 Bastion
resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.vpc.id
  name   = "${var.company}-${var.environment}-bastion-sg"

  # Ingress rule for SSM (HTTPS)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider narrowing this down to AWS SSM service IPs if possible
  }

  # Egress rule to RDS
  egress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_group_id = aws_security_group.rds_sg.id
  }

  # Egress rule for SSM (HTTPS)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Consider narrowing this down to AWS SSM service IPs if possible
  }
}

# Allow Bastion to access RDS
resource "aws_security_group_rule" "bastion_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.bastion_sg.id
}

# EC2 Bastion Instance
resource "aws_instance" "bastion" {
  ami                     = data.aws_ami.latest_ubuntu.id
  instance_type           = "t3.nano"
  key_name                = "${var.company}-${var.environment}-key-pair" # Replace with your key pair name
  security_groups         = [aws_security_group.bastion_sg.name]
  iam_instance_profile    = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update
                sudo apt install -y snapd
                sudo snap install amazon-ssm-agent --classic
                sudo systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
                sudo systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
              EOF

  tags = {
    Name = "${var.company}-${var.environment}-bastion"
  }
}
