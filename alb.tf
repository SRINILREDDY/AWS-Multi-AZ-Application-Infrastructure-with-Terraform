resource "aws_lb_target_group" "target" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.tier-2.id

  health_check {
    path = "/"
  }
}

resource "aws_lb" "alb" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]

  subnets = [aws_subnet.public-1.id,
  aws_subnet.public-2.id]

  tags = {
    Name = "alb"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target.arn
    type             = "forward"
  }

}