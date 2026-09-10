resource "aws_db_subnet_group" "mysql" {
  name = "mysql_subnet"

  subnet_ids = [
    aws_subnet.private-3.id,
    aws_subnet.private-4.id
  ]

  tags = {
    Name = "mysql"
  }
}

resource "aws_db_instance" "database" {
  identifier = "project"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"
  multi_az = true

  allocated_storage = 20
  storage_type      = "gp3"

  db_subnet_group_name = aws_db_subnet_group.mysql.name

  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]

  manage_master_user_password = true

  skip_final_snapshot = true
  publicly_accessible = false

  tags = {
    Name = "project-db"
  }
}