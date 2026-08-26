resource "aws_launch_template" "template" {
  image_id               = "ami-06a8e57e305a2d159"
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_sg.id]

iam_instance_profile {
  name = aws_iam_instance_profile.ec2_cloudwatch_profile.name
}
  user_data = base64encode(<<-EOF
    #!/bin/bash

    dnf update -y
    dnf install -y httpd

    systemctl enable httpd
    systemctl start httpd

    echo "<h1>2-Tier AWS Website</h1>" > /var/www/html/index.html
    echo "<p>Server: $(hostname)</p>" >> /var/www/html/index.html
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "2-tier-app"
    }
  }
}