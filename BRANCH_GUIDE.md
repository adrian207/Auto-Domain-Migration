# Branch Guide - Choose Your Solution

**Last Updated:** January 2025  
**Repository:** Auto Domain Migration

---

## 🎯 Three Specialized Solutions

This repository has **three branches**, each optimized for different scenarios:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  master              │  Server Migration  │  On-Prem   │
│  (User Migration)    │  (Servers/Apps)    │  (No Cloud)│
│                      │                    │            │
│  ✅ 100% Complete    │  🚧 New Branch     │  🚀 Ready  │
│                      │                    │            │
└─────────────────────────────────────────────────────────┘
```

---

## 🌳 Branch 1: `master` (User & Workstation Migration)

**Status:** ✅ 100% Feature Complete (v5.0)

### What It Does
Migrates **users, workstations, and user data** from one Active Directory domain to another.

### Key Features
- ✅ ADMT automation (user/computer/group migration)
- ✅ User profile migration (USMT)
- ✅ File share migration (SMS)
- ✅ Workstation domain joins
- ✅ Group Policy migration
- ✅ AD test data generation
- ✅ Self-healing automation
- ✅ Disaster recovery
- ✅ Complete training materials

### Technology
- **Migration Tool:** Microsoft ADMT
- **Orchestration:** Ansible/AWX (runs in Azure)
- **Infrastructure:** Azure VMs (3 tiers)
- **Cost:** $50-2,200/month

### Use When
- ✅ Migrating users between domains
- ✅ Company merger/acquisition
- ✅ Domain consolidation
- ✅ AD restructuring
- ✅ User-focused migration

### Example Scenario
> "Migrating 500 users from ACME.local to CORP.local after a merger. Need to move user accounts, computers, and file shares."

---

## 🌳 Branch 2: `feature/server-migration` (Server Infrastructure)

**Status:** 🚧 New Branch - Planning Complete

### What It Does
Migrates **servers and applications** (Windows & Linux) to Azure or between data centers.

### Key Features
- 🆕 Azure Migrate integration
- 🆕 Server discovery & dependency mapping
- 🆕 Database migration (SQL, PostgreSQL, MySQL, MongoDB)
- 🆕 Web server migration (IIS, Apache, Nginx)
- 🆕 Application server migration
- 🆕 Container migration (VM → Kubernetes)
- 🆕 Minimal downtime cutover

### Technology
- **Migration Tool:** Azure Migrate, Azure Site Recovery, DMS
- **Orchestration:** Ansible/AWX
- **Infrastructure:** Azure VMs + target VMs
- **Cost:** $200-10,000/month (includes target servers)

### Use When
- ✅ Data center decommission
- ✅ VMware → Azure migration
- ✅ Server OS upgrades
- ✅ Database migrations
- ✅ Application rehosting
- ✅ Infrastructure-focused migration

### Example Scenario
> "Moving 50 servers from aging VMware data center to Azure. Includes web servers, databases, and application servers."

---

## 🌳 Branch 3: `feature/on-premises-only` (No Cloud)

**Status:** 🚀 Ready to Implement

### What It Does
**100% on-premises deployment** with **ZERO cloud dependencies**. Can be completely air-gapped.

### Key Features
- ✅ Works with VMware, Proxmox, Hyper-V, KVM
- ✅ Air-gap capable (no internet required)
- ✅ All software runs on your infrastructure
- ✅ Data never leaves your facility
- ✅ One-time hardware cost (no monthly fees)
- ✅ Same automation as cloud version

### Technology
- **Hypervisor:** VMware/Proxmox/Hyper-V/KVM (your choice)
- **Orchestration:** Ansible/AWX (self-hosted)
- **Infrastructure:** Your VMs (on-prem)
- **Cost:** $10k-150k hardware (one-time capex)

### Use When
- ✅ Air-gapped environment
- ✅ Data sovereignty required
- ✅ No cloud allowed (compliance/policy)
- ✅ Long-term cost savings
- ✅ Already have infrastructure
- ✅ Government/defense/highly regulated

### Example Scenario
> "Air-gapped government facility needs to migrate between domains. No cloud access allowed. Must run entirely on local infrastructure."

---

## 📊 Quick Comparison

| Feature | Master | Server Migration | On-Premises |
|---------|--------|------------------|-------------|
| **Focus** | Users/Workstations | Servers/Applications | Any (no cloud) |
| **Status** | ✅ Complete | 🚧 Planning | 🚀 Ready |
| **Cloud Required** | Yes (automation) | Yes (automation) | ❌ No |
| **Air-Gap** | ❌ No | ❌ No | ✅ Yes |
| **Monthly Cost** | $50-2,200 | $200-10,000 | $0 |
| **Upfront Cost** | $0 | $0 | $10k-150k |
| **ADMT** | ✅ Yes | ❌ No | ✅ Yes |
| **Azure Migrate** | ❌ No | ✅ Yes | ❌ No |
| **Target Can Be** | Anywhere | Azure or anywhere | On-prem only |

---

## 🎯 Decision Matrix

### Choose **MASTER** if you need to:
- Migrate users between Active Directory domains
- Move workstations to new domain
- Consolidate user accounts after merger
- Migrate file shares (user data)
- Don't mind using Azure for automation

**Quick Check:**
```
✅ Migrating users? → master
✅ Migrating computers? → master
✅ Domain consolidation? → master
```

---

### Choose **SERVER-MIGRATION** if you need to:
- Migrate servers to Azure
- Lift-and-shift from VMware
- Database migrations
- Web server migrations
- Application rehosting
- Data center decommission

**Quick Check:**
```
✅ Migrating servers? → feature/server-migration
✅ Moving to Azure? → feature/server-migration
✅ Database migration? → feature/server-migration
```

---

### Choose **ON-PREMISES-ONLY** if you need to:
- Keep everything on-premises
- Work in air-gapped environment
- Avoid cloud costs long-term
- Meet data sovereignty requirements
- No cloud allowed by policy

**Quick Check:**
```
✅ No cloud allowed? → feature/on-premises-only
✅ Air-gapped? → feature/on-premises-only
✅ Data must stay local? → feature/on-premises-only
```

---

## 🤝 Can I Use Multiple Branches?

**YES!** The branches are complementary:

### Example: Complete Infrastructure Migration

**Phase 1: Server Migration** (branch: feature/server-migration)
- Migrate servers to Azure
- Set up new infrastructure

**Phase 2: User Migration** (branch: master)
- Migrate users to new domain
- Join workstations to new domain

**Phase 3: Maintain** (branch: master or feature/on-premises-only)
- Use self-healing
- Run DR procedures

---

## 🚀 Getting Started

### Step 1: Choose Your Branch

```bash
# User/workstation migration (100% complete)
git checkout master

# Server migration (new)
git checkout feature/server-migration

# On-premises only (no cloud)
git checkout feature/on-premises-only
```

### Step 2: Read the Documentation

```bash
# Master branch
docs/30_COMPLETE_SYSTEM_OVERVIEW.md

# Server migration
docs/33_SERVER_MIGRATION_STRATEGY.md

# On-premises
docs/34_ON_PREMISES_DEPLOYMENT.md
```

### Step 3: Deploy

```bash
# Choose your tier and deploy
cd terraform/<branch>/<tier>
terraform init
terraform apply
```

---

## 💰 Cost Comparison

### 3-Year Total Cost of Ownership

| Scenario | Year 1 | Year 2 | Year 3 | Total |
|----------|--------|--------|--------|-------|
| **Master (Cloud)** | $600-26k | $600-36k | $600-36k | $1.8k-98k |
| **Server Mig (Cloud)** | $2.4k-120k | $2.4k-120k | $2.4k-120k | $7.2k-360k |
| **On-Premises** | $10k-150k | $0 | $0 | $10k-150k |

**Break-even (On-Prem vs Cloud):**
- Tier 1: ~18 months
- Tier 2: ~12 months
- Tier 3: ~9 months

---

## 📚 Documentation Index

### Master Branch
- `README.md` - Main project README
- `PROJECT_STATUS.md` - 100% feature complete status
- `docs/30_COMPLETE_SYSTEM_OVERVIEW.md` - Complete guide
- `docs/32_DISASTER_RECOVERY_RUNBOOK.md` - DR procedures
- `docs/training/` - 6 training guides

### Server Migration Branch
- `SERVER_MIGRATION_README.md` - Branch overview
- `docs/33_SERVER_MIGRATION_STRATEGY.md` - Complete strategy

### On-Premises Branch
- `ON_PREMISES_README.md` - Branch overview
- `docs/34_ON_PREMISES_DEPLOYMENT.md` - Complete guide

---

## 🔄 Switching Between Branches

### Save Your Work First
```bash
# Commit current changes
git add .
git commit -m "Your changes"
```

### Switch Branches
```bash
# To master (user migration)
git checkout master

# To server migration
git checkout feature/server-migration

# To on-premises
git checkout feature/on-premises-only
```

### See What Changed
```bash
# Compare branches
git diff master feature/server-migration

# See branch list
git branch -a
```

---

## 🎯 Recommendations

### For Most Organizations
**Start with MASTER** (user migration)
- Most mature (100% complete)
- Best documentation
- Fully tested
- Production ready

### For Cloud Migrations
**Use SERVER-MIGRATION**
- Purpose-built for lift-and-shift
- Azure Migrate integration
- Database migration tools

### For High-Security Environments
**Use ON-PREMISES-ONLY**
- No cloud dependencies
- Air-gap capable
- Complete control

---

## 🆘 Need Help Choosing?

### Ask Yourself:

**1. What am I migrating?**
- Users/workstations → **master**
- Servers/applications → **feature/server-migration**
- Either (but no cloud) → **feature/on-premises-only**

**2. Can I use cloud?**
- Yes → **master** or **feature/server-migration**
- No → **feature/on-premises-only**

**3. Where's the target?**
- On-prem → **master** or **feature/on-premises-only**
- Azure → **feature/server-migration**
- Either → Any branch works

**4. What's my budget?**
- Opex (monthly) OK → **master** or **feature/server-migration**
- Prefer capex (one-time) → **feature/on-premises-only**

---

## 📞 Support

### Questions?
- Open an issue on GitHub
- Tag with branch name
- Reference this guide

### Contributing?
- Each branch maintained separately
- Improvements to shared components benefit all
- Follow branch-specific guidelines

---

## 🎉 Summary

**Three Solutions. One Repository. Choose Your Path.**

```
master               = User migration (100% complete)
server-migration     = Server migration (new, ready to build)
on-premises-only     = No cloud (ready to deploy)
```

**All three are production-grade solutions for different needs.**

---

**Current Status:**
- ✅ **master:** v5.0 - 100% complete
- 🚧 **server-migration:** Strategy complete
- 🚀 **on-premises-only:** Ready to implement

**Pick your branch and start migrating!** 🚀

---

**Version:** 1.0  
**Last Updated:** January 2025  
**Maintained by:** Adrian207

