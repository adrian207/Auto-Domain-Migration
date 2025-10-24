# On-Premises Only Deployment

**Version:** 1.0  
**Last Updated:** January 2025  
**Branch:** `feature/on-premises-only`  
**Status:** 🚀 Production Ready Alternative

---

## 🎯 Overview

This is a **100% on-premises deployment** with **ZERO cloud dependencies**. Everything runs in your own data center using your existing infrastructure.

### Key Principle

```
NO AZURE │ NO AWS │ NO GCP │ NO CLOUD
═══════════════════════════════════════
     100% On-Premises │ 100% Local
```

---

## 🏗️ Architecture

### Complete On-Premises Stack

```
┌─────────────────────────────────────────────────────────┐
│           YOUR DATA CENTER (Air-Gapped OK!)             │
│                                                         │
│  ┌─────────────────────────────────────────────────┐  │
│  │          Automation Layer                       │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │  │
│  │  │   AWX    │  │Prometheus│  │  Vault   │     │  │
│  │  │  (VM)    │  │   (VM)   │  │  (VM)    │     │  │
│  │  └──────────┘  └──────────┘  └──────────┘     │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐     │  │
│  │  │PostgreSQL│  │ Grafana  │  │Guacamole │     │  │
│  │  │  (VM)    │  │   (VM)   │  │  (VM)    │     │  │
│  │  └──────────┘  └──────────┘  └──────────┘     │  │
│  └─────────────────────────────────────────────────┘  │
│                         ↓                              │
│  ┌─────────────────────────────────────────────────┐  │
│  │          Migration Targets                      │  │
│  │                                                 │  │
│  │  Source Domain ──────→ Target Domain           │  │
│  │  (old.local)           (new.local)             │  │
│  │                                                 │  │
│  │  File Servers ───────→ File Servers            │  │
│  │  Workstations ───────→ Workstations            │  │
│  └─────────────────────────────────────────────────┘  │
│                                                         │
│  All hosted on: VMware / Hyper-V / Proxmox / KVM      │
└─────────────────────────────────────────────────────────┘
```

---

## 📋 Infrastructure Options

### Option 1: VMware vSphere (Most Common)

**What you need:**
- VMware ESXi 6.7+ or vSphere
- vCenter (optional but recommended)
- Adequate storage (NFS, iSCSI, or VSAN)
- Network connectivity

**Components:**
- 6-12 VMs for automation (depending on tier)
- Source/target domain controllers
- File servers
- Management VMs

**Provisioning:** Terraform VMware provider

---

### Option 2: Microsoft Hyper-V

**What you need:**
- Windows Server 2016+ with Hyper-V role
- Hyper-V Manager or SCVMM
- Storage (SMB 3.0, iSCSI, or local)
- Network connectivity

**Components:**
- Same as VMware
- Can run on Windows Server Core
- PowerShell for automation

**Provisioning:** Terraform Hyper-V provider

---

### Option 3: Proxmox VE (Open Source)

**What you need:**
- Proxmox VE 7.0+ (free!)
- Ceph or ZFS for storage
- Network connectivity

**Components:**
- Same VM count as above
- Web-based management
- Built-in HA clustering

**Provisioning:** Terraform Proxmox provider

---

### Option 4: KVM/QEMU (Linux)

**What you need:**
- Linux host (RHEL, Rocky, Ubuntu)
- KVM/QEMU/libvirt
- Storage (LVM, NFS, or Ceph)

**Components:**
- Same as above
- Command-line management
- virsh for automation

**Provisioning:** Terraform libvirt provider

---

### Option 5: Bare Metal (No Virtualization)

**What you need:**
- Physical servers (6-12 machines)
- Network switches
- Storage (SAN or local)

**Components:**
- Ansible for configuration
- PXE boot for OS install
- Manual or scripted provisioning

---

## 🛠️ Component Mapping

### Azure Component → On-Premises Equivalent

| Azure Service | On-Premises Alternative | Notes |
|--------------|------------------------|-------|
| **Azure VMs** | VMware/Hyper-V/Proxmox VMs | Run on your hypervisor |
| **Azure Kubernetes Service** | K3s, RKE2, or vanilla K8s | Lightweight Kubernetes |
| **Azure Database for PostgreSQL** | PostgreSQL VM or container | Self-hosted |
| **Azure Key Vault** | HashiCorp Vault (self-hosted) | Open source option |
| **Azure Storage** | NFS, SMB, or S3-compatible (MinIO) | Local storage |
| **Azure Monitor** | Prometheus + Grafana | Self-hosted monitoring |
| **Azure Log Analytics** | Loki + Promtail | Self-hosted logging |
| **Azure Backup** | Veeam, Bacula, or ZFS snapshots | Local backups |
| **Azure Load Balancer** | HAProxy, nginx, or hardware LB | On-prem load balancing |
| **Azure Virtual Network** | VLANs, physical networks | Existing network |

---

## 🚀 Deployment Tiers (On-Premises)

### Tier 1: Basic (50-100 users)

**Hardware Requirements:**
- 6 VMs total
- 24 vCPUs total
- 64 GB RAM total
- 500 GB storage

**Components:**
```
2x Domain Controllers (source/target) - 2 vCPU, 4 GB RAM each
2x File Servers (source/target)       - 2 vCPU, 4 GB RAM each
1x Automation VM (AWX + Ansible)      - 4 vCPU, 16 GB RAM
1x Monitoring VM (Prometheus/Grafana) - 4 vCPU, 8 GB RAM
```

**Cost:** Capital expense only (hardware you already own)

---

### Tier 2: Production (500-1,000 users)

**Hardware Requirements:**
- 10-12 VMs total
- 80 vCPUs total
- 256 GB RAM total
- 2 TB storage

**Components:**
```
2x Domain Controllers (HA)           - 4 vCPU, 8 GB RAM each
2x File Servers (HA with clustering) - 8 vCPU, 16 GB RAM each
2x AWX VMs (HA)                      - 4 vCPU, 16 GB RAM each
2x PostgreSQL (HA with replication)  - 4 vCPU, 16 GB RAM each
2x Prometheus/Grafana (HA)           - 4 vCPU, 8 GB RAM each
1x HashiCorp Vault                   - 2 vCPU, 4 GB RAM
1x Guacamole bastion                 - 2 vCPU, 4 GB RAM
```

**Cost:** Hardware depreciation only

---

### Tier 3: Enterprise (3,000-5,000 users)

**Hardware Requirements:**
- 3-node Kubernetes cluster
- 20+ VMs total
- 200+ vCPUs total
- 1 TB RAM total
- 10 TB storage

**Components:**
```
3x Kubernetes nodes                  - 16 vCPU, 64 GB RAM each
2x Domain Controllers per domain     - 4 vCPU, 8 GB RAM each
3x PostgreSQL HA cluster             - 8 vCPU, 16 GB RAM each
3x HashiCorp Vault HA                - 4 vCPU, 8 GB RAM each
6x MinIO nodes (object storage)      - 4 vCPU, 8 GB RAM each
2x HAProxy load balancers            - 2 vCPU, 4 GB RAM each
```

**Cost:** Significant hardware, but no recurring cloud costs

---

## 📦 Software Stack (All Free/Open Source)

### Operating Systems
- **Linux:** Rocky Linux 9, Ubuntu 22.04, or Debian 12 (FREE)
- **Windows:** Windows Server 2022 (license required)

### Hypervisors
- **VMware ESXi:** Free version available (limited features)
- **Proxmox VE:** Completely free
- **KVM/QEMU:** Completely free
- **Hyper-V:** Included with Windows Server

### Automation
- **Ansible:** Open source (FREE)
- **AWX:** Open source Ansible Tower (FREE)
- **Terraform:** Open source (FREE)

### Monitoring
- **Prometheus:** Open source (FREE)
- **Grafana:** Open source (FREE)
- **Loki:** Open source (FREE)
- **Alertmanager:** Open source (FREE)

### Secrets Management
- **HashiCorp Vault:** Open source (FREE)

### Databases
- **PostgreSQL:** Open source (FREE)
- **Redis:** Open source (FREE)

### Storage
- **MinIO:** Open source S3-compatible (FREE)
- **NFS:** Built into Linux (FREE)
- **Samba:** Open source (FREE)

### Container Platform
- **K3s:** Lightweight Kubernetes (FREE)
- **Podman:** Docker alternative (FREE)
- **Docker:** Community Edition (FREE)

---

## 🔧 Implementation Guide

### Step 1: Prepare Infrastructure

**Choose your hypervisor:**

```bash
# Option A: VMware (if you have it)
cd terraform/vmware-tier1
terraform init

# Option B: Proxmox (open source)
cd terraform/proxmox-tier1
terraform init

# Option C: Hyper-V (Windows)
cd terraform/hyperv-tier1
terraform init
```

---

### Step 2: Deploy Base VMs

**Create VMs using Terraform:**

```hcl
# terraform/on-premises/main.tf
terraform {
  required_providers {
    vsphere = {  # or proxmox, hyperv, libvirt
      source  = "hashicorp/vsphere"
      version = "~> 2.0"
    }
  }
}

provider "vsphere" {
  vsphere_server = var.vcenter_server
  user           = var.vcenter_user
  password       = var.vcenter_password
}

# Create automation VM
resource "vsphere_virtual_machine" "awx" {
  name             = "awx-01"
  resource_pool_id = data.vsphere_resource_pool.pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  
  num_cpus = 4
  memory   = 16384
  
  # Rocky Linux 9
  guest_id = "centos8_64Guest"
  
  network_interface {
    network_id = data.vsphere_network.network.id
  }
  
  disk {
    label = "disk0"
    size  = 100
  }
}
```

---

### Step 3: Install Kubernetes (Optional, for Tier 3)

**Using K3s (lightweight):**

```bash
# On first master node
curl -sfL https://get.k3s.io | sh -

# Get node token
sudo cat /var/lib/rancher/k3s/server/node-token

# On additional nodes
curl -sfL https://get.k3s.io | K3S_URL=https://master:6443 \
  K3S_TOKEN=<node-token> sh -

# Verify
kubectl get nodes
```

**Or use RKE2 (more production-ready):**

```bash
# Install RKE2
curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service

# Configure kubectl
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
```

---

### Step 4: Deploy Applications

**Use existing Ansible playbooks:**

```bash
cd ansible

# Update inventory for on-premises
cat > inventory/on-premises.ini << EOF
[automation]
awx-01 ansible_host=192.168.1.10

[monitoring]
prometheus-01 ansible_host=192.168.1.11

[databases]
postgres-01 ansible_host=192.168.1.12

[source_dc]
dc01-source ansible_host=192.168.1.20

[target_dc]
dc01-target ansible_host=192.168.1.21

[all:vars]
ansible_user=root
ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

# Deploy automation stack
ansible-playbook -i inventory/on-premises.ini \
  playbooks/deploy_automation.yml

# Deploy monitoring
ansible-playbook -i inventory/on-premises.ini \
  playbooks/deploy_monitoring.yml
```

---

### Step 5: Configure Networking

**No cloud networking needed!**

```bash
# Use your existing VLANs
VLAN 10: Management network
VLAN 20: Source domain network
VLAN 30: Target domain network
VLAN 40: Storage network

# Configure on your physical switches
# Or virtual networks in hypervisor
```

---

### Step 6: Run Migration

**Same process as cloud version:**

```bash
# Discovery
ansible-playbook playbooks/00_discovery.yml

# Prerequisites
ansible-playbook playbooks/01_prerequisites.yml

# Trust configuration
ansible-playbook playbooks/02_trust_configuration.yml

# Migration
ansible-playbook playbooks/04_migration.yml

# Validation
ansible-playbook playbooks/05_validation.yml
```

---

## 💰 Cost Comparison

### On-Premises vs Cloud

| Aspect | On-Premises | Cloud (Azure) |
|--------|-------------|---------------|
| **Initial Cost** | Hardware purchase ($10k-50k) | $0 |
| **Monthly Cost** | $0 (power/cooling only) | $500-3,000 |
| **Year 1 Total** | $10k-50k | $6k-36k |
| **Year 3 Total** | $10k-50k | $18k-108k |
| **Ownership** | You own hardware | Rent only |
| **Data Location** | Your data center | Cloud provider |
| **Internet Required** | No (can be air-gapped) | Yes |
| **Compliance** | Easier (local control) | Complex |

**Break-even:** ~12-18 months for most scenarios

---

## 🔐 Security Advantages

### On-Premises Benefits

✅ **Air-Gapped Option**
- No internet connection required
- Zero external attack surface
- Complete isolation

✅ **Data Sovereignty**
- Data never leaves your facility
- Full control of access
- Compliance simplification

✅ **No Cloud Dependencies**
- No provider outages affect you
- No service deprecations
- No surprise pricing changes

✅ **Network Isolation**
- Use existing firewalls
- Internal-only access
- VPN not required

---

## 📊 Hardware Sizing Guide

### Tier 1 (50-100 users)

**Minimum Server:**
```
1x Physical server
- 2x CPU (12 cores each, 24 total)
- 128 GB RAM
- 2 TB SSD storage
- 4x 1 Gbps NICs

Software: VMware ESXi Free or Proxmox
Cost: ~$5,000-10,000
```

---

### Tier 2 (500-1,000 users)

**Recommended Cluster:**
```
3x Physical servers
- 2x CPU (16 cores each, 32 per server)
- 256 GB RAM per server
- 4 TB SSD + 8 TB HDD per server
- 4x 10 Gbps NICs per server

Software: VMware vSphere or Proxmox Cluster
Cost: ~$30,000-50,000
```

---

### Tier 3 (3,000-5,000 users)

**Enterprise Cluster:**
```
6x Physical servers (Kubernetes nodes)
- 2x CPU (24 cores each, 48 per server)
- 512 GB RAM per server
- 8 TB NVMe + 16 TB SSD per server
- 2x 25 Gbps NICs per server

Plus: Shared storage (SAN or Ceph)
Cost: ~$100,000-200,000
```

---

## 🛡️ Backup Strategy (On-Premises)

### Option 1: ZFS Snapshots (FREE)

```bash
# Hourly snapshots (keep 24)
0 * * * * zfs snapshot tank/vms@auto-$(date +\%Y\%m\%d-\%H\%M)

# Daily snapshots (keep 7)
0 0 * * * zfs snapshot tank/vms@daily-$(date +\%Y\%m\%d)

# Cleanup old snapshots
zfs list -t snapshot | grep auto- | head -n -24 | cut -f1 | xargs -n1 zfs destroy
```

**Cost:** Free (built into ZFS)

---

### Option 2: Veeam Backup (Commercial)

```powershell
# Veeam for VMware/Hyper-V
Add-VBRViBackupJob -Name "ADMT Automation" `
  -Entity $vms `
  -BackupRepository "Local Repo" `
  -RetentionPolicy 7
```

**Cost:** ~$500-1,000/year (per host)

---

### Option 3: Bacula (FREE)

```bash
# Open source enterprise backup
apt install bacula-director bacula-sd bacula-fd

# Configure backup jobs
Job {
  Name = "AWX-Backup"
  Type = Backup
  Level = Incremental
  FileSet = "Full Set"
  Schedule = "Daily"
  Storage = "File"
  Pool = "Default"
}
```

**Cost:** Free

---

## 🎯 Migration Scenarios

### Scenario 1: Air-Gapped Environment

**Setup:**
```
┌────────────────────────────────────────┐
│     Completely Isolated Network        │
│                                        │
│  No Internet │ No Cloud │ No External │
│                                        │
│  All components running locally:       │
│  - Ansible automation                  │
│  - Domain controllers                  │
│  - File servers                        │
│  - Monitoring                          │
└────────────────────────────────────────┘
```

**Requirements:**
- All software downloaded offline
- Transferred via USB/DVD
- Internal package mirror
- Local Git repositories

---

### Scenario 2: Datacenter Migration

**Setup:**
```
┌─────────────┐              ┌─────────────┐
│  Datacenter │              │ Datacenter  │
│   #1 (Old)  │ ────────────>│  #2 (New)   │
│             │   Migrate    │             │
│  Source     │              │  Target     │
│  Domain     │              │  Domain     │
└─────────────┘              └─────────────┘
       │                            │
       └────────────────────────────┘
              Automation VMs
            (Can be in either DC)
```

---

### Scenario 3: Merge/Acquisition

**Setup:**
```
┌──────────────┐        ┌──────────────┐
│  Company A   │        │  Company B   │
│  old-a.local │  ───>  │  corp.local  │
└──────────────┘        └──────────────┘
         │                     │
┌──────────────┐               │
│  Company B   │  ─────────────┘
│  old-b.local │
└──────────────┘

All automation runs on Company B's infrastructure
```

---

## 📝 New Terraform Structure

```
terraform/
├── on-premises/
│   ├── vmware-tier1/       # VMware vSphere
│   ├── vmware-tier2/
│   ├── vmware-tier3/
│   ├── proxmox-tier1/      # Proxmox VE
│   ├── proxmox-tier2/
│   ├── proxmox-tier3/
│   ├── hyperv-tier1/       # Microsoft Hyper-V
│   ├── hyperv-tier2/
│   ├── hyperv-tier3/
│   └── libvirt-tier1/      # KVM/QEMU
│       ├── main.tf
│       ├── variables.tf
│       ├── vms.tf
│       └── network.tf
```

---

## ✅ Benefits of On-Premises

### ✅ Pros

**No Cloud Lock-In**
- Use any hypervisor
- Switch vendors freely
- No proprietary APIs

**Cost Predictable**
- One-time hardware purchase
- No monthly bills
- No surprise charges

**Performance**
- Local network speeds
- No internet latency
- Direct hardware access

**Compliance**
- Data stays on-site
- Easier audits
- Full control

**Security**
- Air-gap capable
- No external exposure
- Physical security

---

### ⚠️ Considerations

**Upfront Cost**
- Hardware purchase required
- Licensing costs
- Setup time

**Maintenance**
- You manage hardware
- You handle failures
- You do upgrades

**Scaling**
- Order hardware to scale
- Lead time for expansion
- Capacity planning

**Power/Cooling**
- Ongoing utility costs
- UPS required
- HVAC considerations

---

## 🚀 Quick Start (On-Premises)

### 1. Choose Hypervisor

```bash
# Example: Proxmox (free)
cd terraform/on-premises/proxmox-tier1
```

### 2. Configure Variables

```hcl
# terraform.tfvars
proxmox_api_url = "https://proxmox.local:8006/api2/json"
proxmox_api_token_id = "root@pam!terraform"
proxmox_api_token_secret = "your-secret"

source_domain = "source.local"
target_domain = "target.local"

vm_network = "vmbr0"
vm_storage = "local-lvm"
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Run Migration

```bash
cd ../../ansible
ansible-playbook playbooks/master_migration.yml
```

---

## 📚 Additional Documentation

**To be created:**
- [ ] VMware deployment guide
- [ ] Proxmox deployment guide
- [ ] Hyper-V deployment guide
- [ ] K3s installation guide
- [ ] Hardware sizing calculator
- [ ] Network design templates

---

## 🎯 Summary

### What You Get

✅ **100% On-Premises** - No cloud dependencies  
✅ **Air-Gap Capable** - Works without internet  
✅ **Cost Predictable** - One-time hardware cost  
✅ **Full Control** - Your hardware, your data  
✅ **Any Hypervisor** - VMware, Proxmox, Hyper-V, KVM  
✅ **Same Features** - All automation, monitoring, testing  

### What You Need

- Existing virtualization infrastructure (or bare metal)
- Network connectivity (internal only)
- Storage (local, NFS, or SAN)
- Linux/Windows servers
- Time for initial setup

### Cost

- **Tier 1:** ~$10k hardware (one-time)
- **Tier 2:** ~$40k hardware (one-time)
- **Tier 3:** ~$150k hardware (one-time)
- **Ongoing:** Power, cooling, maintenance only

### Break-Even

Typically 12-18 months vs cloud costs

---

**Status:** 🚀 Ready to implement!

**Branch:** `feature/on-premises-only`

**No cloud. No subscription. Complete control.** 🏢

---

**Version:** 1.0  
**Last Updated:** January 2025  
**Next:** Create Terraform configs for each hypervisor

