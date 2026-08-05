variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "state_bucket_name" {
  type = string
}

variable "lock_table_name" {
  type    = string
  default = "devops-exam-tf-lock"
}

variable "tags" {
  type = map(string)
  default = {
    Project = "devops-exam"
  }
}