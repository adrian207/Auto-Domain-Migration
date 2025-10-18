# vSphere Tier 1 (Demo) Deployment

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Purpose:** Deploy an on-premises AD migration demo environment on VMware vSphere

---

## Overview

This Terraform configuration deploys a complete Active Directory migration environment on VMware vSphere infrastructure, suitable for demos, testing, and small-scale migrations.

### What Gets Deployed

- **Guacamole Bastion Host** (Ubuntu 22.04) - Web-based secure access
- **Ansible Controller** (Ubuntu 22.04) - Migration orchestration
- **PostgreSQL Server** (Ubuntu 22.04) - State store, telemetry, Guacamole DB
- **Source Domain Controller** (Windows Server 2022) - Source AD domain
- **Target Domain Controller** (Windows Server 2022) - Target AD domain
- **Test Workstations** (Windows 11) - Migration test targets (configurable count)

**Resource Requirements:**
- vCPUs: 12-14 (depending on number of workstations)
- RAM: 20-24 GB
- Storage: 600-800 GB
- Network: Single VLAN or port group

**Cost:** On-premises infrastructure (no cloud costs, only electricity)

---

## Prerequisites

### VMware Infrastructure

1. **vCenter Server** 7.0+ or 8.0+
2. **ESXi Cluster** with available resources:
   - 14+ vCPUs
   - 24+ GB RAM
   - 800+ GB storage
3. **Network** with:
   - DHCP or static IP allocation
   - Internet access for VMs (for package installation)
4. **VM Templates** (must be created before running Terraform):
   - Ubuntu 22.04 LTS (with cloud-init support)
   - Windows Server 2022
   - Windows 11

### Software Requirements

1. **Terraform** >= 1.5.0
2. **VMware PowerCLI** (for template creation)
3. **SSH key pair** (will use for Linux VMs)

### Creating VM Templates

See [docs/19_VSPHERE_IMPLEMENTATION.md](../../docs/19_VSPHERE_IMPLEMENTATION.md) for detailed instructions on creating templates.

**Quick template creation:**

```powershell
# Connect to vCenter
Connect-VIServer -Server vcenter.corp.local

# Create Ubuntu 22.04 template
# 1. Deploy Ubuntu 22.04 ISO
# 2. Install cloud-init and open-vm-tools
# 3. Convert to template

# Create Windows templates
# 1. Deploy Windows Server 2022 / Windows 11
# 2. Sysprep and generalize
# 3. Convert to template
```

---

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Required changes:**
- Set `vsphere_server`, `vsphere_user`, `vsphere_password`
- Set `datacenter`, `cluster`, `datastore`, `network_name`
- Set `gateway`, `dns_servers`, and IP addresses
- Set strong `admin_password` and `postgres_password`
- Add your `ssh_public_key`
- Verify template names match your vCenter templates

**Get your SSH public key:**
```bash
cat ~/.ssh/id_rsa.pub
# Copy the output to ssh_public_key variable
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

Deployment takes ~15-30 minutes depending on your infrastructure.

### 5. Access Guacamole

After deployment, Terraform will output the Guacamole URL:

```
guacamole_url = "https://10.0.1.10/"
```

**Default credentials:**
- Username: `guacadmin`
- Password: `guacadmin`

**⚠️ CHANGE THE PASSWORD IMMEDIATELY!**

---

## Post-Deployment Setup

### 1. Configure Source Domain Controller

1. Access via Guacamole (RDP to source DC IP)
2. Login with `administrator` and your password
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

Same steps as above, but use `target.local` for domain name.

### 3. Join Test Workstations to Source Domain

1. RDP to each workstation via Guacamole
2. Change DNS to source DC IP
3. Join to `source.local` domain:
   ```powershell
   Add-Computer -DomainName "source.local" -Credential (Get-Credential) -Restart
   ```

### 4. Configure Ansible Controller

1. SSH to Ansible controller via Guacamole
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

### 5. Verify PostgreSQL

```bash
# SSH to Ansible controller
psql -h 10.0.2.20 -U administrator -d migration_state -c "\dt"
```

Expected output: List of tables (migration_batches, migration_targets, migration_events)

---

## Accessing VMs

**All access is through Guacamole** - no direct connections required.

### Add RDP Connection in Guacamole

1. Log in to Guacamole web interface
2. Settings → Connections → New Connection
3. Protocol: RDP
4. Hostname: (use private IP from terraform output)
5. Username: `administrator`
6. Password: (your admin password)

### Add SSH Connection

1. Settings → Connections → New Connection
2. Protocol: SSH
3. Hostname: (use private IP)
4. Username: `administrator`
5. Private Key: (your SSH private key)

---

## Management

### Start/Stop VMs

**Via Terraform:**
```bash
# Stop all VMs (deallocate)
terraform destroy

# Restart specific VMs (use vSphere client or PowerCLI)
```

**Via PowerCLI:**
```powershell
Connect-VIServer -Server vcenter.corp.local

# Stop VMs
Get-VM -Name "admigration-demo-*" | Stop-VM -Confirm:$false

# Start VMs
Get-VM -Name "admigration-demo-*" | Start-VM

# Check VM status
Get-VM -Name "admigration-demo-*" | Select-Object Name, PowerState
```

### Snapshots (for testing)

```powershell
# Create snapshot of all VMs
Get-VM -Name "admigration-demo-*" | New-Snapshot -Name "Pre-Migration"

# Revert to snapshot
Get-VM -Name "admigration-demo-*" | Get-Snapshot -Name "Pre-Migration" | Set-VM -Snapshot -Confirm:$false

# Remove snapshots
Get-VM -Name "admigration-demo-*" | Get-Snapshot | Remove-Snapshot -Confirm:$false
```

---

## Troubleshooting

### Guacamole not accessible

1. Check VM is powered on:
   ```powershell
   Get-VM -Name "admigration-demo-guacamole" | Select-Object PowerState
   ```

2. Check network connectivity:
   ```bash
   ping 10.0.1.10
   ```

3. Check Guacamole service:
   ```bash
   # SSH to Guacamole VM
   docker ps
   sudo systemctl status nginx
   ```

### PostgreSQL connection issues

```bash
# SSH to PostgreSQL VM
sudo systemctl status postgresql
sudo -u postgres psql -c "\l"

# Check listening ports
sudo netstat -tlnp | grep 5432

# Test connection from Ansible controller
psql -h 10.0.2.20 -U administrator -d migration_state
```

### VM customization failed

[Inference] This may indicate that VMware tools are not running or cloud-init is not configured correctly.

```powershell
# Check VM events in vCenter
Get-VM -Name "admigration-demo-ansible" | Get-VIEvent | Select-Object -First 10
```

Fix:
- Ensure templates have cloud-init (Linux) or sysprep (Windows)
- Verify VMware Tools are installed and running
- Check network connectivity during customization

### Domain controller promotion fails

1. Verify DNS is configured correctly
2. Check Windows Firewall settings
3. Ensure static IP is configured
4. Review Event Viewer logs

---

## Scaling to Production (Tier 2)

Once demo is successful, see:
- [terraform/vsphere-tier2/](../vsphere-tier2/) - Production-scale deployment
- [docs/19_VSPHERE_IMPLEMENTATION.md](../../docs/19_VSPHERE_IMPLEMENTATION.md) - Full documentation

**Tier 2 features:**
- High availability (HA)
- Distributed Resource Scheduler (DRS)
- vMotion support
- Multiple AWX runners
- PostgreSQL clustering
- Advanced monitoring

---

## Cleanup

**Warning:** This will destroy ALL VMs and data!

```bash
terraform destroy
```

Or via PowerCLI:

```powershell
# Remove all VMs
Get-VM -Name "admigration-demo-*" | Remove-VM -DeletePermanently -Confirm:$false

# Remove resource pool
Get-ResourcePool -Name "admigration-demo-pool" | Remove-ResourcePool -Confirm:$false

# Remove VM folder
Get-Folder -Name "demo" | Remove-Folder -Confirm:$false
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
- ⚠️ Use firewall rules to restrict access
- ⚠️ Store terraform.tfvars securely (contains passwords)
- ⚠️ Do NOT commit terraform.tfvars to git!
- ⚠️ Use vCenter RBAC to limit Terraform service account permissions
- ⚠️ Enable vSphere encryption for sensitive VMs

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


