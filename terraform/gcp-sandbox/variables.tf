variable "project" {
  type        = string
  description = "GCP project"
  default     = "server-migration-sandbox"
}

variable "region" {
  type        = string
  default     = "us-central1"
}

variable "zone" {
  type        = string
  default     = "us-central1-a"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.40.0.0/16"
}

variable "subnet_cidrs" {
  type        = map(string)
  default = {
    source = "10.40.1.0/24"
    target = "10.40.2.0/24"
    mgmt   = "10.40.3.0/24"
  }
}

variable "replication_bucket" {
  type        = string
  default     = "server-migration-gcs"
}

variable "logging_bucket" {
  type        = string
  default     = "server-migration-logs"
}

variable "admin_username" {
  type        = string
  default     = "migrate"
}

variable "ssh_public_key" {
  type        = string
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7exampleplaceholderkeyforvalidation migrate@example.com"
}

variable "servers" {
  type = list(object({
    name         = string
    role         = string
    machine_type = string
    image        = string
    subnet       = string
  }))
  default = [
    {
      name         = "source-linux"
      role         = "source"
      machine_type = "e2-standard-4"
      image        = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      subnet       = "source"
    },
    {
      name         = "target-linux"
      role         = "target"
      machine_type = "e2-standard-4"
      image        = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      subnet       = "target"
    },
    {
      name         = "source-windows"
      role         = "source"
      machine_type = "e2-standard-8"
      image        = "projects/windows-cloud/global/images/family/windows-2022"
      subnet       = "source"
    },
    {
      name         = "target-windows"
      role         = "target"
      machine_type = "e2-standard-8"
      image        = "projects/windows-cloud/global/images/family/windows-2022"
      subnet       = "target"
    }
  ]
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type = map(string)
  default = {
    project = "server-migration"
    owner   = "automation"
  }
}
