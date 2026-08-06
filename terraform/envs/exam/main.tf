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
    description     = "NodePort app from NLB"
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
  }

  ingress {
    description = "NodePort app debug"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Node exporter / metrics from monitoring"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_cidr]
  }

  ingress {
    description = "Loki NodePort for Grafana"
    from_port   = 31000
    to_port     = 31000
    protocol    = "tcp"
    cidr_blocks = [var.monitoring_cidr, var.ssh_cidr]
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

resource "aws_security_group" "nlb" {
  name        = "${var.project}-nlb"
  description = "NLB frontend"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-nlb-sg" })
}

resource "aws_lb" "app" {
  name                             = "${var.project}-nlb"
  load_balancer_type               = "network"
  internal                         = false
  subnets                          = [module.vpc.subnet_id]
  security_groups                  = [aws_security_group.nlb.id]
  enable_cross_zone_load_balancing = true
  tags                             = merge(var.tags, { Name = "${var.project}-nlb" })
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project}-app"
  port        = 30080
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = "30080"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = var.tags
}

resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group_attachment" "control_plane" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = module.control_plane.instance_id
  port             = 30080
}

resource "aws_lb_target_group_attachment" "worker" {
  count            = 2
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = module.worker[count.index].instance_id
  port             = 30080
}