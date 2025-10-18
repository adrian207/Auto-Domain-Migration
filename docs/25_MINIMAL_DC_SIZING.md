# Minimal Domain Controller Sizing Strategy

**Date:** October 2025  
**Author:** Adrian Johnson  
**Purpose:** Minimize DC costs - they're just endpoints, not workhorses

---

## 🎯 Key Insight

**Domain Controllers in migration are NOT doing the heavy work:**
```
What DCs DON'T do:
❌ Run ADMT (runs on Ansible controller)
❌ Process USMT (runs on workstations)
❌ Execute playbooks (Ansible does this)
❌ Move data (handled by migration tools)

What DCs DO:
✅ Accept LDAP queries (lightweight)
✅ Create user/computer accounts (minimal CPU)
✅ Authenticate Kerberos tickets (fast)
✅ Store AD database (small for migration)
✅ Replicate changes (only during migration)
```

**Therefore: We can use TINY VMs!**

---

## 💰 Azure VM Sizing Options

### Option 1: B1s (FREE Tier - Too Small) ❌
```yaml
Size: Standard_B1s
vCPU: 1
RAM: 1GB
Cost: FREE (750 hours/month) or $4.75/month

Why it fails:
❌ Windows Server DC requires 2GB RAM minimum
❌ Promotion wizard fails with 1GB
❌ Paging/swapping kills performance
❌ Can't install updates

Verdict: Don't use for DC
```

---

### Option 2: B1ms (Minimal - Works!) ✅
```yaml
Size: Standard_B1ms
vCPU: 1
RAM: 2GB
Disk: 30GB (Server Core)
Cost: $15.33/month (Pay-as-you-go, East US)

Why it works:
✅ Meets 2GB RAM minimum
✅ Handles DC promotion
✅ Supports Server Core
✅ Enough for <500 user migrations
✅ Burstable CPU (handles spikes)

Limitations:
⚠️ Slow for >500 users
⚠️ Can't run ADMT locally (use remote)
⚠️ Limited to 2 data disks

Verdict: BEST for Tier 1 (small migrations)
Cost: $15/month per DC
```

---

### Option 3: B2s (Recommended for Production) ⭐
```yaml
Size: Standard_B2s
vCPU: 2
RAM: 4GB
Disk: 30GB (Server Core)
Cost: $30.66/month (Pay-as-you-go, East US)

Why it's better:
✅ Comfortable RAM headroom
✅ Faster AD queries
✅ Supports >500 users
✅ Room for Windows updates
✅ Can run ADMT locally if needed

Verdict: RECOMMENDED for Tier 2
Cost: $31/month per DC
```

---

### Option 4: B1ms (Auto-Shutdown) - CHEAPEST! 🎉
```yaml
Size: Standard_B1ms
vCPU: 1
RAM: 2GB
Auto-shutdown: 6 PM to 6 AM weekdays, all weekend
Running time: ~40 hours/week = 160 hours/month

Cost calculation:
  - Normal: $15.33/month (730 hours)
  - Actual: $15.33 × (160/730) = $3.36/month!

Savings: $11.97/month (78% off!)

Best for: Tier 1 demo/POC where migration only happens during work hours
```

---

## 🖥️ Windows Server Licensing

### Option 1: Server Core (NO GUI) ⭐ RECOMMENDED
```yaml
What is Server Core:
  - Command-line only (PowerShell/CMD)
  - No Desktop Experience
  - No Start Menu, no GUI tools
  
Benefits:
  ✅ Smaller footprint: 30GB vs 60GB
  ✅ Less RAM usage: 1.5GB vs 2.5GB
  ✅ Fewer updates: 50% reduction
  ✅ Better security: Smaller attack surface
  ✅ Faster boot: 50% quicker

Management:
  ✅ Remote Server Administration Tools (RSAT)
  ✅ Windows Admin Center (web-based)
  ✅ PowerShell remoting
  ✅ Group Policy management (from another machine)

Licensing:
  ✅ Same as Desktop Experience
  ✅ No additional cost

Perfect for: Migration DCs (no one logs into them)
```

**How to deploy Server Core in Azure:**
```hcl
# terraform/azure-tier2/compute.tf
resource "azurerm_windows_virtual_machine" "source_dc" {
  name                = "${local.resource_prefix}-src-dc"
  size                = "Standard_B1ms"  # Smallest viable
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core-g2"  # Server Core
    version   = "latest"
  }
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"  # Cheapest
    disk_size_gb         = 30  # Minimal
  }
}
```

---

### Option 2: Desktop Experience (Full GUI) - Larger
```yaml
What is Desktop Experience:
  - Full Windows GUI
  - Server Manager
  - All graphical tools
  
Downsides:
  ❌ 60GB+ disk required
  ❌ 2.5GB+ RAM usage
  ❌ More updates = more maintenance
  ❌ Larger attack surface
  
When to use:
  ⚠️ Learning/training environments
  ⚠️ Admins unfamiliar with PowerShell
  ⚠️ Need GUI troubleshooting tools

Cost impact:
  - Must use B2s (4GB RAM) minimum
  - $31/month vs $15/month for Core
```

---

## 🔧 Remote Management Setup

### Enable Remote Management (PowerShell)
```powershell
# Run on Server Core DC (via cloud-init or VM extension)

# Enable WinRM (Windows Remote Management)
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

# Configure firewall for remote management
Set-NetFirewallRule -Name "WINRM-HTTP-In-TCP" -Enabled True
New-NetFirewallRule -Name "WINRM-HTTPS-In-TCP" -DisplayName "WinRM HTTPS" `
    -Enabled True -Direction Inbound -Protocol TCP -LocalPort 5986

# Enable Remote Server Administration
Install-WindowsFeature RSAT-AD-PowerShell, RSAT-AD-Tools

# Allow RDP (for emergency access)
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Install AD DS role
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
```

---

### Remote Management from Ansible Controller
```yaml
# Ansible inventory
[domain_controllers]
source-dc ansible_host=10.0.10.10 ansible_user=administrator ansible_password={{ vault_admin_password }} ansible_connection=winrm ansible_winrm_transport=ntlm ansible_winrm_server_cert_validation=ignore

[target_dc]
target-dc ansible_host=10.0.20.10 ansible_user=administrator ansible_password={{ vault_admin_password }} ansible_connection=winrm ansible_winrm_transport=ntlm ansible_winrm_server_cert_validation=ignore
```

```yaml
# Create user on DC remotely
- name: Create user in target AD
  microsoft.ad.user:
    name: John Doe
    sam_account_name: jdoe
    upn: jdoe@target.local
    password: "{{ temp_password }}"
    state: present
  delegate_to: target-dc  # Remote execution
```

---

## 💰 Cost Comparison

### Scenario 1: Tier 1 (POC/Demo - 50 users, 1 month)
```yaml
Option A: Traditional Sizing
  - 2x Standard_D2s_v5 (2 vCPU, 8GB)
  - Cost: $70 × 2 = $140/month
  - Total: $140

Option B: Minimal Sizing (Server Core)
  - 2x Standard_B1ms (1 vCPU, 2GB)
  - Cost: $15 × 2 = $30/month
  - Total: $30

Option C: Minimal + Auto-Shutdown
  - 2x Standard_B1ms (160 hrs/month)
  - Cost: $3.36 × 2 = $6.72/month
  - Total: $7

Savings: $133/month (95% off!) ✅
```

---

### Scenario 2: Tier 2 (Production - 500 users, 4 months)
```yaml
Option A: Current (Standard_D2s_v5)
  - 2x DCs, $70 each
  - 4 months = $70 × 2 × 4 = $560

Option B: Server Core (Standard_B2s)
  - 2x DCs, $31 each
  - 4 months = $31 × 2 × 4 = $248
  
Option C: Entra ID (eliminate target DC)
  - 1x Source DC (existing, $0)
  - 0x Target DC (using Entra)
  - 4 months = $0

Savings Option B: $312 (56% off)
Savings Option C: $560 (100% off!) ⭐
```

---

### Scenario 3: Tier 2 Hybrid (Production with minimal DCs)
```yaml
Reality Check:
  - Source DC: Already exists = $0
  - Target DC: B1ms Server Core = $15/month
  - Only run during migration (4 months)
  - Total: $15 × 4 = $60

Compare to:
  - Current approach: $280 (2x D2s_v5 for 4 months)
  - Savings: $220 (79% off!)
```

---

## 🎯 Recommended Configurations

### Tier 1 (Free/Demo): Ultra-Minimal
```hcl
# terraform/azure-free-tier/compute.tf
resource "azurerm_windows_virtual_machine" "source_dc" {
  name     = "${local.resource_prefix}-src-dc"
  size     = "Standard_B1ms"  # $15/month
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core-g2"  # Server Core
    version   = "latest"
  }
  
  os_disk {
    storage_account_type = "Standard_LRS"  # Cheapest
    disk_size_gb         = 30  # Minimal for Server Core
  }
}

# Auto-shutdown schedule
resource "azurerm_dev_test_global_vm_shutdown_schedule" "dc" {
  virtual_machine_id = azurerm_windows_virtual_machine.source_dc.id
  location           = azurerm_resource_group.main.location
  enabled            = true

  daily_recurrence_time = "1800"  # 6 PM
  timezone              = "Pacific Standard Time"

  notification_settings {
    enabled = false
  }
}

# Cost: $3-7/month with auto-shutdown
```

---

### Tier 2 (Production): Optimized
```hcl
# terraform/azure-tier2/compute.tf
resource "azurerm_windows_virtual_machine" "source_dc" {
  name     = "${local.resource_prefix}-src-dc"
  size     = "Standard_B2s"  # $31/month, better performance
  
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-core-g2"  # Server Core
    version   = "latest"
  }
  
  os_disk {
    storage_account_type = "StandardSSD_LRS"  # Better perf, $5/month
    disk_size_gb         = 40  # Room for logs
  }
  
  # No auto-shutdown (production needs 24/7)
}

# Cost: $31/month (vs $70 with D2s_v5)
# Savings: $39/month per DC
```

---

### Tier 3 (Enterprise): Use Entra ID
```yaml
# No target DC needed!
# Only source DC (customer already has)
# Cost: $0
```

---

## 📊 Final Cost Matrix

| Tier | DC Strategy | VM Size | Server Edition | Monthly Cost | Annual Cost |
|------|-------------|---------|----------------|--------------|-------------|
| **Tier 1 (Demo)** | 2 DCs, auto-shutdown | B1ms | Server Core | **$7** ⭐ | $84 |
| **Tier 2 (Minimal)** | 1 DC (source existing) | B2s | Server Core | **$31** | $372 |
| **Tier 2 (Entra)** | 0 new DCs (Entra ID) | N/A | N/A | **$0** ⭐⭐⭐ | $0 |
| **Tier 3 (Enterprise)** | 0 new DCs (Entra ID) | N/A | N/A | **$0** ⭐⭐⭐ | $0 |
| **Current (Unoptimized)** | 2 DCs | D2s_v5 | Desktop | $140 | $1,680 |

**Maximum Savings: $140/month → $0/month = 100% reduction!**

---

## 🚀 Implementation Guide

### Step 1: Create Server Core DC
```powershell
# Cloud-init for Server Core DC
#cloud-config
runcmd:
  # Enable remote management
  - powershell.exe -Command "Enable-PSRemoting -Force"
  
  # Configure WinRM
  - powershell.exe -Command "Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force"
  
  # Install AD DS
  - powershell.exe -Command "Install-WindowsFeature AD-Domain-Services -IncludeManagementTools"
  
  # Configure firewall
  - powershell.exe -Command "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'"
  - powershell.exe -Command "Enable-NetFirewallRule -DisplayGroup 'Windows Remote Management'"
  
  # Promote to DC (example)
  - powershell.exe -Command "Install-ADDSForest -DomainName 'target.local' -SafeModeAdministratorPassword (ConvertTo-SecureString 'P@ssw0rd!' -AsPlainText -Force) -Force"
```

### Step 2: Manage Remotely
```powershell
# From Windows Admin Center or RSAT
$cred = Get-Credential
$session = New-PSSession -ComputerName target-dc.local -Credential $cred

# Create user remotely
Invoke-Command -Session $session -ScriptBlock {
    New-ADUser -Name "John Doe" -SamAccountName jdoe -UserPrincipalName jdoe@target.local
}

# Query AD remotely
Invoke-Command -Session $session -ScriptBlock {
    Get-ADUser -Filter * | Select Name, Enabled
}
```

---

## ⚠️ Important Notes

### Server Core Limitations (Not an Issue for Migration)
```yaml
What you CAN'T do:
❌ Log in with GUI (command-line only)
❌ Run graphical AD tools locally
❌ Use Server Manager GUI

What you CAN do (remotely):
✅ All AD management via RSAT
✅ PowerShell remoting
✅ Ansible automation
✅ Windows Admin Center (web UI)
✅ Group Policy management
```

**For migration DCs: These limitations don't matter!**
- Ansible does all the work remotely
- No one logs into DCs directly
- All management via automation

---

## 🎯 Final Recommendation

### Tier 1 (Free/Demo):
```yaml
DCs: 2x B1ms Server Core with auto-shutdown
Cost: $7/month
Perfect for: POC, learning, small demos
```

### Tier 2 (Production):
```yaml
Option A (Minimal): 1x B2s Server Core (source existing)
Cost: $31/month

Option B (Best): Use Entra ID (no target DC)
Cost: $0/month ⭐

Recommendation: Option B (Entra ID)
```

### Tier 3 (Enterprise):
```yaml
DCs: Use Entra ID (no new DCs)
Cost: $0/month
Perfect for: Cloud-first architecture
```

---

## 📋 Quick Wins Checklist

**Immediate Actions:**
- [ ] Switch all DCs to Server Core (50% smaller)
- [ ] Downsize to B1ms (Tier 1) or B2s (Tier 2)
- [ ] Enable auto-shutdown for Tier 1
- [ ] Use Entra ID for Tier 2/3 (eliminate target DC)
- [ ] Use Standard_LRS disks (not Premium)

**Expected Savings:**
- Tier 1: $140 → $7/month (95% off)
- Tier 2: $140 → $0/month (100% off with Entra)
- Tier 3: $140 → $0/month (100% off with Entra)

---

**Status:** Minimal DC sizing strategy complete  
**Recommendation:** B1ms Server Core + auto-shutdown for Tier 1, Entra ID for Tier 2/3  
**Maximum Savings:** $1,596/year per deployment! 🎉

