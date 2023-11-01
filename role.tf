resource "aws_iam_role" "rds_lambda_role" {
  name               = "rds-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "rds.amazonaws.com"
        },
        Action    = "sts:AssumeRole"
      },
    ]
  })
}
