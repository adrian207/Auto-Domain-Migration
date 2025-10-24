terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "network" {
  source       = "../modules/network"
  platform     = "aws"
  cidr_block   = var.vpc_cidr
  subnet_cidrs = var.subnet_cidrs
  tags         = var.tags
}

module "storage" {
  source                  = "../modules/storage"
  platform                = "aws"
  replication_bucket_name = var.replication_bucket
  tags                    = var.tags
}

module "observability" {
  source             = "../modules/observability"
  platform           = "aws"
  log_retention_days = var.log_retention_days
  tags               = var.tags
}

resource "aws_security_group" "bastion" {
  name   = "server-migration-bastion"
  vpc_id = module.network.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.operator_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "server-migration-bastion" })
}

resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami
  instance_type               = var.bastion_instance_type
  subnet_id                   = module.network.subnet_ids[var.bastion_subnet]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  tags = merge(var.tags, { Name = "server-migration-bastion" })
}

module "compute" {
  source         = "../modules/compute"
  platform       = "aws"
  admin_username = var.admin_username
  ssh_public_key = var.ssh_public_key
  instances = [
    for server in var.servers : {
      name          = server.name
      role          = server.role
      instance_type = server.instance_type
      image         = server.ami
      subnet_id     = module.network.subnet_ids[server.subnet]
    }
  ]
  tags = merge(var.tags, {
    environment = var.environment
  })
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "replication_bucket" {
  value = var.replication_bucket
}
