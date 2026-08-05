terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "devops-exam-tfstate-646819876267"
    key            = "exam/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "devops-exam-tf-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "vpc" {
  source              = "../../modules/vpc"
  name                = var.project
  cidr                = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  az                  = var.az
  tags                = var.tags
}

resource "aws_security_group" "k8s" {
  name        = "${var.project}-k8s"
  description = "kubeadm cluster"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "K8s API"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "NodePort app"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Node exporter / metrics from monitoring"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_cidr]
  }

  ingress {
    description = "kubelet metrics"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_cidr, module.vpc.cidr]
  }

  ingress {
    description = "intra-cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-k8s-sg" })
}

resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

module "control_plane" {
  source             = "../../modules/ec2-node"
  name               = "${var.project}-cp"
  role               = "control-plane"
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.subnet_id
  security_group_ids = [aws_security_group.k8s.id]
  key_name           = aws_key_pair.this.key_name
  volume_size        = 25
  tags               = var.tags
}

module "worker" {
  source             = "../../modules/ec2-node"
  count              = 2
  name               = "${var.project}-w${count.index + 1}"
  role               = "worker"
  ami_id             = data.aws_ami.ubuntu.id
  instance_type      = var.instance_type
  subnet_id          = module.vpc.subnet_id
  security_group_ids = [aws_security_group.k8s.id]
  key_name           = aws_key_pair.this.key_name
  volume_size        = 20
  tags               = var.tags
}