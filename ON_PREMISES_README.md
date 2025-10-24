# On-Premises Only Deployment

**Branch:** `feature/on-premises-only`  
**Status:** 🚀 Ready to Implement

---

## 🎯 Zero Cloud Dependencies

This branch provides a **complete on-premises deployment** with **NO Azure, AWS, GCP, or any cloud provider**.

```
NO CLOUD │ 100% LOCAL │ AIR-GAP READY
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

## 💰 Cost Comparison

| Timeframe | On-Premises | Cloud (Azure) |
|-----------|-------------|---------------|
| **Year 1** | $10-50k (hardware) | $6-36k (monthly fees) |
| **Year 2** | $0 (owned) | $12-72k (total) |
| **Year 3** | $0 (owned) | $18-108k (total) |
| **Break-even** | 12-18 months | N/A |

**After break-even:** Pure savings, only power/cooling costs

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

### Tier 1 (10-50 servers)
```
2 servers (redundancy): 24 vCPU, 128 GB RAM each
Storage: 2 TB NVMe + 8 TB HDD per server
Migration Rate: ~5 servers per day
Cost: ~$15,000

Formula: 30 servers × 100 GB × 2 = 6 TB migration data
```

### Tier 2 (50-200 servers)
```
3-4 servers: 40 vCPU, 384 GB RAM each
Storage: 4 TB NVMe + 20 TB HDD per server
Migration Rate: ~15-20 servers per day
Cost: ~$65,000

Formula: 150 servers × 200 GB × 2 = 60 TB migration data
Recommended: Separate NAS/SAN for file server data
```

### Tier 3 (200-1,000 servers)
```
6-8 servers: 56 vCPU, 768 GB RAM each
Storage: 8 TB NVMe + 32 TB SSD per server
Plus: Dedicated 100-500 TB SAN/Ceph cluster
Migration Rate: ~50+ servers per day
Cost: ~$225,000

Formula: 500 servers × 300 GB × 2 = 300 TB migration data
Network: 40/100 Gbps backend recommended
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

### Healthcare
- HIPAA compliance
- PHI must stay on-site
- Data sovereignty

### Financial
- Regulatory requirements
- No external data storage
- Complete control

### Manufacturing
- OT/ICS environments
- No internet connectivity
- Industrial networks

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
- ✅ Same migration automation
- ✅ Same Ansible playbooks
- ✅ Same ADMT functions
- ✅ Same testing framework
- ✅ Same monitoring dashboards
- ✅ Same self-healing
- ✅ Same DR capabilities

**Only difference:** Where it runs (cloud vs on-prem)

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
- [ ] K3s deployment automation
- [ ] On-premises backup scripts

---

## 💡 When to Use This Branch

**Use On-Premises if:**
- ✅ Air-gapped environment required
- ✅ Data must stay on-site
- ✅ No cloud allowed (policy/compliance)
- ✅ Long-term cost savings important
- ✅ Already have hardware/virtualization
- ✅ Prefer capex over opex

**Use Cloud (main branch) if:**
- ✅ Fast deployment needed
- ✅ No hardware available
- ✅ Temporary project
- ✅ Prefer opex over capex
- ✅ Want managed services
- ✅ Global distribution needed

---

**Both are valid approaches!** Choose based on your requirements.

---

**Version:** 1.0  
**Last Updated:** January 2025  
**Branch:** feature/on-premises-only  
**Status:** Ready for implementation

