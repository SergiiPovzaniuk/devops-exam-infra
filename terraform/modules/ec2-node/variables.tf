variable "name" { type = string }
variable "role" { type = string }
variable "ami_id" { type = string }
variable "instance_type" { type = string }
variable "subnet_id" { type = string }
variable "security_group_ids" { type = list(string) }
variable "key_name" { type = string }
variable "volume_size" {
  type    = number
  default = 20
}
variable "iam_instance_profile" {
  type    = string
  default = null
}
variable "tags" {
  type    = map(string)
  default = {}
}