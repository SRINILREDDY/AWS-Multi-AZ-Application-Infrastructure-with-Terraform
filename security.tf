#alb
resource "aws_security_group" "alb_sg" {
  vpc_id      = aws_vpc.tier-2.id
  description = "allow from internet only http and https"

  tags = {
    Name = "alb_sg"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#app-sg
resource "aws_security_group" "app_sg" {
  vpc_id      = aws_vpc.tier-2.id
  description = "allow from alb security group only"

  tags = {
    Name = "app_sg"
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#db -sg

resource "aws_security_group" "db_sg" {
  vpc_id      = aws_vpc.tier-2.id
  description = "allow from app-sg only"

  tags = {
    Name = "db_sg"
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

