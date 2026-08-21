resource "aws_autoscaling_group" "asg" {
  desired_capacity = 2
  min_size         = 2
  max_size         = 4

  vpc_zone_identifier = [aws_subnet.private-1.id, aws_subnet.private-2.id]

  target_group_arns = [aws_lb_target_group.target.arn]

  launch_template {
    id      = aws_launch_template.template.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "2-tier-asg"
    propagate_at_launch = true
  }
}
