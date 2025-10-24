variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.20.0.0/16"
}

variable "subnet_cidrs" {
  description = "Map of subnet CIDRs"
  type        = map(string)
  default = {
    source = "10.20.1.0/24"
    target = "10.20.2.0/24"
    mgmt   = "10.20.3.0/24"
  }
}

variable "operator_cidr" {
  description = "CIDR block allowed to access bastion"
  type        = string
  default     = "0.0.0.0/0"
}

variable "bastion_ami" {
  description = "AMI used for bastion host"
  type        = string
}

variable "bastion_instance_type" {
  description = "Instance type for bastion"
  type        = string
  default     = "t3.small"
}

variable "bastion_subnet" {
  description = "Subnet key used by bastion"
  type        = string
  default     = "mgmt"
}

variable "admin_username" {
  description = "Default admin username"
  type        = string
  default     = "migrate"
}

variable "ssh_public_key" {
  description = "SSH public key"
  type        = string
  default     = ""
}

variable "servers" {
  description = "Server definitions"
  type = list(object({
    name          = string
    role          = string
    instance_type = string
    ami           = string
    subnet        = string
  }))
  default = [
    {
      name          = "source-linux"
      role          = "source"
      instance_type = "t3.medium"
      ami           = "ami-0c55b159cbfafe1f0"
      subnet        = "source"
    },
    {
      name          = "target-linux"
      role          = "target"
      instance_type = "t3.medium"
      ami           = "ami-0c55b159cbfafe1f0"
      subnet        = "target"
    },
    {
      name          = "source-windows"
      role          = "source"
      instance_type = "t3.large"
      ami           = "ami-0f9c61b5a562a16af"
      subnet        = "source"
    },
    {
      name          = "target-windows"
      role          = "target"
      instance_type = "t3.large"
      ami           = "ami-0f9c61b5a562a16af"
      subnet        = "target"
    }
  ]
}

variable "replication_bucket" {
  description = "S3 bucket for replication staging"
  type        = string
  default     = "server-migration-replication"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "pilot"
}

variable "log_retention_days" {
  description = "CloudWatch log retention"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    project = "server-migration"
    owner   = "automation"
  }
}
