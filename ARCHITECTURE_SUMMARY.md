# Architecture Summary - Container-First Approach

**Date:** October 2025  
**Architect:** Adrian Johnson

---

## 🎯 Solution Overview

A **fully containerized** Active Directory domain migration platform that eliminates traditional complexity:

- ❌ **No ISO management**
- ❌ **No binary downloads**
- ❌ **No manual installations**
- ✅ **Everything in containers**
- ✅ **Fully automated with Ansible**

---

## 🏗️ Azure Architecture (Production-Ready)

### Infrastructure Layer
```
Azure Subscription
├── Resource Group: admigration-prod-rg
│
├── Compute (Marketplace VMs - No ISOs)
│   ├── Rocky Linux 9 VMs (from RESF publisher)
│   │   ├── Guacamole Bastion (Docker pre-installed)
│   │   ├── Ansible Controller (Docker pre-installed)
│   │   └── Monitoring (Prometheus + Grafana containers)
│   │
│   └── Windows VMs (from Microsoft publisher)
│       ├── Source DC (Server 2022 - Marketplace)
│       ├── Target DC (Server 2022 - Marketplace)
│       └── Test Workstation (Windows 11 - Marketplace)
│
├── Database (Managed PostgreSQL)
│   ├── guacamole_db
│   ├── migration_state
│   ├── migration_telemetry
│   └── awx_db
│
├── Storage (Azure Blob)
│   ├── migration-artifacts (state files)
│   ├── usmt-backups (user profiles)
│   └── logs (audit trail)
│
└── Key Vault (Secrets - FREE tier)
    ├── admin-password
    ├── postgres-admin-password
    └── domain-credentials
```

**Licensing:**
- Linux: Free (Rocky Linux)
- Windows: Azure Marketplace (pay-as-you-go) OR Azure Hybrid Benefit

**Total Cost (Tier 2):** ~$900-1,400/month

---

## 🏗️ vSphere Architecture (On-Premises)

### Infrastructure Layer
```
vSphere Cluster
├── VM Templates (One-time setup)
│   ├── Rocky Linux 9 + Docker (from public ISO)
│   └── Windows Server Core + Docker (optional)
│
├── Container Runtime Options
│   ├── Option A: VMs with Docker (Simple)
│   │   └── Works on any vSphere version
│   │
│   ├── Option B: vSphere with Tanzu (Advanced)
│   │   ├── Kubernetes on vSphere
│   │   └── Native container orchestration
│   │
│   └── Option C: Photon OS (VMware Native)
│       └── Ultra-lightweight container host
│
└── Storage
    ├── Datastore: VM disks
    └── NFS/SMB: Migration artifacts
```

**Licensing:**
- Linux VMs: Free (Rocky Linux)
- Windows VMs: Use existing licenses (SPLA, Volume, etc)
- vSphere: Use existing vCenter license

**Total Cost (Tier 1):** $2-5k (hardware/storage only)

---

## 📦 Container Architecture

### Migration Tool Containers

```
Container Registry (Azure ACR or Harbor)
├── Linux Containers
│   ├── migration-controller:latest
│   │   └── Ansible + Python + WinRM
│   ├── guacamole/guacamole:latest
│   │   └── Remote desktop gateway
│   ├── prom/prometheus:latest
│   │   └── Metrics collection
│   └── grafana/grafana:latest
│       └── Dashboards
│
└── Windows Containers
    ├── admt-container:latest
    │   └── ADMT + PowerShell wrappers
    ├── usmt-container:latest
    │   └── USMT (from Windows ADK)
    └── migration-tools:latest
        └── Custom scripts + utilities
```

---

## 🔄 Migration Workflow

### Phase 1: Infrastructure Deployment (Terraform)
```bash
# Azure
cd terraform/azure-tier2
terraform apply
# Result: All VMs provisioned from marketplace, Docker installed

# vSphere
cd terraform/vsphere-tier2
terraform apply
# Result: VMs cloned from template, Docker pre-configured
```

### Phase 2: Container Preparation (One-Time)
```bash
# Build containers
cd containers
./build-all.sh

# Push to registry
./push-to-registry.sh
# Azure: Pushes to Azure Container Registry
# vSphere: Pushes to Harbor or external registry
```

### Phase 3: Migration Execution (Ansible)
```bash
# Bootstrap environment
ansible-playbook playbooks/00_bootstrap.yml
# - Pulls container images
# - Configures domain trusts
# - Validates connectivity

# Run migration
ansible-playbook playbooks/migrate_full.yml \
  --extra-vars "wave_number=1"

# Behind the scenes:
# 1. Ansible pulls migration-controller container
# 2. Controller pulls ADMT container on Source DC
# 3. ADMT migrates users/groups to Target DC
# 4. Controller pulls USMT container on workstations
# 5. USMT captures and restores user profiles
# 6. All state tracked in PostgreSQL
# 7. Metrics sent to Prometheus
# 8. Dashboards updated in Grafana
```

---

## 💡 Key Innovations

### 1. Zero Binary Management
```
Traditional:                    Container-Based:
├─ Download ADMT               ├─ docker pull admt-container
├─ Download USMT               ├─ docker pull usmt-container
├─ Download Sysinternals       ├─ docker pull migration-tools
├─ Verify checksums            ├─ (automatic)
├─ Install manually            ├─ (automatic)
└─ Update manually             └─ docker pull :latest
```

### 2. Azure Marketplace Integration
```
Traditional:                    Azure Marketplace:
├─ Download Windows ISO        ├─ Instant provisioning
├─ Upload to cloud             ├─ No upload needed
├─ Create VM from ISO          ├─ Select marketplace image
├─ Activate license            ├─ Licensing included
└─ 30-60 min setup             └─ 5 min setup
```

### 3. Immutable Infrastructure
```
Every deployment identical:
├─ Container images tagged with SHA
├─ Terraform state tracked
├─ Ansible playbooks versioned
└─ Full reproducibility
```

---

## 📊 Deployment Options Comparison

| Feature | Azure Tier 2 | vSphere Tier 2 | Hybrid |
|---------|--------------|----------------|--------|
| **VM Provisioning** | Marketplace (instant) | Template clone (minutes) | Both |
| **Container Registry** | Azure ACR ($5/mo) | Harbor (self-hosted) | ACR |
| **Licensing** | Pay-as-you-go or Hybrid | Use existing | Mixed |
| **Management** | Azure Portal | vCenter | Both |
| **Cost (4 months)** | $3,600-5,600 | $2,000-5,000 | Varies |
| **Best For** | Cloud-first orgs | On-prem/VMware shops | Large enterprises |

---

## 🎯 Implementation Status

### Completed ✅
- [x] Azure Tier 2 Terraform (uses marketplace VMs)
- [x] Azure Free Tier Terraform (uses marketplace VMs)
- [x] Rocky Linux migration (RHEL-compatible)
- [x] Key Vault integration (free tier)
- [x] Tier 2 optimizations (cost, performance, security)
- [x] Container architecture design

### In Progress 🔄
- [ ] Dockerfiles for migration tools
- [ ] Ansible playbooks (container-based)
- [ ] vSphere Terraform updates (container support)
- [ ] Container build pipeline (CI/CD)
- [ ] End-to-end testing

### Planned 📋
- [ ] Tier 3 architecture (Kubernetes-based)
- [ ] Monitoring dashboards (Grafana)
- [ ] Documentation portal (Docusaurus)
- [ ] Demo videos and tutorials

---

## 🚀 Quick Start

### Azure Deployment
```bash
# 1. Clone repository
git clone https://github.com/your-org/Auto-Domain-Migration.git
cd Auto-Domain-Migration

# 2. Configure Azure credentials
az login

# 3. Accept Rocky Linux marketplace terms (one-time)
az vm image terms accept \
  --publisher resf \
  --offer rockylinux-x86_64 \
  --plan 9-lvm-gen2

# 4. Deploy infrastructure
cd terraform/azure-tier2
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply

# 5. Run migration (coming soon)
# ansible-playbook playbooks/migrate_full.yml
```

### vSphere Deployment
```bash
# 1. Prepare Rocky Linux template (one-time)
# - Download Rocky Linux 9 ISO
# - Create VM and install
# - Install Docker: dnf install -y docker-ce
# - Convert to template

# 2. Deploy infrastructure
cd terraform/vsphere-tier2
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply

# 3. Run migration (coming soon)
# ansible-playbook playbooks/migrate_full.yml
```

---

## 📞 Support

- **Documentation:** `docs/` directory
- **Issues:** GitHub Issues
- **Email:** adrian207@gmail.com

---

**Status:** Architecture complete, ready for Ansible implementation  
**Next:** Build container images and Ansible playbooks 🚀

