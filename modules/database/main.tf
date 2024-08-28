# DB Subnet Group for RDS
# Defines a DB subnet group to specify which subnets the RDS instance can be deployed in
resource "aws_db_subnet_group" "db_subnet" {
  name       = "db_subnet_group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "DB Subnet Group"
  }
}


# RDS PostgreSQL Instance
# Creates an Amazon RDS PostgreSQL instance for tenant-specific data storage
resource "aws_db_instance" "postgres_instance" {
  identifier             = var.db_name
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = "db.t3.micro"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.id
  skip_final_snapshot    = true
  tags = {
    Name = "Tenant-PostgresDB"
  }
}


# Security Group for RDS
# Restricts access to the RDS instance, only allowing traffic from Lambda security group
resource "aws_security_group" "rds_sg" {
  name   = "rds_sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.db_lambda_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "RDS Security Group"
  }
}

# Security Group for Lambda
# Allows Lambda function to make outbound connections to the RDS instance
resource "aws_security_group" "db_lambda_sg" {
  name   = "db_lambda_sg"
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "Lambda Security Group"
  }
}

# Lambda Function Definition
# Defines a Lambda function to interact with the RDS instance
# Lambda function
resource "aws_lambda_function" "db_query_function" {
  filename         = "${path.module}/database_lambda_function.zip"
  function_name    = "rdsSetupAndTestFunction"
  role             = aws_iam_role.db_lambda_exec.arn
  timeout          = 30
  handler          = "database_lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("${path.module}/database_lambda_function.zip")

  environment {
    variables = {
      DB_SECRET_NAME = aws_secretsmanager_secret.db_credentials.name
      DB_HOST        = aws_db_instance.postgres_instance.address
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.db_lambda_sg.id]
  }

  tags = {
    Name = "DB setup and Query function"
  }
}

# IAM Role for Lambda Execution
# Grants necessary permissions for the Lambda function to interact with AWS services
resource "aws_iam_role" "db_lambda_exec" {
  name = "db_lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}



# IAM Policy Attachment for Lambda
# Associates an IAM policy that allows the Lambda function to execute
resource "aws_iam_role_policy_attachment" "lambda_exec_policy" {
  role       = aws_iam_role.db_lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}


# Secrets Manager - Store DB Credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "postgresql_cred"
  recovery_window_in_days = 0

}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    dbname   = var.db_name
  })
}

# IAM Policy for Secrets Access
resource "aws_iam_policy" "lambda_secrets_access" {
  name = "lambda_secrets_access"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "secretsmanager:GetSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:UpdateSecret"
      ],
      "Resource": [
        "${aws_secretsmanager_secret.db_credentials.arn}"
      ]
    }
  ]
}
EOF
}
# Attach RDS access policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_rds_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
  role       = aws_iam_role.db_lambda_exec.name
}
# Attach Secrets Manager access policy to Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_secrets_policy_attachment" {
  role       = aws_iam_role.db_lambda_exec.name
  policy_arn = aws_iam_policy.lambda_secrets_access.arn
}