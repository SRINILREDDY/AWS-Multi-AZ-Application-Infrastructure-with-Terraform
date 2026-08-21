resource "aws_launch_template" "template" {
  image_id               = "ami-0ac7b260cf76d8865"
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.app_sg.id]

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