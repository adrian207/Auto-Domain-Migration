# vSphere Implementation Guide – Tier 1 (Demo) & Tier 2 (Production)

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Deploy the identity and domain migration solution on VMware vSphere infrastructure (on-premises or colo), fully automated via Terraform and Ansible.

**Target Audience:** Organizations with existing VMware investments wanting to leverage on-prem infrastructure.

**Cost:** Minimal (electricity + storage, no cloud costs)

---

## 1) vSphere Deployment Overview

### 1.1 Why vSphere?

**Advantages:**
- ✅ **Zero cloud costs** – Use existing VMware infrastructure
- ✅ **Full control** – On-premises data stays on-premises
- ✅ **VMware ecosystem** – Leverage vMotion, HA, DRS, vSAN
- ✅ **Enterprise features** – Advanced networking, storage policies
- ✅ **Compliance** – Data sovereignty, air-gapped networks

**Best For:**
- Organizations with existing vSphere deployments
- Regulated industries (healthcare, finance, government)
- Air-gapped or isolated networks
- Cost-conscious environments (no cloud spend)

---

### 1.2 Prerequisites

**VMware Infrastructure:**
- vCenter Server 7.0+ (or 8.0)
- ESXi hosts with available resources:
  - **Tier 1 (Demo):** 4 vCPUs, 8 GB RAM, 200 GB storage
  - **Tier 2 (Production):** 16 vCPUs, 64 GB RAM, 2 TB storage
- Network with DHCP or static IP allocation
- DNS server (internal)
- NFS or iSCSI datastore for USMT states (1-10 TB)

**Software Licenses:**
- vSphere Standard or Enterprise (for HA, DRS features)
- (Optional) vSAN for distributed storage
- (Optional) NSX for advanced networking

**Management Workstation:**
- Terraform 1.5+
- Ansible 2.15+
- PowerCLI (for manual tasks)
- SSH key pair

---

## 2) Architecture – vSphere Deployment

### 2.1 Tier 1 (Demo) Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                   vSphere Cluster (On-Prem)                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  vCenter Server: vcenter.corp.local                      │  │
│  │  Datacenter: Migration-DC                                │  │
│  │  Cluster: Migration-Cluster                              │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ Datastore: DS-MIGRATION-01 (500 GB)               │  │  │
│  │  │ Type: NFS / iSCSI / vSAN                          │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ Port Group: PG-Migration-Control (VLAN 100)       │  │  │
│  │  │ Network: 10.100.0.0/24                            │  │  │
│  │  │                                                   │  │  │
│  │  │  ┌──────────────────────────────────────────┐    │  │  │
│  │  │  │ VM: awx-runner-01                        │    │  │  │
│  │  │  │ vCPU: 2  |  RAM: 4 GB  |  Disk: 100 GB   │    │  │  │
│  │  │  │ OS: Ubuntu 22.04 LTS                     │    │  │  │
│  │  │  │ IP: 10.100.0.10                          │    │  │  │
│  │  │  │ Role: AWX (Ansible Tower)                │    │  │  │
│  │  │  └──────────────────────────────────────────┘    │  │  │
│  │  │                                                   │  │  │
│  │  │  ┌──────────────────────────────────────────┐    │  │  │
│  │  │  │ VM: postgres-01                          │    │  │  │
│  │  │  │ vCPU: 2  |  RAM: 4 GB  |  Disk: 50 GB    │    │  │  │
│  │  │  │ OS: Ubuntu 22.04 LTS                     │    │  │  │
│  │  │  │ IP: 10.100.0.20                          │    │  │  │
│  │  │  │ Role: PostgreSQL (reporting DB)          │    │  │  │
│  │  │  └──────────────────────────────────────────┘    │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ Port Group: PG-Migration-Targets (VLAN 200)       │  │  │
│  │  │ Network: 10.200.0.0/24                            │  │  │
│  │  │                                                   │  │  │
│  │  │  ┌──────────────────────────────────────────┐    │  │  │
│  │  │  │ VM: test-workstation-01                  │    │  │  │
│  │  │  │ vCPU: 2  |  RAM: 4 GB  |  Disk: 80 GB    │    │  │  │
│  │  │  │ OS: Windows 11 Pro                       │    │  │  │
│  │  │  │ IP: 10.200.0.10                          │    │  │  │
│  │  │  │ Role: Test migration target              │    │  │  │
│  │  │  └──────────────────────────────────────────┘    │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ NFS Datastore: StateStore-NFS                     │  │  │
│  │  │ Server: nfs-01.corp.local                         │  │  │
│  │  │ Export: /export/migration/usmt-states (2 TB)      │  │  │
│  │  │ Mount: /mnt/statestore (on awx-runner-01)         │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

**Resource Summary (Tier 1):**
- 3 VMs: 6 vCPUs, 12 GB RAM, 230 GB storage
- 1 NFS share: 2 TB
- 2 VLANs / Port Groups

---

### 2.2 Tier 2 (Production) Architecture

```
┌────────────────────────────────────────────────────────────────┐
│               vSphere Cluster (Production)                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  vCenter: vcenter.corp.local                             │  │
│  │  Cluster: Production-Cluster (with HA, DRS enabled)      │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ Control Plane VMs (Anti-Affinity Rule)            │  │  │
│  │  │                                                   │  │  │
│  │  │  ┌──────────────────────────────────────────┐    │  │  │
│  │  │  │ awx-runner-01, awx-runner-02             │    │  │  │
│  │  │  │ vCPU: 8  |  RAM: 32 GB  |  Disk: 500 GB  │    │  │  │
│  │  │  │ Role: AWX runners (parallel execution)   │    │  │  │
│  │  │  └──────────────────────────────────────────┘    │  │  │
│  │  │                                                   │  │  │
│  │  │  ┌──────────────────────────────────────────┐    │  │  │
│  │  │  │ postgres-01, postgres-02, postgres-03    │    │  │  │
│  │  │  │ vCPU: 4  |  RAM: 16 GB  |  Disk: 1 TB    │    │  │  │
│  │  │  │ Role: PostgreSQL cluster (Patroni + etcd) │   │  │  │
│  │  │  └──────────────────────────────────────────┘    │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ Storage: vSAN or NFS (10 TB)                      │  │  │
│  │  │ - USMT state stores: 8 TB                         │  │  │
│  │  │ - PostgreSQL data: 1 TB                           │  │  │
│  │  │ - Snapshots/backups: 1 TB                         │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │ Networking: NSX or Standard vSwitch               │  │  │
│  │  │ - VLAN 100: Control plane (10.100.0.0/24)         │  │  │
│  │  │ - VLAN 200: Target workstations (10.200.0.0/16)   │  │  │
│  │  │ - VLAN 300: Source domain (10.10.0.0/16)          │  │  │
│  │  │ - Firewall: NSX-T or physical firewall            │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

**Resource Summary (Tier 2):**
- 5 VMs: 32 vCPUs, 128 GB RAM, 4 TB storage
- 10 TB shared storage (NFS/vSAN)
- 3 VLANs / Port Groups
- vSphere HA, DRS, anti-affinity rules

---

## 3) Automated Deployment with Terraform

### 3.1 Terraform vSphere Provider Setup

**Directory Structure:**
```
infrastructure/vsphere-tier1/
├── main.tf               # Main resources
├── variables.tf          # Input variables
├── outputs.tf            # Outputs
├── terraform.tfvars.example
├── provider.tf           # vSphere provider config
├── data.tf               # Data sources (templates, networks, etc.)
├── compute.tf            # VM resources
├── network.tf            # Port groups (if creating new)
├── storage.tf            # NFS mounts, datastore config
└── templates/
    ├── awx-cloud-init.yaml
    ├── postgres-cloud-init.yaml
    └── ansible-inventory.tpl
```

---

### 3.2 Terraform Code

#### **provider.tf**

```hcl
terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.5.0"
    }
  }
  
  # Optional: Store state in NFS share or Git
  # backend "local" {
  #   path = "/mnt/nfs/terraform-state/vsphere-tier1.tfstate"
  # }
}

provider "vsphere" {
  vsphere_server       = var.vcenter_server
  user                 = var.vcenter_user
  password             = var.vcenter_password
  allow_unverified_ssl = var.vcenter_insecure
}
```

---

#### **variables.tf**

```hcl
# vCenter Connection
variable "vcenter_server" {
  description = "vCenter server FQDN or IP"
  type        = string
}

variable "vcenter_user" {
  description = "vCenter username"
  type        = string
}

variable "vcenter_password" {
  description = "vCenter password"
  type        = string
  sensitive   = true
}

variable "vcenter_insecure" {
  description = "Allow self-signed vCenter certificates"
  type        = bool
  default     = true
}

# vSphere Resources
variable "datacenter" {
  description = "vSphere datacenter name"
  type        = string
  default     = "Migration-DC"
}

variable "cluster" {
  description = "vSphere cluster name"
  type        = string
  default     = "Migration-Cluster"
}

variable "datastore" {
  description = "vSphere datastore for VMs"
  type        = string
  default     = "DS-MIGRATION-01"
}

variable "network_control_plane" {
  description = "Port group for control plane VMs"
  type        = string
  default     = "PG-Migration-Control"
}

variable "network_workstations" {
  description = "Port group for target workstations"
  type        = string
  default     = "PG-Migration-Targets"
}

# VM Templates
variable "template_ubuntu" {
  description = "Ubuntu 22.04 LTS template name"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "template_windows" {
  description = "Windows 11 Pro template name"
  type        = string
  default     = "windows-11-pro-template"
}

# VM Configuration
variable "vm_admin_user" {
  description = "Admin username for VMs"
  type        = string
  default     = "vmadmin"
}

variable "vm_admin_password" {
  description = "Admin password for VMs"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for Linux VMs"
  type        = string
  default     = ""  # Will use file() in main.tf
}

# NFS State Store
variable "nfs_server" {
  description = "NFS server for USMT state store"
  type        = string
  default     = "nfs-01.corp.local"
}

variable "nfs_export" {
  description = "NFS export path"
  type        = string
  default     = "/export/migration/usmt-states"
}

# Networking
variable "control_plane_network" {
  description = "Control plane network CIDR"
  type        = string
  default     = "10.100.0.0/24"
}

variable "awx_ip" {
  description = "Static IP for AWX VM"
  type        = string
  default     = "10.100.0.10"
}

variable "postgres_ip" {
  description = "Static IP for PostgreSQL VM"
  type        = string
  default     = "10.100.0.20"
}

variable "test_workstation_ip" {
  description = "Static IP for test workstation"
  type        = string
  default     = "10.200.0.10"
}

variable "gateway" {
  description = "Default gateway for VMs"
  type        = string
  default     = "10.100.0.1"
}

variable "dns_servers" {
  description = "DNS servers for VMs"
  type        = list(string)
  default     = ["10.10.0.10", "10.10.0.11"]  # Corporate DNS
}

variable "domain_name" {
  description = "DNS domain name"
  type        = string
  default     = "corp.local"
}

# Tags
variable "tags" {
  description = "Tags for VMs"
  type        = map(string)
  default = {
    Project     = "Identity-Domain-Migration"
    Environment = "Demo"
    ManagedBy   = "Terraform"
  }
}
```

---

#### **data.tf** (Data Sources)

```hcl
# Datacenter
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

# Compute Cluster
data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Datastore
data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Networks
data "vsphere_network" "control_plane" {
  name          = var.network_control_plane
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "workstations" {
  name          = var.network_workstations
  datacenter_id = data.vsphere_datacenter.dc.id
}

# VM Templates
data "vsphere_virtual_machine" "ubuntu_template" {
  name          = var.template_ubuntu
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "windows_template" {
  name          = var.template_windows
  datacenter_id = data.vsphere_datacenter.dc.id
}
```

---

#### **compute.tf** (VMs)

```hcl
# AWX Runner VM
resource "vsphere_virtual_machine" "awx" {
  name             = "awx-runner-01"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "Migration"  # VM folder in vCenter
  
  num_cpus = 2
  memory   = 4096  # 4 GB
  guest_id = data.vsphere_virtual_machine.ubuntu_template.guest_id
  
  scsi_type = data.vsphere_virtual_machine.ubuntu_template.scsi_type
  
  network_interface {
    network_id   = data.vsphere_network.control_plane.id
    adapter_type = data.vsphere_virtual_machine.ubuntu_template.network_interface_types[0]
  }
  
  disk {
    label            = "disk0"
    size             = 100
    thin_provisioned = true
  }
  
  clone {
    template_uuid = data.vsphere_virtual_machine.ubuntu_template.id
    
    customize {
      linux_options {
        host_name = "awx-runner-01"
        domain    = var.domain_name
      }
      
      network_interface {
        ipv4_address = var.awx_ip
        ipv4_netmask = 24
      }
      
      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
      dns_suffix_list = [var.domain_name]
    }
  }
  
  # Cloud-init (user data)
  extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/templates/awx-cloud-init.yaml", {
      admin_user     = var.vm_admin_user
      ssh_public_key = coalesce(var.ssh_public_key, file("~/.ssh/id_rsa.pub"))
      postgres_host  = var.postgres_ip
      nfs_server     = var.nfs_server
      nfs_export     = var.nfs_export
    }))
    "guestinfo.userdata.encoding" = "base64"
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/templates/metadata.yaml", {
      hostname = "awx-runner-01"
      fqdn     = "awx-runner-01.${var.domain_name}"
    }))
    "guestinfo.metadata.encoding" = "base64"
  }
  
  # Tags
  tags = [for k, v in var.tags : vsphere_tag.tags[k].id]
}

# PostgreSQL VM
resource "vsphere_virtual_machine" "postgres" {
  name             = "postgres-01"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "Migration"
  
  num_cpus = 2
  memory   = 4096  # 4 GB
  guest_id = data.vsphere_virtual_machine.ubuntu_template.guest_id
  
  scsi_type = data.vsphere_virtual_machine.ubuntu_template.scsi_type
  
  network_interface {
    network_id   = data.vsphere_network.control_plane.id
    adapter_type = data.vsphere_virtual_machine.ubuntu_template.network_interface_types[0]
  }
  
  disk {
    label            = "disk0"
    size             = 50
    thin_provisioned = true
  }
  
  # Additional disk for PostgreSQL data
  disk {
    label            = "disk1"
    size             = 100
    thin_provisioned = true
    unit_number      = 1
  }
  
  clone {
    template_uuid = data.vsphere_virtual_machine.ubuntu_template.id
    
    customize {
      linux_options {
        host_name = "postgres-01"
        domain    = var.domain_name
      }
      
      network_interface {
        ipv4_address = var.postgres_ip
        ipv4_netmask = 24
      }
      
      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
      dns_suffix_list = [var.domain_name]
    }
  }
  
  extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/templates/postgres-cloud-init.yaml", {
      admin_user     = var.vm_admin_user
      ssh_public_key = coalesce(var.ssh_public_key, file("~/.ssh/id_rsa.pub"))
    }))
    "guestinfo.userdata.encoding" = "base64"
    "guestinfo.metadata"          = base64encode(templatefile("${path.module}/templates/metadata.yaml", {
      hostname = "postgres-01"
      fqdn     = "postgres-01.${var.domain_name}"
    }))
    "guestinfo.metadata.encoding" = "base64"
  }
  
  tags = [for k, v in var.tags : vsphere_tag.tags[k].id]
}

# Test Workstation VM (Windows)
resource "vsphere_virtual_machine" "test_workstation" {
  name             = "test-workstation-01"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = "Migration"
  
  num_cpus = 2
  memory   = 4096
  guest_id = data.vsphere_virtual_machine.windows_template.guest_id
  
  scsi_type = data.vsphere_virtual_machine.windows_template.scsi_type
  
  network_interface {
    network_id   = data.vsphere_network.workstations.id
    adapter_type = data.vsphere_virtual_machine.windows_template.network_interface_types[0]
  }
  
  disk {
    label            = "disk0"
    size             = 80
    thin_provisioned = true
  }
  
  clone {
    template_uuid = data.vsphere_virtual_machine.windows_template.id
    
    customize {
      windows_options {
        computer_name  = "TEST-WS-01"
        workgroup      = "WORKGROUP"  # Will join domain later
        admin_password = var.vm_admin_password
        
        # Enable WinRM
        run_once_command_list = [
          "powershell.exe -ExecutionPolicy Bypass -Command \"Enable-PSRemoting -Force\"",
          "powershell.exe -ExecutionPolicy Bypass -Command \"Set-Item wsman:\\localhost\\client\\trustedhosts * -Force\"",
          "powershell.exe -ExecutionPolicy Bypass -Command \"New-NetFirewallRule -Name 'WinRM-HTTP' -DisplayName 'WinRM HTTP' -Protocol TCP -LocalPort 5985 -Action Allow\""
        ]
      }
      
      network_interface {
        ipv4_address = var.test_workstation_ip
        ipv4_netmask = 24
      }
      
      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }
  
  tags = [for k, v in var.tags : vsphere_tag.tags[k].id]
}

# vSphere Tags
resource "vsphere_tag_category" "migration" {
  name        = "Migration"
  cardinality = "MULTIPLE"
  description = "Tags for migration project VMs"
  
  associable_types = [
    "VirtualMachine",
  ]
}

resource "vsphere_tag" "tags" {
  for_each    = var.tags
  name        = "${each.key}-${each.value}"
  category_id = vsphere_tag_category.migration.id
  description = "Tag: ${each.key} = ${each.value}"
}
```

---

#### **outputs.tf**

```hcl
output "awx_vm_ip" {
  description = "AWX VM IP address"
  value       = var.awx_ip
}

output "awx_url" {
  description = "AWX Web UI URL"
  value       = "https://${var.awx_ip}"
}

output "postgres_vm_ip" {
  description = "PostgreSQL VM IP address"
  value       = var.postgres_ip
}

output "test_workstation_ip" {
  description = "Test workstation IP"
  value       = var.test_workstation_ip
}

output "ssh_awx" {
  description = "SSH command for AWX VM"
  value       = "ssh ${var.vm_admin_user}@${var.awx_ip}"
}

output "ssh_postgres" {
  description = "SSH command for PostgreSQL VM"
  value       = "ssh ${var.vm_admin_user}@${var.postgres_ip}"
}

output "rdp_workstation" {
  description = "RDP to test workstation"
  value       = "mstsc /v:${var.test_workstation_ip}"
}

output "nfs_mount" {
  description = "NFS mount point on AWX VM"
  value       = "/mnt/statestore → ${var.nfs_server}:${var.nfs_export}"
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ✅ vSphere deployment complete!
    
    Next steps:
    
    1. SSH to AWX VM:
       ${output.ssh_awx.value}
    
    2. Check AWX installation:
       sudo docker ps
       sudo tail -f /var/log/awx-install.log
    
    3. Access AWX Web UI:
       ${output.awx_url.value}
       Username: admin
       Password: admin (CHANGE IMMEDIATELY)
    
    4. Verify NFS mount:
       ssh ${var.vm_admin_user}@${var.awx_ip}
       df -h /mnt/statestore
    
    5. Connect to PostgreSQL:
       ssh ${var.vm_admin_user}@${var.postgres_ip}
       sudo -u postgres psql
    
    6. RDP to test workstation:
       ${output.rdp_workstation.value}
    
    7. Take snapshots (via vCenter):
       - awx-runner-01: Pre-migration baseline
       - postgres-01: Pre-migration baseline
       - test-workstation-01: Pre-migration baseline
    
    Cost: Minimal (electricity + storage, no cloud fees)
  EOT
}
```

---

### 3.3 Cloud-Init Templates

#### **templates/awx-cloud-init.yaml**

```yaml
#cloud-config
users:
  - name: ${admin_user}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${ssh_public_key}

package_update: true
package_upgrade: true

packages:
  - docker.io
  - docker-compose
  - python3-pip
  - git
  - curl
  - jq
  - nfs-common
  - postgresql-client

write_files:
  - path: /opt/awx-install/docker-compose.yml
    content: |
      version: '3'
      services:
        awx_web:
          image: ansible/awx:21.14.0
          container_name: awx_web
          depends_on:
            - awx_task
          ports:
            - "80:8052"
            - "443:8053"
          environment:
            DATABASE_HOST: ${postgres_host}
            DATABASE_NAME: awx
            DATABASE_USER: awx
            DATABASE_PASSWORD: awx_password
            DATABASE_PORT: 5432
            SECRET_KEY: $(openssl rand -base64 32)
          volumes:
            - /mnt/statestore:/var/lib/awx/projects
            - /opt/awx/job_output:/var/lib/awx/job_output
        
        awx_task:
          image: ansible/awx:21.14.0
          container_name: awx_task
          environment:
            DATABASE_HOST: ${postgres_host}
            DATABASE_NAME: awx
            DATABASE_USER: awx
            DATABASE_PASSWORD: awx_password
            DATABASE_PORT: 5432
          volumes:
            - /mnt/statestore:/var/lib/awx/projects
            - /opt/awx/job_output:/var/lib/awx/job_output
  
  - path: /etc/fstab
    append: true
    content: |
      ${nfs_server}:${nfs_export} /mnt/statestore nfs defaults,_netdev 0 0

runcmd:
  - mkdir -p /mnt/statestore
  - mount -a
  - systemctl enable docker
  - systemctl start docker
  - curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  - chmod +x /usr/local/bin/docker-compose
  - cd /opt/awx-install && docker-compose up -d
  - sleep 60
  - docker exec awx_task awx-manage createsuperuser --username admin --email admin@example.com --noinput || true
  - docker exec awx_task awx-manage update_password --username admin --password admin || true

final_message: "AWX installation complete. Access at https://${admin_user}@$(hostname -I | awk '{print $1}')"
```

#### **templates/postgres-cloud-init.yaml**

```yaml
#cloud-config
users:
  - name: ${admin_user}
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - ${ssh_public_key}

package_update: true
package_upgrade: true

packages:
  - postgresql-14
  - postgresql-contrib

write_files:
  - path: /etc/postgresql/14/main/postgresql.conf
    append: true
    content: |
      listen_addresses = '*'
      max_connections = 200
      shared_buffers = 1GB
      effective_cache_size = 3GB
      maintenance_work_mem = 256MB
      checkpoint_completion_target = 0.9
      wal_buffers = 16MB
      default_statistics_target = 100
      random_page_cost = 1.1
      effective_io_concurrency = 200
  
  - path: /etc/postgresql/14/main/pg_hba.conf
    append: true
    content: |
      host    all             all             10.100.0.0/24           md5
      host    all             all             10.200.0.0/16           md5

runcmd:
  - systemctl enable postgresql
  - systemctl start postgresql
  - sudo -u postgres psql -c "CREATE USER awx WITH PASSWORD 'awx_password';"
  - sudo -u postgres psql -c "CREATE DATABASE awx OWNER awx;"
  - sudo -u postgres psql -c "CREATE DATABASE migration_reporting OWNER awx;"
  - systemctl restart postgresql

final_message: "PostgreSQL installation complete."
```

---

### 3.4 terraform.tfvars.example

```hcl
# vCenter Connection
vcenter_server   = "vcenter.corp.local"
vcenter_user     = "administrator@vsphere.local"
vcenter_password = "YourVCenterPassword"
vcenter_insecure = true  # Set to false if using valid cert

# vSphere Resources
datacenter = "Migration-DC"
cluster    = "Migration-Cluster"
datastore  = "DS-MIGRATION-01"

network_control_plane = "PG-Migration-Control"
network_workstations  = "PG-Migration-Targets"

# VM Templates (create these before running Terraform)
template_ubuntu  = "ubuntu-22.04-template"
template_windows = "windows-11-pro-template"

# VM Credentials
vm_admin_user     = "vmadmin"
vm_admin_password = "YourStrongPassword123!"
ssh_public_key    = "ssh-rsa AAAAB3... yourkey@yourmachine"

# NFS State Store
nfs_server = "nfs-01.corp.local"
nfs_export = "/export/migration/usmt-states"

# Networking
awx_ip              = "10.100.0.10"
postgres_ip         = "10.100.0.20"
test_workstation_ip = "10.200.0.10"
gateway             = "10.100.0.1"
dns_servers         = ["10.10.0.10", "10.10.0.11"]
domain_name         = "corp.local"

# Tags
tags = {
  Project     = "Identity-Domain-Migration-Demo"
  Environment = "Demo"
  ManagedBy   = "Terraform"
  Owner       = "it-team@corp.com"
}
```

---

## 4) Pre-Deployment: Create VM Templates

### 4.1 Create Ubuntu 22.04 Template

```bash
# On vCenter or ESXi host

# 1. Create VM from ISO
# 2. Install Ubuntu 22.04 LTS (minimal installation)
# 3. Install VMware Tools
sudo apt update
sudo apt install open-vm-tools -y

# 4. Install cloud-init
sudo apt install cloud-init -y

# 5. Configure cloud-init datasource
sudo cat > /etc/cloud/cloud.cfg.d/99-vmware.cfg <<EOF
datasource:
  VMware:
    allow_raw_data: true
datasource_list: [ VMware, OVF, None ]
EOF

# 6. Clean up
sudo cloud-init clean
sudo rm -rf /var/lib/cloud/instances/*
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
history -c

# 7. Shut down VM
sudo shutdown -h now

# 8. Convert to template in vCenter
# Right-click VM → Template → Convert to Template
# Name: ubuntu-22.04-template
```

---

### 4.2 Create Windows 11 Pro Template

```powershell
# On Windows 11 VM

# 1. Install VMware Tools
# 2. Run Windows Update
# 3. Install required features
Enable-PSRemoting -Force
Set-Item wsman:\localhost\client\trustedhosts * -Force

# 4. Configure Windows for sysprep
C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown

# 5. Convert to template in vCenter after shutdown
# Right-click VM → Template → Convert to Template
# Name: windows-11-pro-template
```

---

## 5) Deployment Steps

### 5.1 Deploy Infrastructure

```bash
# Clone repository
git clone https://github.com/yourorg/migration-automation.git
cd migration-automation

# Checkout vSphere branch
git checkout platform/vsphere

# Navigate to Terraform directory
cd infrastructure/vsphere-tier1

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Edit with your vCenter details

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply (deploy VMs)
terraform apply

# Expected duration: 10-15 minutes
```

---

### 5.2 Verify Deployment

```bash
# Get outputs
terraform output

# SSH to AWX VM
ssh vmadmin@10.100.0.10

# Check AWX installation
sudo docker ps
sudo tail -f /var/log/awx-install.log

# Verify NFS mount
df -h /mnt/statestore

# SSH to PostgreSQL VM
ssh vmadmin@10.100.0.20

# Test PostgreSQL
sudo -u postgres psql -l
```

---

## 6) vSphere-Specific Features

### 6.1 Snapshots for Rollback

**Create Pre-Migration Snapshots:**
```bash
# Using PowerCLI
Connect-VIServer -Server vcenter.corp.local

# Snapshot all migration VMs
Get-VM -Name "*migration*" | New-Snapshot -Name "Pre-Wave-01" -Description "Snapshot before wave 1 migration" -Memory:$false -Quiesce:$true

# List snapshots
Get-VM -Name "awx-runner-01" | Get-Snapshot
```

**Or via Terraform:**
```hcl
# Add to compute.tf
resource "vsphere_snapshot" "awx_pre_migration" {
  virtual_machine_uuid = vsphere_virtual_machine.awx.id
  snapshot_name        = "Pre-Migration-Baseline"
  description          = "Baseline snapshot before any migrations"
  memory               = false
  quiesce              = true
}
```

---

### 6.2 High Availability (Tier 2)

**Enable vSphere HA:**
```hcl
# In Tier 2 configuration
resource "vsphere_ha_vm_override" "awx_priority" {
  compute_cluster_id = data.vsphere_compute_cluster.cluster.id
  virtual_machine_id = vsphere_virtual_machine.awx.id
  
  ha_vm_restart_priority = "high"
  ha_vm_failure_interval = 30
}
```

**Anti-Affinity Rule (keep AWX runners on different hosts):**
```hcl
resource "vsphere_compute_cluster_vm_anti_affinity_rule" "awx_anti_affinity" {
  name                = "awx-anti-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = [
    vsphere_virtual_machine.awx[0].id,
    vsphere_virtual_machine.awx[1].id,
  ]
}
```

---

### 6.3 vMotion for Zero-Downtime Maintenance

```bash
# Migrate AWX VM to different host (no downtime)
Move-VM -VM "awx-runner-01" -Destination (Get-VMHost "esxi-02.corp.local")

# Migrate to different datastore (Storage vMotion)
Move-VM -VM "awx-runner-01" -Datastore (Get-Datastore "DS-MIGRATION-02")
```

---

## 7) Cost Comparison

### vSphere vs. Azure (4-month migration project)

| Component | vSphere (On-Prem) | Azure (Cloud) |
|-----------|-------------------|---------------|
| **Compute** | $0 (existing hardware) | $9,600 (VM costs) |
| **Storage** | $200 (2 TB NFS, electricity) | $4,800 (Blob storage) |
| **Network** | $0 (existing network) | $3,200 (VPN Gateway) |
| **Database** | $0 (VM-based Postgres) | $1,200 (Azure DB) |
| **Monitoring** | $0 (Prometheus/Grafana) | $800 (Azure Monitor) |
| **Total (4 months)** | **$200** | **$19,600** |

**Savings:** **$19,400** (98% cost reduction)

**[Note: Assumes existing vSphere infrastructure; excludes vSphere licensing costs]**

---

## 8) Summary

### What You Get with vSphere

✅ **Zero cloud costs** – Use existing VMware infrastructure  
✅ **Enterprise features** – vMotion, HA, DRS, snapshots  
✅ **Full control** – No vendor lock-in, on-prem data  
✅ **Mature ecosystem** – PowerCLI, vRealize, NSX integration  
✅ **Cost-effective** – ~$200 for 4-month project vs. $19k+ for cloud  

### Limitations

❌ **Requires existing VMware** – Not suitable if you don't have vSphere  
❌ **Manual hardware management** – No cloud elasticity  
❌ **Licensing costs** – vSphere licenses (if not already owned)  
❌ **Network complexity** – Must manage on-prem networking  

### Best For

✅ Organizations with existing VMware deployments  
✅ Regulated industries (data sovereignty)  
✅ Air-gapped or isolated networks  
✅ Cost-conscious environments (no cloud budget)  

---

**You now have TWO implementation paths:**
1. **Azure Free Tier** (`docs/18_AZURE_FREE_TIER_IMPLEMENTATION.md`) – $0-5/month, cloud-based demo
2. **vSphere** (`docs/19_VSPHERE_IMPLEMENTATION.md`) – ~$200/4 months, on-prem deployment

**Choose based on:**
- Existing infrastructure (VMware = vSphere, Microsoft shop = Azure)
- Budget constraints (vSphere = minimal cost)
- Compliance requirements (on-prem = vSphere, cloud-ready = Azure)

---

**END OF DOCUMENT**

