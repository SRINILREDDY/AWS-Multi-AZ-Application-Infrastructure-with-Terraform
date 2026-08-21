output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "vpc_id" {
  value = aws_vpc.tier-2.id
}

output "public-1" {
  value = aws_subnet.public-1.id
}

output "public-2" {
  value = aws_subnet.public-2.id
}

output "private-1" {
  value = aws_subnet.private-1.id
}

output "private-2" {
  value = aws_subnet.private-2.id
}