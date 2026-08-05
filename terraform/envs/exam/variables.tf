variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "project" {
  type    = string
  default = "devops-exam"
}

variable "az" {
  type    = string
  default = "eu-central-1a"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  type    = string
  default = "devops-exam"
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/devops-exam.pub"
}

variable "ssh_cidr" {
  type        = string
  description = "Your public IP/CIDR for SSH and K8s API"
  default     = "0.0.0.0/0"
}

variable "monitoring_cidr" {
  type        = string
  description = "CIDR of monitoring host that scrapes metrics"
  default     = "192.168.32.80/32"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "devops-exam"
    Managed = "terraform"
  }
}