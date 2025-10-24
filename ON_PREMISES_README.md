# On-Premises Only Deployment

**Branch:** `feature/on-premises-only`  
**Status:** 🚀 Ready to Implement

---

## 🎯 Zero Cloud Dependencies

This branch provides a **complete on-premises deployment** with **NO Azure, AWS, GCP, or any cloud provider**.

**Designed for:** Windows & Linux server migrations (not workstation/user migrations)

```
NO CLOUD │ 100% LOCAL │ AIR-GAP READY │ SERVER-FOCUSED
```

---

## 📖 Documentation

**Complete Guide:** [`docs/34_ON_PREMISES_DEPLOYMENT.md`](docs/34_ON_PREMISES_DEPLOYMENT.md)

---

## 🏗️ What You Can Use

### Hypervisors (Choose One)
- ✅ **VMware vSphere/ESXi** - Commercial (free version available)
- ✅ **Proxmox VE** - Open source (completely free)
- ✅ **Microsoft Hyper-V** - Included with Windows Server
- ✅ **KVM/QEMU** - Open source (completely free)
- ✅ **Bare Metal** - No virtualization

### Software (All Free/Open Source)
- ✅ **Ansible/AWX** - Automation
- ✅ **Terraform** - Infrastructure provisioning
- ✅ **Prometheus/Grafana** - Monitoring
- ✅ **HashiCorp Vault** - Secrets management
- ✅ **PostgreSQL** - Database
- ✅ **K3s** - Lightweight Kubernetes (Tier 3)
- ✅ **MinIO** - S3-compatible storage

---

## 💰 Cost Comparison (Server Migration Workload)

| Timeframe | On-Premises | Cloud (Azure) |
|-----------|-------------|---------------|
| **Year 1** | $3-30k (hardware) | $9.6-60k (monthly fees) |
| **Year 2** | $4.2-36k (power only) | $19.2-120k (total) |
| **Year 3** | $6.6-42k (total) | $28.8-180k (total) |
| **Year 5** | $9-48k (total) | $48-300k (total) |
| **Break-even** | 1-12 months | N/A |

**After break-even:** Pure savings, only power/cooling (~$50-200/month)

**Key Advantages:**
- Lower upfront investment (can reuse existing hardware)
- No cloud bandwidth costs for large file server migrations
- Break-even much faster with reduced hardware requirements

---

## 🔐 Key Benefits

### ✅ Air-Gap Capable
- No internet required
- Complete isolation
- Zero external attack surface

### ✅ Data Sovereignty
- Data never leaves your facility
- Full compliance control
- No third-party access

### ✅ Cost Predictable
- One-time hardware purchase
- No monthly subscription
- No surprise charges

### ✅ Full Control
- You own the hardware
- No vendor lock-in
- Switch platforms anytime

---

## 📊 Hardware Requirements (Server Migration Sizing)

### Tier 1 (10-50 servers) - Minimal Setup
```
Single Server: 8 vCPU, 32 GB RAM
Storage: 500 GB SSD + existing NAS/file server storage
Migration Rate: ~5 servers per day
Cost: ~$3,000 (or use existing hardware)

VMs on single host:
- 1x Automation (AWX + Ansible):  4 vCPU, 16 GB RAM
- 1x Monitoring (Prom + Grafana): 2 vCPU, 8 GB RAM  
- 1x PostgreSQL:                  2 vCPU, 8 GB RAM

Note: Use existing file servers for source/target storage
```

### Tier 2 (50-200 servers) - Production Setup
```
2 servers: 16 vCPU, 64 GB RAM each (for HA)
Storage: 1 TB SSD per server + existing storage infrastructure
Migration Rate: ~15-20 servers per day
Cost: ~$10,000-15,000

VMs distributed across hosts:
- 2x Automation (HA):             4 vCPU, 16 GB RAM each
- 2x PostgreSQL (HA):             4 vCPU, 12 GB RAM each
- 2x Monitoring (HA):             2 vCPU, 8 GB RAM each
- 1x Vault:                       2 vCPU, 4 GB RAM

Note: Leverage existing file servers, NAS, or SAN for migration storage
```

### Tier 3 (200-1,000 servers) - Enterprise Setup
```
3-4 servers: 16 vCPU, 32 GB RAM each
Storage: 1 TB SSD per server + existing enterprise storage
Migration Rate: ~50+ servers per day
Cost: ~$20,000-30,000

Options:
A) VM-based (simpler):
   - 3x Automation cluster:       4 vCPU, 12 GB RAM each
   - 3x PostgreSQL HA:            4 vCPU, 8 GB RAM each
   - 3x Monitoring HA:            2 vCPU, 4 GB RAM each
   - 1x Vault:                    2 vCPU, 4 GB RAM
   
B) Kubernetes-based (advanced):
   - 3x K3s nodes:                16 vCPU, 32 GB RAM each
   - Run all services as lightweight containers
   - Better resource utilization

Note: Use existing SAN/NAS for file server migration data
Bandwidth: 10 Gbps network recommended (1 Gbps minimum)
```

---

## 🚀 Quick Start

### 1. Switch to Branch
```bash
git checkout feature/on-premises-only
```

### 2. Choose Hypervisor
```bash
# Example: Proxmox (free)
cd terraform/on-premises/proxmox-tier1
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

## 🎯 Use Cases

### Government/Defense
- Air-gapped networks
- Classified data
- No cloud allowed
- **Server consolidation** across agencies

### Healthcare
- HIPAA compliance
- PHI must stay on-site
- Data sovereignty
- **Medical records server** migration

### Financial
- Regulatory requirements
- No external data storage
- Complete control
- **Trading/database server** migrations

### Manufacturing
- OT/ICS environments
- No internet connectivity
- Industrial networks
- **SCADA/MES server** migrations

### Datacenter Consolidation
- **Multi-site server** migrations
- **Merger/acquisition** server consolidation
- Legacy server decommissioning
- Physical to virtual (P2V) migrations

---

## 🤝 Comparison with Main Branch

| Aspect | Main Branch (Cloud) | This Branch (On-Prem) |
|--------|---------------------|----------------------|
| **Orchestration** | Azure VMs | Your VMs |
| **Kubernetes** | Azure AKS | K3s/RKE2 |
| **Database** | Azure PostgreSQL | Self-hosted PostgreSQL |
| **Storage** | Azure Storage | NFS/MinIO/Local |
| **Monitoring** | Azure Monitor | Prometheus/Grafana |
| **Cost Model** | Monthly subscription | One-time capex |
| **Internet** | Required | Optional |
| **Air-gap** | Not possible | Fully supported |

---

## ✅ What's the Same?

Both branches provide:
- ✅ Same migration automation (Ansible/AWX)
- ✅ Same server migration playbooks
- ✅ Same file server migration (SMS)
- ✅ Same testing framework (150+ tests)
- ✅ Same monitoring dashboards (Prometheus/Grafana)
- ✅ Same self-healing automation
- ✅ Same DR capabilities (backup/snapshot)
- ✅ Same database migrations (PostgreSQL, SQL Server, MySQL)

**Key difference:** Where it runs (cloud vs on-prem)  
**Migration focus:** Servers, databases, and file shares (not end-user workstations)

---

## 📝 Status

### ✅ Completed
- [x] Complete deployment guide
- [x] Architecture documentation
- [x] Hardware sizing
- [x] Cost comparison

### 🚧 To Do
- [ ] Terraform configs for VMware
- [ ] Terraform configs for Proxmox
- [ ] Terraform configs for Hyper-V
- [ ] Terraform configs for KVM
- [ ] K3s deployment automation (Tier 3)
- [ ] On-premises backup scripts (ZFS/Veeam/Bacula)
- [ ] Storage sizing calculator (server-based)
- [ ] Network design templates
- [ ] Migration wave planning tools

---

## 💡 When to Use This Branch

**Use On-Premises if:**
- ✅ Air-gapped environment required
- ✅ Data must stay on-site
- ✅ No cloud allowed (policy/compliance)
- ✅ Long-term cost savings important (8-18 month ROI)
- ✅ Already have hardware/virtualization
- ✅ Large file server migrations (bandwidth cost avoidance)
- ✅ Migrating 50+ servers (better economics at scale)
- ✅ Prefer capex over opex

**Use Cloud (main branch) if:**
- ✅ Fast deployment needed (minutes vs days)
- ✅ No hardware available
- ✅ Temporary project (<12 months)
- ✅ Small server count (<50 servers)
- ✅ Prefer opex over capex
- ✅ Want managed services
- ✅ Global distribution needed

---

**Both are valid approaches!** Choose based on your requirements.

**Break-Even Analysis:**
- **Tier 1 (10-50 servers):** 1-3 months (immediate if reusing hardware)
- **Tier 2 (50-200 servers):** 3-6 months
- **Tier 3 (200-1,000 servers):** 6-12 months

**Pro Tip:** Most organizations have spare capacity on existing servers that can run the automation infrastructure at zero additional hardware cost!

---

**Version:** 1.0  
**Last Updated:** January 2025  
**Branch:** feature/on-premises-only  
**Status:** Ready for implementation

