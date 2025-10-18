# Azure Free Tier Deployment - Tier 1 (Demo)

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Purpose:** Deploy a zero-cost AD migration demo environment on Azure's free tier

---

## Overview

This Terraform configuration deploys a complete Active Directory migration environment on Azure, optimized to stay within free tier limits (target: $0-5/month).

### What Gets Deployed

- **Guacamole Bastion Host** (B1s VM) - Web-based secure access with dynamic IP handling
- **Ansible Controller** (B1s VM) - Migration orchestration
- **Source Domain Controller** (B1s VM) - Windows Server 2022
- **Target Domain Controller** (B1s VM) - Windows Server 2022
- **Test Workstation** (B1s VM) - Windows 11 for migration testing
- **PostgreSQL Flexible Server** (B1ms) - State store, telemetry, Guacamole DB
- **Storage Account** (Standard LRS) - Migration artifacts and USMT backups
- **Virtual Network** - 5 subnets with NSGs

**Total VMs**: 5 × B1s (750 free hours/month each = 3,750 hours total)  
**Estimated Cost**: $0-5/month (within free tier limits)

---

## Prerequisites

1. **Azure Subscription** with free tier available
2. **Terraform** >= 1.5.0 installed
3. **Azure CLI** installed and authenticated (`az login`)
4. **SSH Key** (optional - will be generated if not provided)

---

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Required changes:**
- Set strong `admin_password` (min 12 chars, complex)
- Set strong `guacamole_db_password`
- Set `allowed_ip_ranges` to your public IP (security!)

**Get your public IP:**
```bash
curl https://api.ipify.org
# Add to allowed_ip_ranges as ["YOUR_IP/32"]
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

Deployment takes ~15-20 minutes.

### 5. Access Guacamole

After deployment, Terraform will output the Guacamole URL:

```
guacamole_url = "https://X.X.X.X/"
```

**Default credentials:**
- Username: `guacadmin`
- Password: `guacadmin`

**⚠️ CHANGE THE PASSWORD IMMEDIATELY!**

---

## Post-Deployment Setup

### 1. Configure Source Domain Controller

1. Access via Guacamole (RDP to `10.0.10.10`)
2. Login with `azureadmin` and your password
3. Install AD DS:
   ```powershell
   Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
   ```
4. Promote to domain controller:
   ```powershell
   Install-ADDSForest `
       -DomainName "source.local" `
       -DomainMode "WinThreshold" `
       -ForestMode "WinThreshold" `
       -InstallDns `
       -SafeModeAdministratorPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
       -Force
   ```
5. Reboot when prompted

### 2. Configure Target Domain Controller

Same steps as above, but use `target.local` for domain name (RDP to `10.0.20.10`).

### 3. Join Test Workstation to Source Domain

1. RDP to `10.0.30.X` via Guacamole
2. Change DNS to source DC: `10.0.10.10`
3. Join to `source.local` domain
4. Reboot

### 4. Configure Ansible Controller

1. SSH to `10.0.2.10` via Guacamole
2. Clone migration repository:
   ```bash
   cd /opt/migration/repo
   git clone https://github.com/adrian207/Auto-Domain-Migration.git .
   ```
3. Activate Python venv:
   ```bash
   source /opt/migration/venv/bin/activate
   ```
4. Configure inventory files (see `ansible/inventory/`)
5. Run discovery:
   ```bash
   ansible-playbook playbooks/00_discovery.yml
   ```

---

## Dynamic IP Handling

The Guacamole VM automatically updates the NSG with its current public IP every 5 minutes via managed identity.

**Manual update from your workstation:**

See `scripts/azure/update-azure-nsg-ip.sh` (Bash) or `scripts/azure/Update-AzureNsgIp.ps1` (PowerShell) in the main repo.

---

## Cost Management

### Free Tier Limits (12 months)

- **B1s VMs**: 750 hours/month × 5 = 3,750 hours
- **PostgreSQL B1ms**: 750 hours/month
- **Storage**: 5 GB LRS
- **Bandwidth**: 100 GB outbound

### Stay Within Free Tier

1. **Stop VMs when not in use:**
   ```bash
   az vm deallocate --resource-group admigration-demo-rg --name admigration-demo-guacamole
   ```

2. **Monitor usage:**
   ```bash
   az consumption usage list --start-date 2025-10-01 --end-date 2025-10-31
   ```

3. **Set budget alerts** in Azure Portal

---

## Accessing VMs

**All access is through Guacamole** - no direct SSH/RDP from internet.

### Add RDP Connection in Guacamole

1. Log in to Guacamole web interface
2. Settings → Connections → New Connection
3. Protocol: RDP
4. Hostname: `10.0.X.X` (use private IPs from terraform output)
5. Username: `azureadmin`
6. Password: (your admin password)

### Add SSH Connection

1. Settings → Connections → New Connection
2. Protocol: SSH
3. Hostname: `10.0.2.10` (Ansible controller)
4. Username: `azureadmin`
5. Private Key: (use generated key from terraform output)

---

## Troubleshooting

### Guacamole not accessible

```bash
# Check NSG rule
az network nsg rule show \
    --resource-group admigration-demo-rg \
    --nsg-name admigration-demo-bastion-nsg \
    --name Allow-HTTPS-Inbound

# Check if your IP changed
curl https://api.ipify.org

# Update NSG manually
az network nsg rule update \
    --resource-group admigration-demo-rg \
    --nsg-name admigration-demo-bastion-nsg \
    --name Allow-HTTPS-Inbound \
    --source-address-prefixes "YOUR_NEW_IP/32"
```

### PostgreSQL connection issues

```bash
# Verify firewall rules
az postgres flexible-server firewall-rule list \
    --resource-group admigration-demo-rg \
    --name admigration-demo-psql-XXXXXX

# Test connection from Ansible controller
psql -h admigration-demo-psql-XXXXXX.postgres.database.azure.com \
     -U azureadmin -d migration_state
```

### VM won't start

```bash
# Check VM status
az vm get-instance-view \
    --resource-group admigration-demo-rg \
    --name admigration-demo-ansible \
    --query instanceView.statuses

# Start VM
az vm start \
    --resource-group admigration-demo-rg \
    --name admigration-demo-ansible
```

---

## Cleanup

**Warning:** This will destroy ALL resources and data!

```bash
terraform destroy
```

Or via Azure CLI:

```bash
az group delete --name admigration-demo-rg --yes --no-wait
```

---

## Next Steps

1. ✅ Review [Master Design Document](../../docs/00_MASTER_DESIGN.md)
2. ✅ Configure domain controllers and trust (if needed)
3. ✅ Run service discovery playbooks
4. ✅ Execute test migration
5. ✅ Scale to production (Tier 2) if successful

---

## Security Considerations

- ⚠️ Change all default passwords immediately
- ⚠️ Restrict `allowed_ip_ranges` to your IP only
- ⚠️ Enable Azure Security Center (free tier available)
- ⚠️ Review NSG rules regularly
- ⚠️ Store terraform.tfvars securely (contains passwords)
- ⚠️ Do NOT commit terraform.tfvars to git!

---

## Support

For issues, questions, or contributions:
- **GitHub**: https://github.com/adrian207/Auto-Domain-Migration
- **Email**: adrian207@gmail.com
- **Documentation**: [docs/](../../docs/)

---

**Author:** Adrian Johnson  
**License:** [To be determined]  
**Last Updated:** October 2025

