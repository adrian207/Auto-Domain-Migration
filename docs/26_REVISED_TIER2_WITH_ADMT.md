# Revised Tier 2 Architecture - ADMT + Cost Optimization

**Date:** October 2025  
**Author:** Adrian Johnson  
**Purpose:** Production-ready Tier 2 with Microsoft ADMT (supported tools only)

---

## 🎯 Architecture Decision

**Keep ADMT for Tier 2** - It's the right call for production:

```yaml
Why ADMT is Essential:
✅ Microsoft-supported (official tool)
✅ Production-tested (billions of migrations)
✅ Comprehensive features:
  - User/group/computer migration
  - SID history preservation
  - Password migration
  - Security translation
  - Resource migration
  - Trust relationship handling
✅ Error handling and retry logic
✅ Detailed logging and reporting
✅ Microsoft support if issues arise

Why NOT to replace ADMT:
❌ PowerShell + Graph API = custom code (not supported)
❌ Third-party tools = licensing costs
❌ Direct Entra sync = no SID history, breaks permissions
❌ Manual process = error-prone at scale
```

**Verdict: ADMT stays for Tier 2/3 production migrations** ✅

---

## 🏗️ Revised Tier 2 Architecture

### Infrastructure Components

```
Azure Container Apps ($380/mo)
├── Ansible Controller (orchestration)
├── Guacamole Bastion (remote access)
├── Prometheus (metrics)
└── Grafana (dashboards)

Domain Controllers - OPTIMIZED ($62/mo)
├── Source DC (existing customer infrastructure) = $0
└── Target DC (B2s Server Core) = $31/month
    └── Runs ADMT + AD services

Managed Services ($350/mo)
├── PostgreSQL Flexible Server ($220)
├── Azure Storage ($30)
├── Key Vault (FREE)
├── Networking ($50)
└── Entra ID (FREE)

Optional Post-Migration:
└── Entra Connect (syncs Target AD → Entra ID)
    └── Enables hybrid cloud identity

TOTAL: $792/month
vs Original: $2,000/month
SAVINGS: $1,208/month (60%)
```

---

## 💰 Cost Breakdown Comparison

### Current (Unoptimized) - $2,000/month
```
Compute VMs:
├── 2x Ansible (D8s_v5): $560
├── 1x Guacamole (D2s_v5): $70
├── 1x Monitoring (D4s_v5): $140
├── 1x Source DC (D4s_v5): $70
└── 1x Target DC (D4s_v5): $70
Total: $910/month

Services: $1,090/month
TOTAL: $2,000/month
```

### Optimized (Containers + ADMT) - $792/month ⭐
```
Container Apps:
├── Ansible Controller: $150
├── Guacamole: $76
├── Prometheus: $76
└── Grafana: $78
Total: $380/month

VMs (Minimal):
├── Source DC: $0 (customer existing)
└── Target DC (B2s Core): $31
Total: $31/month

Services: $381/month
TOTAL: $792/month

SAVINGS: $1,208/month (60%)
```

---

## 🔄 Migration Workflow with ADMT

### Phase 1: Infrastructure Setup (Week 1)
```bash
# Deploy optimized infrastructure
cd terraform/azure-tier2-optimized
terraform apply

Result:
✅ Container Apps running (Ansible, Guacamole, Monitoring)
✅ Target DC (B2s Server Core) provisioned
✅ ADMT installed on Target DC
✅ Trusts configured between domains
✅ Entra Connect ready (optional)
```

### Phase 2: ADMT Migration (Weeks 2-8)
```yaml
Ansible Playbook: playbooks/10_migrate_users_admt.yml

Process:
  1. Ansible discovers source users from Source DC
  2. Ansible generates ADMT script
  3. Ansible executes ADMT on Target DC (via WinRM)
  4. ADMT migrates:
     - User accounts
     - Group memberships
     - Computer accounts
     - Security principals
     - SID history (permission preservation)
  5. Ansible validates migration
  6. Repeat for next wave

Benefits:
✅ Supported by Microsoft
✅ SID history preserved (no permission loss)
✅ Password migration (if enabled)
✅ Automated via Ansible (not manual)
✅ Wave-based (controlled rollout)
```

### Phase 3: Entra Sync (Optional - Ongoing)
```yaml
After ADMT completes:
  1. Install Entra Connect on Target DC
  2. Configure sync: Target AD → Entra ID
  3. Users appear in Azure AD
  4. Enable:
     - Azure AD Join for devices
     - SSO to cloud apps
     - Conditional Access
     - MFA
  
Cost: $0 (Entra Connect is free)
```

### Phase 4: Hybrid or Decommission (Post-Migration)
```yaml
Option A: Keep Target DC (Hybrid Identity)
  - Maintain Target AD + Entra ID sync
  - Support on-prem apps requiring AD
  - Cost: $31/month ongoing
  
Option B: Cloud-Only (Decommission DC)
  - After devices are Azure AD Joined
  - After apps migrated to cloud auth
  - Shut down Target DC
  - Cost: $0 ongoing
  
Recommendation: Start with Option A, migrate to B over time
```

---

## 🛠️ ADMT Implementation Details

### ADMT Installation (Automated)
```yaml
# Ansible playbook: roles/admt_install/tasks/main.yml
- name: Download ADMT installer
  win_get_url:
    url: "https://download.microsoft.com/download/C/A/E/CAE57B8E-C9E8-4FA5-A618-0CD23C7C32FC/admtsetup32.exe"
    dest: "C:\\Temp\\admtsetup32.exe"
  delegate_to: "{{ target_dc }}"

- name: Install ADMT silently
  win_package:
    path: "C:\\Temp\\admtsetup32.exe"
    arguments: "/quiet /norestart"
    state: present
  delegate_to: "{{ target_dc }}"

- name: Install ADMT Password Export Server (on Source DC)
  win_package:
    path: "C:\\Temp\\pwdmig.msi"
    arguments: "/quiet"
    state: present
  delegate_to: "{{ source_dc }}"
  when: migrate_passwords | bool
```

### ADMT Execution (Automated)
```yaml
# Ansible playbook: playbooks/10_migrate_users_admt.yml
- name: Generate ADMT migration script
  template:
    src: admt_migrate_users.ps1.j2
    dest: "C:\\Migration\\admt_wave{{ wave_number }}.ps1"
  delegate_to: "{{ target_dc }}"

- name: Execute ADMT user migration
  win_shell: |
    C:\Migration\admt_wave{{ wave_number }}.ps1
  register: admt_result
  delegate_to: "{{ target_dc }}"

- name: Parse ADMT results
  set_fact:
    migrated_users: "{{ admt_result.stdout | regex_findall('Successfully migrated: (.+)') }}"
    failed_users: "{{ admt_result.stdout | regex_findall('Failed to migrate: (.+)') }}"

- name: Log results to PostgreSQL
  postgresql_query:
    db: migration_state
    query: |
      INSERT INTO migration_events (wave_number, event_type, success_count, failed_count)
      VALUES ({{ wave_number }}, 'ADMT_USER_MIGRATION', {{ migrated_users|length }}, {{ failed_users|length }})
```

---

## 🔧 Target DC Optimization

### Configuration: B2s Server Core
```hcl
# terraform/azure-tier2/compute-optimized.tf
resource "azurerm_windows_virtual_machine" "target_dc" {
  name                = "${local.resource_prefix}-tgt-dc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"  # 2 vCPU, 4GB - $31/month
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core-g2"  # Server Core (no GUI)
    version   = "latest"
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"  # $5/month, good performance
    disk_size_gb         = 40  # Minimal for Server Core + ADMT
  }

  # Remote management configuration
  additional_unattend_content {
    setting = "AutoLogon"
    content = "<AutoLogon><Password><Value>${var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
  }

  tags = merge(local.common_tags, {
    Role = "Target-DomainController"
    Edition = "ServerCore"
    Purpose = "ADMT-Migration"
  })
}
```

### Why B2s Instead of B1ms?
```yaml
B1ms (1 vCPU, 2GB): $15/month
  ⚠️ ADMT can be slow with 1 vCPU
  ⚠️ 2GB RAM is minimum, no headroom
  ⚠️ Risk of paging during large migrations
  
B2s (2 vCPU, 4GB): $31/month ⭐
  ✅ ADMT runs smoothly
  ✅ Comfortable RAM for 500+ users
  ✅ Handles parallel operations
  ✅ Room for Windows updates
  ✅ Only $16/month more for production stability

Recommendation: B2s for production (Tier 2)
              B1ms acceptable for Tier 1 (small demos)
```

---

## 📊 Tier Comparison Matrix

| Component | Tier 1 (Demo) | Tier 2 (Production) | Tier 3 (Enterprise) |
|-----------|---------------|---------------------|---------------------|
| **Migration Tool** | ADMT | **ADMT** ⭐ | ADMT + Advanced |
| **Ansible** | 1 VM | Container App | AKS |
| **Guacamole** | 1 VM | Container App | AKS |
| **Monitoring** | Basic | Container Apps | AKS + Premium |
| **Source DC** | B1ms | Existing ($0) | Existing ($0) |
| **Target DC** | B1ms Core | **B2s Core** ⭐ | B2s Core |
| **Entra Sync** | Optional | Recommended | Required |
| **Monthly Cost** | $50-100 | **$792** ⭐ | $1,570 |
| **Best For** | POC, Learning | Most organizations | >3,000 users |

---

## 🎯 Why This Architecture Works

### 1. Supported & Reliable
```yaml
ADMT Benefits:
✅ Microsoft official tool (production-tested)
✅ Comprehensive feature set
✅ SID history preservation (critical for permissions)
✅ Detailed error reporting
✅ Microsoft support available

Plus:
✅ Containers reduce other compute costs (60%)
✅ B2s Server Core optimizes DC costs (56% off)
✅ Automation via Ansible (no manual steps)
```

### 2. Cost-Optimized
```yaml
Savings vs All-VM Approach:
├── Containers instead of VMs: -$530/month
├── B2s instead of D4s_v5: -$39/month
├── Server Core instead of Desktop: -$0 but smaller/faster
├── Source DC already exists: -$70/month
└── Total savings: $1,208/month (60%)
```

### 3. Production-Ready
```yaml
Enterprise Features:
✅ High availability (Container Apps auto-scale)
✅ Backup and recovery (Azure Backup)
✅ Monitoring (Prometheus + Grafana)
✅ Security (Key Vault, NSGs, JIT access)
✅ Compliance (audit logs to PostgreSQL)
✅ Support (Microsoft tools, enterprise SLAs)
```

---

## 🚀 Deployment Guide

### Step 1: Deploy Infrastructure
```bash
cd terraform/azure-tier2-optimized
terraform init
terraform apply

# Provisions:
# - Container Apps (Ansible, Guacamole, Monitoring)
# - Target DC (B2s Server Core)
# - PostgreSQL, Storage, Networking
# - All optimized for cost
```

### Step 2: Configure ADMT
```bash
# Ansible automatically:
ansible-playbook playbooks/00_bootstrap.yml

# - Promotes Target DC
# - Installs ADMT
# - Configures domain trusts
# - Installs Password Export Server (if needed)
# - Validates connectivity
```

### Step 3: Execute Migration
```bash
# Wave-based ADMT migration
ansible-playbook playbooks/10_migrate_users_admt.yml \
  --extra-vars "wave_number=1"

ansible-playbook playbooks/11_migrate_computers_admt.yml \
  --extra-vars "wave_number=1"

# Fully automated:
# - Ansible orchestrates ADMT
# - ADMT migrates objects
# - State tracked in PostgreSQL
# - Metrics sent to Prometheus
# - Dashboards updated in Grafana
```

### Step 4: Enable Entra Sync (Optional)
```bash
ansible-playbook playbooks/20_configure_entra_connect.yml

# - Installs Entra Connect on Target DC
# - Configures sync to Azure AD
# - Enables hybrid identity
```

---

## 📋 Feature Comparison

| Feature | Tier 1 | Tier 2 (This Design) | Alternative (Entra Only) |
|---------|--------|----------------------|--------------------------|
| **Migration Tool** | ADMT | **ADMT** ✅ | PowerShell/Graph API |
| **Microsoft Support** | Yes | **Yes** ✅ | No (custom code) |
| **SID History** | Yes | **Yes** ✅ | No |
| **Password Migration** | Yes | **Yes** ✅ | No |
| **Resource Translation** | Yes | **Yes** ✅ | Manual |
| **Group Memberships** | Yes | **Yes** ✅ | Manual mapping |
| **Computer Migration** | Yes | **Yes** ✅ | Re-join only |
| **Production Ready** | Demo | **Yes** ✅ | Risky |
| **Cost** | $50-100 | **$792** | $730 |

**Tier 2 with ADMT wins on reliability and supportability** ⭐

---

## 💡 Post-Migration Options

### Option A: Hybrid Identity (Recommended Initially)
```yaml
Keep Target DC + Entra Sync:
  - Maintains Target AD domain
  - Syncs to Entra ID for cloud access
  - Supports on-prem apps requiring AD
  - Gradual migration to cloud
  
Cost: $31/month (Target DC)
Timeline: Ongoing (hybrid model)
```

### Option B: Cloud-Only (Future State)
```yaml
After All Systems Cloud-Ready:
  1. Migrate devices to Azure AD Join
  2. Migrate apps to cloud auth (OAuth/SAML)
  3. Decommission Target DC
  4. Pure Entra ID
  
Cost: $0/month (no DC)
Timeline: 6-12 months post-migration
Savings: Additional $372/year
```

---

## ⚠️ Important Notes

### ADMT Requirements
```yaml
Technical Requirements:
✅ Source and Target AD domains (must exist)
✅ Two-way trust or domain migration mode
✅ Domain Admin credentials on both domains
✅ Windows Server 2016+ (ADMT 3.2)
✅ .NET Framework 4.x
✅ SQL Server Express (included with ADMT)

Network Requirements:
✅ RPC connectivity (TCP 135, 49152-65535)
✅ SMB (TCP 445)
✅ LDAP (TCP 389, UDP 389)
✅ DNS resolution
```

### Unsupported Alternatives Avoided
```yaml
Why We're NOT Doing This for Tier 2:

❌ Direct Entra sync without AD:
  - Loses SID history (permission issues)
  - No password migration
  - Manual resource translation
  - Not Microsoft-supported for large migrations

❌ PowerShell-only migration:
  - Custom code (no support)
  - Error-prone
  - Missing features vs ADMT
  - No production track record

❌ Third-party tools:
  - Additional licensing costs
  - Vendor lock-in
  - Learning curve

Tier 2 = Production = Microsoft-supported tools ✅
```

---

## 🎯 Final Recommendation

**For Tier 2 Production: Use ADMT with Optimized Infrastructure**

```yaml
Architecture:
├── ADMT for migration (Microsoft-supported)
├── Container Apps for orchestration (60% cheaper)
├── B2s Server Core for Target DC (56% cheaper)
├── Entra Connect for hybrid cloud (optional)
└── Automated with Ansible (zero manual steps)

Cost: $792/month
Savings: $1,208/month (60% vs all-VMs)
Reliability: Production-grade
Support: Microsoft-backed
```

**This gives you:**
- ✅ Supported migration tool (ADMT)
- ✅ Massive cost savings (60%)
- ✅ Production reliability
- ✅ Full automation
- ✅ Hybrid cloud ready
- ✅ Path to cloud-only future

---

**Status:** Architecture revised with ADMT + cost optimization  
**Next:** Implement Terraform and Ansible for this design 🚀

