terraform {
  backend "s3" {
    bucket = "srinil-539"
    key    = "terraform.state"
    region = "ap-south-1"
  }
}
