output "vpc_id" {
  description = "id of my vpc"
  value       = aws_vpc.my_vpc.id
}

output "gateway_id" {
  description = "id of my internet gateway"
  value       = aws_internet_gateway.igw.id
}

output "public_route_table_id" {
  description = "id of my public route table"
  value       = aws_route_table.public_route.id
}

output "public_subnet_id" {
  description = "id of my public subnet"
  value       = aws_subnet.public_subnet[*].id
}

output "elastic_ip_id" {
  description = "id of my elastic IP"
  value       = aws_eip.ngw_eip[*].id
}

output "ngw_id" {
  description = "id of my nat gateway"
  value       = aws_nat_gateway.ngw[*].id
}

output "private_route_table_id" {
  description = "id of my private route table"
  value       = aws_route_table.private_route[*].id
}

output "private_subnet_id" {
  description = "id of my private subnet"
  value       = aws_subnet.private_subnet[*].id
}

output "security_group_id" {
  description = "id of my security group"
  value       = aws_security_group.security-group.id
}


