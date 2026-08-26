resource "aws_iam_role" "ec2_cloudwatch_logs"{
    name = "2tier-ec2-cloudwatch-role"

    assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "2tier-ec2-cloudwatch-role"
    Project = "2tier"
}
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role = aws_iam_role.ec2_cloudwatch_logs.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_cloudwatch_profile" {
  name = "2-tier"
  role = aws_iam_role.ec2_cloudwatch_logs.name
}