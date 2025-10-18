variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_D2s_v5"
}

variable "os_type" {
  description = "OS type (linux or windows)"
  type        = string

  validation {
    condition     = contains(["linux", "windows"], var.os_type)
    error_message = "OS type must be 'linux' or 'windows'."
  }
}

variable "admin_username" {
  description = "Admin username"
  type        = string
}

variable "admin_password" {
  description = "Admin password (required for Windows)"
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_public_key" {
  description = "SSH public key (required for Linux)"
  type        = string
  default     = null
}

variable "subnet_id" {
  description = "Subnet ID for the VM"
  type        = string
}

variable "private_ip_address" {
  description = "Static private IP address (optional)"
  type        = string
  default     = null
}

variable "create_public_ip" {
  description = "Create a public IP for the VM"
  type        = bool
  default     = false
}

variable "availability_zone" {
  description = "Availability zone (1, 2, or 3)"
  type        = string
  default     = null
}

variable "os_disk_type" {
  description = "OS disk type"
  type        = string
  default     = "Premium_LRS"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "image_publisher" {
  description = "Image publisher"
  type        = string
}

variable "image_offer" {
  description = "Image offer"
  type        = string
}

variable "image_sku" {
  description = "Image SKU"
  type        = string
}

variable "image_version" {
  description = "Image version"
  type        = string
  default     = "latest"
}

variable "custom_data" {
  description = "Custom data for cloud-init or other initialization"
  type        = string
  default     = null
}

variable "enable_managed_identity" {
  description = "Enable system-assigned managed identity"
  type        = bool
  default     = false
}

variable "boot_diagnostics_storage_uri" {
  description = "Storage URI for boot diagnostics"
  type        = string
  default     = null
}

variable "data_disks" {
  description = "Map of data disks to attach"
  type = map(object({
    size_gb = number
    type    = string
    lun     = number
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}


