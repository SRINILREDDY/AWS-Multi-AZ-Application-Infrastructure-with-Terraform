variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "project_name" {
  description = "2_tier architecture with github actions"
  type        = string
  default     = "2_tier"
}

variable "db_username" {
  description = "Master username for RDS MySQL. Use the existing username when managing an existing database."
  type        = string
  default     = "admin"
}
