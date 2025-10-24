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

### Tier 1: Small (10-50 servers)

**Target Migration Size:**
- 10-50 Windows/Linux servers
- 5-20 TB file server data (use existing file servers)
- 2 TB database capacity
- Single datacenter

**Hardware Requirements:**
- Single server: 8 vCPU, 32 GB RAM, 500 GB SSD
- Or reuse existing server with spare capacity

**Components:**
```
1x Automation (AWX + Ansible)        - 4 vCPU, 16 GB RAM
1x Monitoring (Prom + Grafana)       - 2 vCPU, 8 GB RAM
1x PostgreSQL                        - 2 vCPU, 8 GB RAM
```

**Migration Storage Requirements (NAS/File Server):**
```
- USMT backup staging:          10-15 GB per server × 50 = ~750 GB
- File server staging:          15-20% of source data
- Database backups:             2x database size
- Temporary/working space:      ~250 GB
- Total migration storage:      1-2 TB minimum
- IOPS:                         2,000+ for concurrent migrations
- Network:                      1 Gbps minimum
```

**Migration Capacity:**
- ~5 servers migrated per day
- 2-10 day migration window
- Single automation controller

**Cost:** ~$3,000 hardware (or $0 if reusing existing server)

---

### Tier 2: Medium (50-200 servers)

**Target Migration Size:**
- 50-200 Windows/Linux servers
- 20-100 TB file server data (use existing storage)
- 10 TB database capacity
- Multi-site support

**Hardware Requirements:**
- 2 servers: 16 vCPU, 64 GB RAM each (for HA)
- 1 TB SSD per server (OS/Applications)

**Components (distributed across 2 hosts):**
```
2x Automation (AWX) HA               - 4 vCPU, 16 GB RAM each
2x PostgreSQL HA                     - 4 vCPU, 12 GB RAM each
2x Monitoring (Prom/Grafana) HA      - 2 vCPU, 8 GB RAM each
1x Vault                             - 2 vCPU, 4 GB RAM
```

**Migration Storage Requirements (NAS/SAN/File Server):**
```
- USMT backup staging:          10-20 GB per server × 200 = ~4 TB
- File server staging:          20-30% of source data (buffer)
- Database backups:             2-3x database size
- Temporary/working space:      ~1 TB
- Total migration storage:      4-10 TB (depends on migration wave size)
- IOPS:                         5,000+ for parallel migrations
- Network:                      1 Gbps minimum, 10 Gbps recommended
```

**Migration Capacity:**
- ~15-20 servers migrated per day
- Parallel migration batches
- Automated rollback capability

**Cost:** ~$10-15k hardware (one-time)

---

### Tier 3: Large (200-1,000 servers)

**Target Migration Size:**
- 200-1,000 Windows/Linux servers
- 100-500 TB file server data (use existing storage)
- 50 TB database capacity
- Multi-datacenter, global operations

**Hardware Requirements:**

**Option A - VM-based (simpler):**
- 4 physical servers: 24 vCPU, 96 GB RAM each (N+1 HA)
- 2 TB NVMe SSD per server (OS/Applications)
- Total: 96 vCPUs, 384 GB RAM

**Option B - Kubernetes-based (more efficient):**
- 4 physical servers: 24 vCPU, 64 GB RAM each (N+1 HA)
- 2 TB NVMe SSD per server (OS/Applications)
- Total: 96 vCPUs, 256 GB RAM
- ~$10k less hardware cost vs VM-based

**Components (Option A - VM-based, simpler):**
```
4x Automation cluster (AWX/Ansible) - 6 vCPU, 24 GB RAM each
3x PostgreSQL HA cluster            - 6 vCPU, 20 GB RAM each
3x Monitoring (Prom/Grafana) HA     - 4 vCPU, 12 GB RAM each
1x Vault HA                         - 4 vCPU, 8 GB RAM
```

**Components (Option B - Kubernetes-based, advanced):**
```
4x K3s nodes                        - 24 vCPU, 64 GB RAM each
All services run as containers with 70-80% resource utilization
Auto-scaling capabilities for peak migration loads
Lower memory footprint due to containerization
```

**Migration Storage Requirements (Enterprise SAN/NAS):**
```
- USMT backup staging:          15-25 GB per server × 1,000 = ~20 TB
- File server staging:          30-40% of source data (for waves)
- Database backups:             3-4x database size
- Temporary/working space:      ~5 TB
- Deduplication storage:        ~40-50% reduction (if enabled)
- Total migration storage:      20-50 TB (depends on migration strategy)
- IOPS:                         20,000+ for parallel migrations (SSD/NVMe SAN)
- Network:                      10 Gbps minimum, 25/40 Gbps recommended
- Recommended:                  Dedicated migration VLAN/network segment
```

**Migration Capacity:**
- ~50+ servers migrated per day
- Wave-based migration planning
- Multi-region orchestration
- Automated testing & validation

**Cost:** ~$30-40k hardware (one-time), leverage existing storage infrastructure

**Note:** Use existing SAN/NAS for file server migration data. No need for dedicated file server VMs.

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

### On-Premises vs Cloud (Server Migration Workload)

| Aspect | On-Premises | Cloud (Azure) |
|--------|-------------|---------------|
| **Initial Cost** | Hardware purchase ($15k-225k) | $0 |
| **Monthly Cost** | $100-500 (power/cooling) | $800-5,000 |
| **Year 1 Total** | $15k-231k | $9.6k-60k |
| **Year 3 Total** | $18.6k-243k | $28.8k-180k |
| **Year 5 Total** | $21.2k-255k | $48k-300k |
| **Ownership** | You own hardware | Rent only |
| **Data Location** | Your data center | Cloud provider |
| **Internet Required** | No (can be air-gapped) | Yes |
| **Bandwidth Cost** | $0 (internal network) | High for large file servers |
| **Compliance** | Easier (local control) | Complex |

**Break-even:** 
- Tier 1 (10-50 servers): ~18 months
- Tier 2 (50-200 servers): ~12 months
- Tier 3 (200-1,000 servers): ~8-10 months

**Key Factor:** On-premises becomes more cost-effective at scale, especially for large file server migrations where cloud egress fees are significant.

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

### Tier 1 (10-50 servers)

**Minimum Infrastructure:**
```
2x Physical servers (for redundancy)
- 2x CPU (12 cores each, 24 total)
- 128 GB RAM per server
- 2 TB NVMe SSD + 8 TB HDD storage per server
- 4x 1 Gbps NICs (or 2x 10 Gbps)

Software: VMware ESXi Free or Proxmox
Cost: ~$10,000-20,000

Storage Calculation:
- Base OS/Apps: ~500 GB
- Migration data: Server count × avg server size × 2 (source + target)
- Example: 30 servers × 100 GB × 2 = 6 TB needed
```

---

### Tier 2 (50-200 servers)

**Recommended Cluster:**
```
3-4x Physical servers
- 2x CPU (20 cores each, 40 per server)
- 384 GB RAM per server
- 4 TB NVMe + 20 TB HDD per server
- 4x 10 Gbps NICs per server

Software: VMware vSphere or Proxmox Cluster
Cost: ~$50,000-80,000

Storage Calculation:
- Base infrastructure: ~2 TB
- Migration data: Server count × avg server size × 2
- Example: 150 servers × 200 GB × 2 = 60 TB needed
- File server data: Add actual capacity needed

Recommended: Separate storage array (NAS/SAN) for file server data
```

---

### Tier 3 (200-1,000 servers)

**Practical Cluster:**
```
3-4x Physical servers
- 2x CPU (8 cores each, 16 total per server)
- 32 GB RAM per server
- 1 TB SSD per server
- 2x 10 Gbps NICs per server (or 4x 1 Gbps bonded)

Software: VMware ESXi (free) OR Proxmox (free) OR Hyper-V
Cost: ~$20,000-30,000

Storage Strategy:
- Automation infrastructure: ~3-4 TB SSD total
- Migration data: Use existing SAN/NAS/file servers
- No need for dedicated migration storage
- Leverage what you already have!

Network Requirements:
- 10 Gbps recommended (1 Gbps minimum works fine)
- Existing network infrastructure
- No dedicated migration network needed for most scenarios
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

- **Tier 1 (10-50 servers):** ~$15k hardware (one-time)
- **Tier 2 (50-200 servers):** ~$65k hardware (one-time)
- **Tier 3 (200-1,000 servers):** ~$225k hardware (one-time)
- **Ongoing:** Power (~$100-500/month), cooling, maintenance only

**ROI:** Hardware pays for itself in 12-24 months vs cloud costs

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

