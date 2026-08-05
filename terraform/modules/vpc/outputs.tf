output "vpc_id" { value = aws_vpc.this.id }
output "subnet_id" { value = aws_subnet.public.id }
output "cidr" { value = aws_vpc.this.cidr_block }