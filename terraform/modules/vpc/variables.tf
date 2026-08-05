variable "name" { type = string }
variable "cidr" { type = string }
variable "public_subnet_cidr" { type = string }
variable "az" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}