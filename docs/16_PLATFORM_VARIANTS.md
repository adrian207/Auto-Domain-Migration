# Platform Variants – Multi-Cloud & Virtualization Support

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Provide platform-specific implementation branches for AWS, Azure, GCP, and major virtualization platforms (Hyper-V, vSphere, OpenStack), enabling organizations to choose their infrastructure stack while using the same migration automation framework.

**Design Principle:** **Core migration logic remains platform-agnostic; infrastructure components are swappable via platform-specific roles and variables.**

---

## 1) Architecture Overview

### 1.1 Platform Abstraction Model

```
┌─────────────────────────────────────────────────────────┐
│         Core Migration Framework (Platform-Agnostic)    │
│  - Identity export/provision                            │
│  - Machine domain moves (USMT, service rebind)          │
│  - Validation, reporting, rollback                      │
└─────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│         Platform Abstraction Layer (Pluggable)          │
│  - Storage (state stores, object storage)               │
│  - Compute (runner VMs, orchestration)                  │
│  - Networking (VPCs, DNS, load balancers)               │
│  - Secrets (Key Vault, Secrets Manager, etc.)           │
└─────────────────────────────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┬─────────────────┐
         ▼                 ▼                 ▼                 ▼
    ┌────────┐       ┌────────┐       ┌────────┐       ┌────────┐
    │  AWS   │       │ Azure  │       │  GCP   │       │On-Prem │
    │ Branch │       │ Branch │       │ Branch │       │ Branch │
    └────────┘       └────────┘       └────────┘       └────────┘
```

**Implementation:** Git branches + Ansible variable overrides + platform-specific roles

---

## 2) Git Branch Strategy

### 2.1 Branch Structure

```
main (platform-agnostic core)
├── platform/aws
├── platform/azure
├── platform/gcp
├── platform/vmware-vsphere
├── platform/hyperv
├── platform/openstack
└── platform/hybrid (multi-cloud)
```

**Workflow:**
1. **Core development** happens in `main` branch
2. **Platform branches** merge from `main` and add platform-specific components
3. **Organizations fork** the appropriate platform branch for their deployment

---

### 2.2 Branch Contents

**`main` (Core Framework):**
- All `roles/` for migration logic (ad_export, machine_move_usmt, etc.)
- Core playbooks (discovery, provision, migrate, validate, rollback)
- Documentation (design, runbooks, strategies)
- Platform-agnostic inventory templates

**`platform/aws`:**
- `infrastructure/aws/` – Terraform for AWS resources
- `group_vars/aws.yml` – AWS-specific variables (S3 buckets, IAM roles)
- Platform-specific roles: `aws_s3_state_store`, `aws_secrets_manager`, `aws_backup`
- CloudFormation templates (alternative to Terraform)
- AWS-specific playbooks: `aws_snapshot_ec2.yml`, `aws_setup_transit_gateway.yml`

**`platform/azure`:**
- `infrastructure/azure/` – Terraform for Azure resources
- `group_vars/azure.yml` – Azure-specific variables (Storage Accounts, Key Vault)
- Platform-specific roles: `azure_blob_state_store`, `azure_keyvault`, `azure_backup`
- ARM templates (alternative to Terraform)
- Azure-specific playbooks: `azure_snapshot_vm.yml`, `azure_setup_vnet_peering.yml`

**Similar for GCP, vSphere, Hyper-V, OpenStack...**

---

## 3) Platform-Specific Components

### 3.1 AWS Implementation

#### **Infrastructure (Terraform)**

```hcl
# infrastructure/aws/main.tf
# Control Plane VPC
resource "aws_vpc" "migration_control" {
  cidr_block           = "10.100.0.0/16"
  enable_dns_hostnames = true
  
  tags = {
    Name = "migration-control-plane"
    Purpose = "Identity & Domain Migration"
  }
}

# State Store S3 Bucket (replaces SMB shares)
resource "aws_s3_bucket" "usmt_state_store" {
  bucket = "migration-usmt-states-${var.org_id}"
  
  lifecycle_rule {
    enabled = true
    expiration {
      days = 90  # Prune old USMT stores after 90 days
    }
    noncurrent_version_expiration {
      days = 30
    }
  }
  
  versioning {
    enabled = true  # Snapshot-like behavior via versioning
  }
}

# Secrets Manager for credentials
resource "aws_secretsmanager_secret" "migration_creds" {
  name = "migration/domain-admin"
  
  recovery_window_in_days = 7
}

# EC2 Instances for AWX runners
resource "aws_instance" "awx_runner" {
  count         = var.runner_count
  ami           = data.aws_ami.rhel8.id
  instance_type = "c5.2xlarge"  # 8 vCPU, 16 GB RAM
  
  subnet_id              = aws_subnet.control_plane.id
  vpc_security_group_ids = [aws_security_group.awx_runner.id]
  iam_instance_profile   = aws_iam_instance_profile.awx_runner.name
  
  root_block_device {
    volume_size = 500
    volume_type = "gp3"
    encrypted   = true
  }
  
  tags = {
    Name = "awx-runner-${count.index + 1}"
  }
}

# RDS for PostgreSQL (reporting database)
resource "aws_db_instance" "migration_db" {
  identifier     = "migration-reporting"
  engine         = "postgres"
  engine_version = "14.7"
  instance_class = "db.r5.large"
  
  allocated_storage     = 1000
  storage_encrypted     = true
  multi_az              = true
  
  db_subnet_group_name   = aws_db_subnet_group.migration.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  
  backup_retention_period = 30
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
}

# VPN Gateway (connect to on-prem)
resource "aws_vpn_gateway" "migration" {
  vpc_id = aws_vpc.migration_control.id
  
  tags = {
    Name = "migration-vpn-gateway"
  }
}

# Direct Connect (for high-bandwidth state store access)
resource "aws_dx_gateway" "migration" {
  name            = "migration-dx-gateway"
  amazon_side_asn = 64512
}
```

#### **Ansible Variables (group_vars/aws.yml)**

```yaml
---
# AWS-specific configuration
platform: aws
cloud_provider: aws

# State Store (S3 instead of SMB)
usmt_store_type: s3
usmt_s3_bucket: "migration-usmt-states-{{ org_id }}"
usmt_s3_region: "us-east-1"
usmt_s3_kms_key: "alias/migration-usmt"

# Secrets Management
secrets_backend: aws_secretsmanager
aws_secrets_region: "us-east-1"

# Database
reporting_db_type: rds_postgres
reporting_db_endpoint: "{{ terraform_output.rds_endpoint }}"
reporting_db_port: 5432

# Backup Strategy
backup_method: aws_snapshots
snapshot_schedule: "cron(0 2 * * ? *)"  # 2 AM daily

# Network
vpc_id: "{{ terraform_output.vpc_id }}"
control_plane_subnet_ids: "{{ terraform_output.control_subnets }}"
vpn_gateway_id: "{{ terraform_output.vpn_gateway_id }}"

# Monitoring
monitoring_backend: cloudwatch
metrics_namespace: "Migration/Waves"

# Tags (applied to all AWS resources)
resource_tags:
  Project: "Identity-Domain-Migration"
  ManagedBy: "Ansible"
  CostCenter: "IT-Infrastructure"
```

#### **Platform-Specific Roles**

**Role: `aws_s3_state_store`**

```yaml
# roles/aws_s3_state_store/tasks/main.yml
---
- name: Install AWS CLI and boto3
  pip:
    name:
      - awscli
      - boto3
    state: present

- name: Configure AWS CLI credentials (via IAM role)
  shell: aws sts get-caller-identity
  register: aws_identity
  changed_when: false

- name: Test S3 bucket access
  aws_s3:
    bucket: "{{ usmt_s3_bucket }}"
    mode: list
  register: s3_test

- name: Enable S3 bucket versioning (snapshot-like)
  aws_s3_bucket:
    name: "{{ usmt_s3_bucket }}"
    versioning: yes
    region: "{{ usmt_s3_region }}"

- name: Enable S3 bucket encryption
  aws_s3_bucket:
    name: "{{ usmt_s3_bucket }}"
    encryption: "aws:kms"
    encryption_key_id: "{{ usmt_s3_kms_key }}"

- name: Create lifecycle policy for old USMT stores
  aws_s3_bucket:
    name: "{{ usmt_s3_bucket }}"
    lifecycle_rule:
      - id: "expire-old-states"
        status: enabled
        expiration:
          days: 90
```

**Role: `aws_secrets_manager`**

```yaml
# roles/aws_secrets_manager/tasks/main.yml
---
- name: Retrieve domain admin credentials from Secrets Manager
  aws_secret:
    name: "migration/domain-admin"
    region: "{{ aws_secrets_region }}"
  register: domain_admin_secret
  no_log: true

- name: Parse secret JSON
  set_fact:
    domain_admin_user: "{{ (domain_admin_secret.secret | from_json).username }}"
    domain_admin_pass: "{{ (domain_admin_secret.secret | from_json).password }}"
  no_log: true

- name: Retrieve service account credentials
  aws_secret:
    name: "migration/service-accounts/{{ item }}"
    region: "{{ aws_secrets_region }}"
  loop: "{{ service_accounts }}"
  register: service_account_secrets
  no_log: true
```

**Playbook: `aws_snapshot_ec2.yml` (Backup Control Plane)**

```yaml
---
- name: AWS - Snapshot Control Plane EC2 Instances
  hosts: localhost
  gather_facts: no

  tasks:
    - name: Get AWX runner instance IDs
      ec2_instance_info:
        region: "{{ aws_region }}"
        filters:
          "tag:Name": "awx-runner-*"
          "instance-state-name": "running"
      register: awx_instances

    - name: Create AMI snapshots
      ec2_ami:
        instance_id: "{{ item.instance_id }}"
        name: "awx-runner-{{ item.instance_id }}-{{ ansible_date_time.epoch }}"
        description: "Pre-wave snapshot for {{ wave }}"
        wait: yes
        region: "{{ aws_region }}"
        tags:
          Wave: "{{ wave }}"
          SnapshotType: "pre-wave"
      loop: "{{ awx_instances.instances }}"
      register: ami_snapshots

    - name: Tag AMIs for lifecycle management
      ec2_tag:
        resource: "{{ item.image_id }}"
        region: "{{ aws_region }}"
        tags:
          RetentionDays: "30"
          AutoDelete: "true"
      loop: "{{ ami_snapshots.results }}"
```

---

### 3.2 Azure Implementation

#### **Infrastructure (Terraform)**

```hcl
# infrastructure/azure/main.tf
# Resource Group
resource "azurerm_resource_group" "migration" {
  name     = "rg-migration-${var.environment}"
  location = var.azure_region
  
  tags = {
    Purpose = "Identity & Domain Migration"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "migration_control" {
  name                = "vnet-migration-control"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  address_space       = ["10.100.0.0/16"]
}

# Storage Account for USMT State Store
resource "azurerm_storage_account" "usmt_states" {
  name                     = "stmigusmt${var.org_id}"
  resource_group_name      = azurerm_resource_group.migration.name
  location                 = azurerm_resource_group.migration.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  blob_properties {
    versioning_enabled = true  # Snapshot-like behavior
    
    delete_retention_policy {
      days = 90
    }
  }
}

# Key Vault for Secrets
resource "azurerm_key_vault" "migration" {
  name                = "kv-migration-${var.org_id}"
  location            = azurerm_resource_group.migration.location
  resource_group_name = azurerm_resource_group.migration.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"
  
  enable_rbac_authorization = true
  purge_protection_enabled  = true
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "migration_db" {
  name                = "psql-migration-${var.org_id}"
  resource_group_name = azurerm_resource_group.migration.name
  location            = azurerm_resource_group.migration.location
  
  sku_name   = "GP_Standard_D4s_v3"
  storage_mb = 1048576  # 1 TB
  
  backup_retention_days = 30
  geo_redundant_backup_enabled = true
  
  high_availability {
    mode = "ZoneRedundant"
  }
}

# Virtual Machines for AWX Runners
resource "azurerm_linux_virtual_machine" "awx_runner" {
  count               = var.runner_count
  name                = "vm-awx-runner-${count.index + 1}"
  resource_group_name = azurerm_resource_group.migration.name
  location            = azurerm_resource_group.migration.location
  size                = "Standard_D8s_v3"  # 8 vCPU, 32 GB RAM
  
  admin_username = "azureuser"
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 500
  }
  
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "8_6"
    version   = "latest"
  }
  
  identity {
    type = "SystemAssigned"
  }
}

# ExpressRoute (for high-bandwidth on-prem connectivity)
resource "azurerm_express_route_circuit" "migration" {
  name                  = "er-migration"
  resource_group_name   = azurerm_resource_group.migration.name
  location              = azurerm_resource_group.migration.location
  service_provider_name = "Equinix"
  peering_location      = "Silicon Valley"
  bandwidth_in_mbps     = 1000
  
  sku {
    tier   = "Premium"
    family = "MeteredData"
  }
}
```

#### **Ansible Variables (group_vars/azure.yml)**

```yaml
---
platform: azure
cloud_provider: azure

# State Store (Azure Blob)
usmt_store_type: azure_blob
usmt_storage_account: "stmigusmt{{ org_id }}"
usmt_storage_container: "usmt-states"
usmt_blob_tier: "Hot"  # Hot tier for active waves

# Secrets Management
secrets_backend: azure_keyvault
azure_keyvault_name: "kv-migration-{{ org_id }}"

# Database
reporting_db_type: azure_postgres_flexible
reporting_db_fqdn: "{{ terraform_output.postgres_fqdn }}"

# Backup Strategy
backup_method: azure_vm_backup
recovery_services_vault: "rsv-migration-{{ org_id }}"

# Network
vnet_id: "{{ terraform_output.vnet_id }}"
expressroute_circuit_id: "{{ terraform_output.expressroute_id }}"

# Monitoring
monitoring_backend: azure_monitor
log_analytics_workspace_id: "{{ terraform_output.law_id }}"

# Managed Identity
use_managed_identity: true
```

---

### 3.3 GCP Implementation

#### **Infrastructure (Terraform)**

```hcl
# infrastructure/gcp/main.tf
# VPC Network
resource "google_compute_network" "migration_control" {
  name                    = "vpc-migration-control"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "control_plane" {
  name          = "subnet-control-plane"
  ip_cidr_range = "10.100.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.migration_control.id
}

# Cloud Storage Bucket for USMT State Store
resource "google_storage_bucket" "usmt_states" {
  name     = "migration-usmt-states-${var.org_id}"
  location = var.gcp_region
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90
    }
  }
  
  encryption {
    default_kms_key_name = google_kms_crypto_key.usmt.id
  }
}

# Secret Manager
resource "google_secret_manager_secret" "domain_admin" {
  secret_id = "migration-domain-admin"
  
  replication {
    automatic = true
  }
}

# Cloud SQL (PostgreSQL)
resource "google_sql_database_instance" "migration_db" {
  name             = "migration-db-${var.org_id}"
  database_version = "POSTGRES_14"
  region           = var.gcp_region
  
  settings {
    tier              = "db-custom-4-16384"  # 4 vCPU, 16 GB RAM
    availability_type = "REGIONAL"
    disk_size         = 1000
    disk_type         = "PD_SSD"
    
    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
    }
  }
}

# Compute Instances for AWX Runners
resource "google_compute_instance" "awx_runner" {
  count        = var.runner_count
  name         = "awx-runner-${count.index + 1}"
  machine_type = "n2-standard-8"  # 8 vCPU, 32 GB RAM
  zone         = "${var.gcp_region}-a"
  
  boot_disk {
    initialize_params {
      image = "rhel-cloud/rhel-8"
      size  = 500
      type  = "pd-ssd"
    }
  }
  
  network_interface {
    subnetwork = google_compute_subnetwork.control_plane.id
  }
  
  service_account {
    scopes = ["cloud-platform"]
  }
}

# Cloud Interconnect (for on-prem connectivity)
resource "google_compute_interconnect_attachment" "migration" {
  name                     = "interconnect-migration"
  interconnect             = var.interconnect_url
  router                   = google_compute_router.migration.id
  region                   = var.gcp_region
  bandwidth                = "BPS_1G"
}
```

---

### 3.4 Hyper-V (On-Prem) Implementation

#### **Infrastructure (PowerShell DSC / Ansible)**

```powershell
# infrastructure/hyperv/deploy_control_plane.ps1
# Create VMs for AWX runners on Hyper-V

$VMConfig = @{
    Name = "AWX-Runner-01"
    MemoryStartupBytes = 32GB
    Generation = 2
    BootDevice = "VHD"
    NewVHDPath = "D:\VMs\AWX-Runner-01\disk.vhdx"
    NewVHDSizeBytes = 500GB
    SwitchName = "Migration-vSwitch"
}

New-VM @VMConfig

# Configure processors
Set-VMProcessor -VMName "AWX-Runner-01" -Count 8

# Add data disk for state store
New-VHD -Path "D:\StateStore\usmt-states.vhdx" -SizeBytes 10TB -Dynamic
Add-VMHardDiskDrive -VMName "StateStore-01" -Path "D:\StateStore\usmt-states.vhdx"

# Create Storage Spaces for USMT state store
$PhysicalDisks = Get-PhysicalDisk -CanPool $true
New-StoragePool -FriendlyName "MigrationPool" -StorageSubSystemFriendlyName "Windows Storage*" -PhysicalDisks $PhysicalDisks

New-VirtualDisk -StoragePoolFriendlyName "MigrationPool" -FriendlyName "StateStore" -Size 10TB -ResiliencySettingName "Mirror" -ProvisioningType Thin

# Format and mount
Get-VirtualDisk -FriendlyName "StateStore" | Get-Disk | Initialize-Disk -PartitionStyle GPT
New-Volume -DiskNumber 2 -FriendlyName "StateStore" -FileSystem NTFS -DriveLetter S
```

#### **Ansible Variables (group_vars/hyperv.yml)**

```yaml
---
platform: hyperv
cloud_provider: on-prem
virtualization: hyperv

# State Store (SMB on Hyper-V file server)
usmt_store_type: smb
usmt_smb_share: "\\\\statestore-01\\StateStore$"
usmt_smb_username: "DOMAIN\\MigrationSvc"

# Secrets Management (local Ansible Vault)
secrets_backend: ansible_vault

# Database (PostgreSQL on VM)
reporting_db_type: postgres_vm
reporting_db_host: "postgres-01.migration.local"

# Backup Strategy
backup_method: hyperv_checkpoints
checkpoint_prefix: "migration"

# Network
hyperv_switch: "Migration-vSwitch"
vlan_id: 100

# Monitoring
monitoring_backend: prometheus_local
```

**Playbook: `hyperv_checkpoint.yml`**

```yaml
---
- name: Hyper-V - Create VM Checkpoints (Snapshots)
  hosts: hyperv_host
  gather_facts: no

  tasks:
    - name: Create checkpoint for AWX VM
      win_shell: |
        Checkpoint-VM -Name "AWX-Runner-01" -SnapshotName "Pre-Wave-{{ wave }}-{{ ansible_date_time.epoch }}"
      register: checkpoint_awx

    - name: Create checkpoint for Postgres VM
      win_shell: |
        Checkpoint-VM -Name "Postgres-01" -SnapshotName "Pre-Wave-{{ wave }}-{{ ansible_date_time.epoch }}"

    - name: Prune old checkpoints (>30 days)
      win_shell: |
        $cutoff = (Get-Date).AddDays(-30)
        Get-VMSnapshot -VMName "AWX-Runner-01" | 
          Where-Object {$_.CreationTime -lt $cutoff} | 
          Remove-VMSnapshot -Confirm:$false
```

---

### 3.5 vSphere (VMware) Implementation

#### **Infrastructure (Terraform with vSphere Provider)**

```hcl
# infrastructure/vsphere/main.tf
provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_password
  vsphere_server = var.vsphere_server
  
  allow_unverified_ssl = false
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# AWX Runner VM
resource "vsphere_virtual_machine" "awx_runner" {
  count            = var.runner_count
  name             = "awx-runner-${count.index + 1}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id
  
  num_cpus = 8
  memory   = 32768
  guest_id = "rhel8_64Guest"
  
  network_interface {
    network_id = data.vsphere_network.network.id
  }
  
  disk {
    label = "disk0"
    size  = 500
    thin_provisioned = true
  }
  
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id
  }
}

# NFS Datastore for USMT State Store
resource "vsphere_nas_datastore" "usmt_states" {
  name            = "StateStore-NFS"
  host_system_ids = [data.vsphere_host.esxi.*.id]
  
  type         = "NFS"
  remote_hosts = ["nfs-server.migration.local"]
  remote_path  = "/export/usmt-states"
}
```

#### **Ansible Variables (group_vars/vsphere.yml)**

```yaml
---
platform: vsphere
cloud_provider: on-prem
virtualization: vmware

# State Store (NFS on vSphere)
usmt_store_type: nfs
usmt_nfs_server: "nfs-server.migration.local"
usmt_nfs_export: "/export/usmt-states"
usmt_nfs_mount: "/mnt/statestore"

# Secrets Management
secrets_backend: ansible_vault

# Database
reporting_db_type: postgres_vm
reporting_db_host: "postgres-01.migration.local"

# Backup Strategy
backup_method: vsphere_snapshots
vcenter_server: "vcenter.migration.local"

# Storage
vsphere_datastore: "SAN-LUN-01"
vsphere_cluster: "Migration-Cluster"

# Monitoring
monitoring_backend: prometheus_local
```

**Playbook: `vsphere_snapshot.yml`**

```yaml
---
- name: vSphere - Create VM Snapshots
  hosts: localhost
  gather_facts: no

  tasks:
    - name: Create snapshot for AWX runners
      vmware_guest_snapshot:
        hostname: "{{ vcenter_server }}"
        username: "{{ vcenter_user }}"
        password: "{{ vcenter_password }}"
        datacenter: "{{ datacenter }}"
        folder: "/Migration"
        name: "{{ item }}"
        snapshot_name: "Pre-Wave-{{ wave }}-{{ ansible_date_time.epoch }}"
        description: "Automated snapshot before wave {{ wave }}"
        state: present
        validate_certs: no
      loop:
        - "AWX-Runner-01"
        - "AWX-Runner-02"
        - "Postgres-01"
      register: snapshots

    - name: Remove old snapshots (>30 days)
      vmware_guest_snapshot:
        hostname: "{{ vcenter_server }}"
        username: "{{ vcenter_user }}"
        password: "{{ vcenter_password }}"
        datacenter: "{{ datacenter }}"
        name: "{{ item.0 }}"
        snapshot_name: "{{ item.1.name }}"
        state: absent
      loop: "{{ vm_old_snapshots }}"
      when: item.1.create_time < cutoff_date
```

---

### 3.6 OpenStack Implementation

#### **Infrastructure (Terraform with OpenStack Provider)**

```hcl
# infrastructure/openstack/main.tf
provider "openstack" {
  auth_url    = var.openstack_auth_url
  user_name   = var.openstack_user
  password    = var.openstack_password
  tenant_name = var.openstack_tenant
  region      = var.openstack_region
}

# Network
resource "openstack_networking_network_v2" "migration_control" {
  name           = "migration-control-network"
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "migration_subnet" {
  name       = "migration-subnet"
  network_id = openstack_networking_network_v2.migration_control.id
  cidr       = "10.100.0.0/24"
  ip_version = 4
}

# Storage Volume for State Store
resource "openstack_blockstorage_volume_v3" "usmt_states" {
  name = "usmt-state-store"
  size = 10240  # 10 TB
  volume_type = "ssd"
}

# Compute Instances for AWX Runners
resource "openstack_compute_instance_v2" "awx_runner" {
  count           = var.runner_count
  name            = "awx-runner-${count.index + 1}"
  image_name      = "RHEL-8"
  flavor_name     = "m1.xlarge"  # 8 vCPU, 32 GB RAM
  key_pair        = var.keypair_name
  security_groups = ["migration-sg"]
  
  network {
    uuid = openstack_networking_network_v2.migration_control.id
  }
  
  block_device {
    uuid                  = data.openstack_images_image_v2.rhel8.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 500
    delete_on_termination = true
  }
}

# Object Storage (Swift) for USMT States
resource "openstack_objectstorage_container_v1" "usmt_states" {
  name = "migration-usmt-states"
  
  versioning {
    type    = "versions"
    location = "migration-usmt-states-archive"
  }
}
```

---

## 4) Hybrid/Multi-Cloud Strategy

### 4.1 Use Case

**Scenario:** On-prem source domain, hybrid target (some resources in Azure, some on-prem)

**Branch:** `platform/hybrid`

**Key Challenges:**
- State stores must be accessible from both cloud and on-prem
- Runners in both locations
- Network connectivity (VPN/ExpressRoute/DirectConnect)
- Secret synchronization across environments

---

### 4.2 Hybrid Architecture

```
┌──────────────────────────────────────────────────────┐
│                  On-Premises                         │
│  ┌─────────────────┐      ┌────────────────────┐    │
│  │ Source AD/Users │      │ Target AD (Hybrid) │    │
│  └─────────────────┘      └────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ AWX Runner (On-Prem)                        │    │
│  │  - Migrates on-prem servers                 │    │
│  │  - Accesses local state store               │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ State Store (on-prem)                       │    │
│  │  - SMB/NFS for on-prem workstations         │    │
│  └─────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
                         │
                         │ VPN/ExpressRoute
                         ▼
┌──────────────────────────────────────────────────────┐
│                   Azure Cloud                        │
│  ┌─────────────────────────────────────────────┐    │
│  │ Entra Connect (Hybrid Join)                 │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ AWX Runner (Azure)                          │    │
│  │  - Migrates cloud-bound workstations        │    │
│  │  - Accesses Azure Blob state store          │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ State Store (Azure Blob)                    │    │
│  │  - For Azure VMs and remote workers         │    │
│  └─────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────┐    │
│  │ PostgreSQL (Azure Database)                 │    │
│  │  - Centralized reporting for all runners    │    │
│  └─────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────┘
```

**Inventory Split:**

```ini
# inventories/hybrid/hosts.ini
[awx_runners_onprem]
awx-runner-onprem-01 ansible_host=10.0.1.10

[awx_runners_azure]
awx-runner-azure-01 ansible_host=10.100.1.10

[workstations_onprem]
# Workstations staying on-prem (use SMB state store)

[workstations_azure]
# Workstations moving to Azure VMs (use Blob state store)

[servers_onprem]
# Servers staying on-prem

[servers_azure]
# Servers lifting to Azure IaaS
```

**Variables:**

```yaml
# group_vars/workstations_onprem.yml
usmt_store_type: smb
usmt_smb_share: "\\\\statestore-onprem\\StateStore$"
migration_runner: awx-runner-onprem-01

# group_vars/workstations_azure.yml
usmt_store_type: azure_blob
usmt_storage_account: "stmigusmt{{ org_id }}"
usmt_storage_container: "usmt-states-azure"
migration_runner: awx-runner-azure-01
```

---

## 5) Platform Selection Matrix

| Criterion | AWS | Azure | GCP | Hyper-V | vSphere | OpenStack |
|-----------|-----|-------|-----|---------|---------|-----------|
| **Best For** | Cloud-first orgs | Microsoft shops | Data-heavy workloads | Windows-centric | VMware existing | Open-source orgs |
| **State Store** | S3 (versioning) | Blob (versioning) | GCS (versioning) | SMB/DFS-R | NFS/vSAN | Swift/Ceph |
| **Secrets** | Secrets Manager | Key Vault | Secret Manager | Ansible Vault | Ansible Vault | Ansible Vault |
| **Database** | RDS Postgres | Azure DB Postgres | Cloud SQL | VM-based | VM-based | VM-based |
| **Backup** | EBS snapshots, AMIs | VM backups, disk snapshots | Persistent disk snapshots | Hyper-V checkpoints | vSphere snapshots | Volume snapshots |
| **Network** | VPN/Direct Connect | ExpressRoute | Cloud Interconnect | Site-to-site VPN | Site-to-site VPN | VPN/GRE tunnels |
| **Cost (Tier 2)** | $3k-5k/month | $3k-5k/month | $2.5k-4k/month | $1k-2k/month | $1k-2k/month | $500-1k/month |
| **Complexity** | Medium | Medium | Medium | Low | Low | High |
| **HA Options** | Multi-AZ, Auto Scaling | Availability Zones, VMSS | Regional, MIGs | Clustering | vSphere HA, DRS | Ceph replication |

---

## 6) Implementation Workflow

### 6.1 Choose Your Platform Branch

```bash
# Clone the repo
git clone https://github.com/yourorg/migration-automation.git
cd migration-automation

# Checkout your platform branch
git checkout platform/azure  # or aws, gcp, vsphere, hyperv, openstack
```

---

### 6.2 Deploy Infrastructure

**AWS:**
```bash
cd infrastructure/aws
terraform init
terraform plan -var-file=prod.tfvars
terraform apply
```

**Azure:**
```bash
cd infrastructure/azure
terraform init
terraform plan -var-file=prod.tfvars
terraform apply
```

**vSphere:**
```bash
cd infrastructure/vsphere
terraform init
terraform plan -var-file=prod.tfvars
terraform apply
```

---

### 6.3 Configure Ansible Variables

```bash
# Edit platform-specific variables
vim inventories/tier2_azure/group_vars/all.yml

# Adjust for your environment
org_id: "acme"
azure_region: "eastus"
usmt_storage_account: "stmigusmtacme"
resource_group: "rg-migration-prod"
```

---

### 6.4 Test Platform-Specific Features

```bash
# Test state store access
ansible-playbook -i inventories/tier2_azure/hosts.ini \
  playbooks/00h_test_state_store.yml

# Test secrets retrieval
ansible-playbook -i inventories/tier2_azure/hosts.ini \
  playbooks/00i_test_secrets.yml

# Test backup/snapshot capability
ansible-playbook -i inventories/tier2_azure/hosts.ini \
  playbooks/01_pre_wave_snapshot.yml --check
```

---

## 7) Platform-Specific Considerations

### 7.1 AWS-Specific

**Advantages:**
- S3 versioning provides snapshot-like capability without ZFS
- Mature ecosystem (Terraform, CloudFormation, extensive modules)
- AWS Systems Manager for secret rotation

**Challenges:**
- VPN bandwidth may limit state store throughput (use Direct Connect)
- Cross-region latency if on-prem is far from AWS region

**Recommendations:**
- Use S3 Transfer Acceleration for USMT uploads from on-prem
- Deploy runners in same region as state store (minimize egress costs)
- Use VPC endpoints for S3 access (avoid internet routing)

---

### 7.2 Azure-Specific

**Advantages:**
- Native integration with Entra ID (Azure AD)
- ExpressRoute for high-bandwidth on-prem connectivity
- Azure Site Recovery can augment migration (for lift-and-shift servers)

**Challenges:**
- Azure Blob storage slightly slower than S3 for small files
- Managed identity configuration requires careful RBAC

**Recommendations:**
- Use Azure Files (SMB) instead of Blob for USMT if Windows-centric
- Leverage Azure AD PIM for just-in-time admin access
- Use Azure Policy to enforce encryption and tagging

---

### 7.3 GCP-Specific

**Advantages:**
- Cheapest storage ($0.020/GB for Standard vs. $0.023 S3)
- Cloud Interconnect often cheaper than AWS Direct Connect
- BigQuery can augment reporting (analyze migration telemetry at scale)

**Challenges:**
- Smaller ecosystem, fewer Ansible modules
- Less mature hybrid identity (Entra Connect doesn't run in GCP natively)

**Recommendations:**
- Use GCS signed URLs for secure USMT upload without VPN
- Deploy Entra Connect on-prem or in Azure (not GCP)
- Use Cloud Functions for lightweight automation (e.g., auto-prune old states)

---

### 7.4 Hyper-V-Specific

**Advantages:**
- Zero cloud costs
- Native Windows management (PowerShell, SCVMM)
- Storage Spaces provides software-defined storage

**Challenges:**
- Limited scalability vs. cloud (hardware-bound)
- Manual infrastructure provisioning

**Recommendations:**
- Use DFS-R for state store replication across sites
- Leverage System Center for orchestration if available
- Consider Azure Stack HCI for hybrid capabilities

---

### 7.5 vSphere-Specific

**Advantages:**
- VMware ecosystem maturity
- vMotion enables zero-downtime runner maintenance
- vSAN provides distributed storage

**Challenges:**
- Licensing costs for vSphere features (HA, DRS, vSAN)
- Terraform vSphere provider less mature than AWS/Azure

**Recommendations:**
- Use vSphere tags for migration tracking
- Leverage vRealize Orchestrator for advanced workflows
- Deploy vCenter HA for control plane resilience

---

### 7.6 OpenStack-Specific

**Advantages:**
- Open-source, no vendor lock-in
- Cost-effective at scale
- Ceph/Swift object storage

**Challenges:**
- Requires OpenStack expertise
- Fewer managed services

**Recommendations:**
- Use Ceph for unified block + object storage
- Leverage Heat templates for infrastructure as code
- Deploy Ansible Tower (upstream of AWX) if budget allows

---

## 8) Cost Comparison (Tier 2, 3,000 users, 4-month project)

| Platform | Compute | Storage | Network | Backup | Total |
|----------|---------|---------|---------|--------|-------|
| **AWS** | $2,500 (EC2) | $1,200 (S3) | $800 (VPN) | $300 (snapshots) | **$4,800/mo** |
| **Azure** | $2,400 (VMs) | $1,100 (Blob) | $900 (ExpressRoute) | $300 (backups) | **$4,700/mo** |
| **GCP** | $2,100 (Compute) | $1,000 (GCS) | $700 (Interconnect) | $200 (snapshots) | **$4,000/mo** |
| **Hyper-V** | $0 (existing) | $500 (disks) | $0 (existing) | $0 (checkpoints) | **$500/mo** |
| **vSphere** | $0 (existing) | $400 (storage) | $0 (existing) | $0 (snapshots) | **$400/mo** |
| **OpenStack** | $800 (VMs) | $200 (Ceph) | $0 (existing) | $0 (snapshots) | **$1,000/mo** |

**4-month project:**
- AWS: $19,200
- Azure: $18,800
- GCP: $16,000
- Hyper-V: $2,000
- vSphere: $1,600
- OpenStack: $4,000

**[Note: Excludes labor, USMT licenses, on-prem hardware depreciation]**

---

## 9) Summary & Recommendations

### Start with Your Existing Platform

**If you already have:**
- **AWS** → Use `platform/aws` branch
- **Azure** → Use `platform/azure` branch
- **VMware** → Use `platform/vsphere` branch
- **Hyper-V** → Use `platform/hyperv` branch
- **OpenStack** → Use `platform/openstack` branch
- **Hybrid** → Use `platform/hybrid` branch and adapt

### Don't Over-Architect

**For Tier 1 (Demo/POC):**
- Use whatever platform you have
- Don't deploy new infrastructure for a 500-user pilot

**For Tier 2/3 (Production):**
- Choose platform based on:
  1. Existing investments
  2. Team expertise
  3. Budget constraints
  4. Hybrid requirements

### Platform-Agnostic Core is Key

**The migration logic doesn't change:**
- AD export/provision works the same everywhere
- USMT works the same everywhere
- Domain joins work the same everywhere

**Only infrastructure changes:**
- Where state stores live (S3 vs. Blob vs. SMB)
- Where secrets come from (Secrets Manager vs. Key Vault vs. Ansible Vault)
- How backups work (EBS snapshots vs. Hyper-V checkpoints vs. ZFS snapshots)

**Recommendation:** Start with `main` branch, adapt infrastructure layer as needed.

---

**END OF DOCUMENT**

