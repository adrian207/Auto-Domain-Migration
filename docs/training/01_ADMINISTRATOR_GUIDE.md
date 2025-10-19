# Administrator Training Guide

**Version:** 1.0  
**Last Updated:** January 2025  
**Target Audience:** System Administrators, Migration Engineers  
**Duration:** 4-6 hours self-paced

---

## 📋 Table of Contents

1. [Introduction](#introduction)
2. [Prerequisites](#prerequisites)
3. [Architecture Overview](#architecture-overview)
4. [Deployment Guide](#deployment-guide)
5. [Migration Workflow](#migration-workflow)
6. [Monitoring & Operations](#monitoring--operations)
7. [Self-Healing](#self-healing)
8. [Disaster Recovery](#disaster-recovery)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## 🎯 Introduction

### What You'll Learn

By the end of this guide, you will be able to:

- ✅ Deploy the migration infrastructure (all 3 tiers)
- ✅ Execute a complete domain migration
- ✅ Monitor migration progress and health
- ✅ Troubleshoot common issues
- ✅ Perform rollback operations
- ✅ Manage self-healing automation
- ✅ Execute disaster recovery procedures

### Training Path

```
Module 1: Architecture (30 min)
    ↓
Module 2: Deployment (60 min)
    ↓
Module 3: Migration Workflow (90 min)
    ↓
Module 4: Monitoring (45 min)
    ↓
Module 5: Self-Healing (45 min)
    ↓
Module 6: Disaster Recovery (60 min)
    ↓
Module 7: Troubleshooting (45 min)
```

---

## 📚 Prerequisites

### Required Knowledge

- **Active Directory:** Understanding of domains, OUs, trusts
- **PowerShell:** Basic scripting and cmdlets
- **Azure:** Basic portal navigation and CLI
- **Ansible:** Understanding of playbooks and roles
- **Networking:** DNS, subnets, firewalls

### Required Access

- **Azure Subscription:** Contributor access
- **Domain Admin:** Both source and target domains
- **GitHub:** Repository access
- **SSH/RDP:** Access to servers

### Required Tools

```powershell
# Install Azure PowerShell
Install-Module -Name Az -Force

# Install Ansible
pip install ansible

# Install Terraform
choco install terraform

# Install Pester (for testing)
Install-Module -Name Pester -MinimumVersion 5.0.0 -Force

# Install Git
choco install git
```

---

## 🏗️ Architecture Overview

### Three-Tier Deployment

#### Tier 1: Demo/PoC
- **Cost:** ~$50/month
- **Purpose:** Learning, testing, demos
- **Scale:** 2 DCs, 2 file servers
- **Uptime:** Best effort

#### Tier 2: Production
- **Cost:** ~$500-800/month
- **Purpose:** Small-medium business
- **Scale:** HA DCs, redundant file servers
- **Uptime:** 99.9% target

#### Tier 3: Enterprise
- **Cost:** ~$2,000-3,000/month
- **Purpose:** Large enterprise
- **Scale:** AKS cluster, geo-redundant
- **Uptime:** 99.99% target

### Component Map

```
┌─────────────────────────────────────────────────┐
│           Source Domain (old.local)             │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  │
│  │ Domain    │  │   File    │  │   Users   │  │
│  │Controller │  │  Servers  │  │ Computers │  │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  │
└────────┼──────────────┼──────────────┼─────────┘
         │              │              │
         │         ┌────▼────┐         │
         │         │  Trust  │         │
         │         │Establish│         │
         │         └────┬────┘         │
         │              │              │
┌────────▼──────────────▼──────────────▼─────────┐
│          Target Domain (new.local)              │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  │
│  │ Domain    │  │   File    │  │ Migrated  │  │
│  │Controller │  │  Servers  │  │  Objects  │  │
│  └───────────┘  └───────────┘  └───────────┘  │
└─────────────────────────────────────────────────┘
         │              │              │
         └──────────────┼──────────────┘
                        │
                   ┌────▼────┐
                   │   AWX   │
                   │Automation│
                   └────┬────┘
                        │
              ┌─────────┴─────────┐
              │                   │
         ┌────▼────┐        ┌────▼────┐
         │Prometheus│        │  Vault  │
         │Monitoring│        │ Secrets │
         └─────────┘        └─────────┘
```

---

## 🚀 Deployment Guide

### Step 1: Prepare Environment (15 minutes)

```powershell
# Clone repository
git clone https://github.com/yourusername/Auto-Domain-Migration.git
cd Auto-Domain-Migration

# Authenticate to Azure
Connect-AzAccount

# Set subscription
Set-AzContext -SubscriptionId "your-subscription-id"
```

### Step 2: Configure Variables (15 minutes)

```bash
# Copy example variables
cd terraform/azure-tier2
cp terraform.tfvars.example terraform.tfvars

# Edit variables
nano terraform.tfvars
```

**Key Variables:**
```hcl
subscription_id    = "your-subscription-id"
location          = "eastus"
environment       = "production"
admin_username    = "azureadmin"
source_domain     = "source.local"
target_domain     = "target.local"
```

### Step 3: Deploy Infrastructure (30 minutes)

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -out=tfplan

# Review plan carefully!
# Check: VMs, networks, costs

# Apply
terraform apply tfplan

# Save outputs
terraform output -json > outputs.json
```

**Expected Resources:**
- 2+ Virtual Machines (DCs)
- 2+ File Servers
- 1 Virtual Network
- 2+ Subnets
- Network Security Groups
- Storage Accounts
- Recovery Services Vault

### Step 4: Configure Ansible (15 minutes)

```bash
cd ../../ansible

# Update inventory with IPs from Terraform
nano inventory/hosts.ini
```

**hosts.ini:**
```ini
[source_dc]
dc01-source ansible_host=10.0.1.10 ansible_user=azureadmin

[target_dc]
dc01-target ansible_host=10.0.2.10 ansible_user=azureadmin

[file_servers]
fs01-source ansible_host=10.0.1.20 ansible_user=azureadmin
fs01-target ansible_host=10.0.2.20 ansible_user=azureadmin

[all:vars]
ansible_connection=winrm
ansible_winrm_transport=ntlm
ansible_winrm_server_cert_validation=ignore
```

### Step 5: Run Prerequisites Playbook (20 minutes)

```bash
# Test connectivity
ansible all -m win_ping

# Install prerequisites
ansible-playbook playbooks/01_prerequisites.yml

# Verify ADMT installation
ansible source_dc -m win_shell -a "Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\ADMT'"
```

### Step 6: Generate Test Data (Optional, 10 minutes)

```powershell
# On source DC
cd C:\scripts\ad-test-data
.\Generate-ADTestData.ps1 -Tier Tier2 -DomainDN "DC=source,DC=local"
```

**What it creates:**
- 500 users
- 250 computers  
- 50 groups
- Realistic attributes

---

## 🔄 Migration Workflow

### Phase 1: Discovery (15 minutes)

```bash
# Run discovery
ansible-playbook playbooks/00_discovery.yml

# Review discovery report
cat /tmp/discovery-report.json | jq .
```

**What it discovers:**
- Domain controllers
- User accounts
- Computer accounts
- Groups
- GPOs
- Trust relationships

### Phase 2: Trust Configuration (20 minutes)

```bash
# Establish trust
ansible-playbook playbooks/02_trust_configuration.yml \
  --extra-vars "source_domain=source.local target_domain=target.local"
```

**Verification:**
```powershell
# On target DC
Get-ADTrust -Filter * | Select-Object Name, Direction, TrustType
Test-ComputerSecureChannel -Server source.local
```

### Phase 3: User Migration (30-60 minutes)

```bash
# Create migration batch
ansible-playbook playbooks/04_migration.yml \
  --extra-vars "batch_id=batch001 migration_type=users"
```

**Monitor Progress:**
```powershell
# Check ADMT logs
Get-Content C:\ADMT\Logs\migration.log -Tail 20 -Wait

# Check batch status
Import-Module C:\ADMT\ADMT-Functions.psm1
Get-ADMTMigrationStatus
```

### Phase 4: Computer Migration (60-90 minutes)

```bash
# Migrate computers
ansible-playbook playbooks/04_migration.yml \
  --extra-vars "batch_id=batch002 migration_type=computers"
```

**Important:**
- Computers will reboot
- Users may be logged off
- Plan for maintenance window

### Phase 5: File Server Migration (2-4 hours)

```bash
# Run SMS migration
ansible-playbook playbooks/sms/02_execute_migration.yml
```

**Phases:**
1. Inventory (30 min)
2. Transfer (varies by data size)
3. Cutover (30 min)

### Phase 6: Validation (30 minutes)

```bash
# Run validation
ansible-playbook playbooks/05_validation.yml

# Review results
cat /tmp/validation-report.json | jq '.summary'
```

**Checks:**
- All users migrated
- Group memberships preserved
- File shares accessible
- Computers joined to new domain
- GPOs applied

---

## 📊 Monitoring & Operations

### Accessing Monitoring

**Grafana:**
```
URL: https://grafana.yourdomain.com
Default: admin / <from Key Vault>
```

**Prometheus:**
```
URL: https://prometheus.yourdomain.com
```

### Key Dashboards

#### 1. ADMT Migration Overview
- Users migrated (counter)
- Success rate (gauge)
- Migration rate (graph)
- Failed jobs (table)
- Job duration (histogram)

#### 2. Infrastructure Health
- VM status
- Disk space
- Network connectivity
- Service health

#### 3. Self-Healing Activity
- Remediation events
- Success rate
- MTTR trends

### Setting Up Alerts

**Email Notifications:**
```yaml
# Edit alertmanager config
kubectl edit configmap alertmanager -n monitoring

receivers:
  - name: 'email'
    email_configs:
      - to: 'your-email@example.com'
        from: 'alerts@yourdomain.com'
        smarthost: 'smtp.gmail.com:587'
```

**Slack Notifications:**
```yaml
receivers:
  - name: 'slack'
    slack_configs:
      - api_url: 'YOUR_WEBHOOK_URL'
        channel: '#alerts'
```

### Daily Operations Checklist

**Morning:**
- [ ] Check dashboard for overnight issues
- [ ] Review self-healing events
- [ ] Verify backup completion
- [ ] Check disk space trends

**During Migration:**
- [ ] Monitor migration progress
- [ ] Watch for errors
- [ ] Check domain controller health
- [ ] Verify network connectivity

**Evening:**
- [ ] Review day's migrations
- [ ] Check for failed jobs
- [ ] Plan next day's work
- [ ] Update stakeholders

---

## 🤖 Self-Healing

### Understanding Self-Healing

**How it works:**
```
1. Prometheus detects issue
2. Alert triggered
3. Alertmanager routes to webhook
4. Webhook triggers AWX job
5. Ansible playbook fixes issue
6. Alert resolves automatically
```

### Viewing Self-Healing Events

**AWX Dashboard:**
```
URL: https://awx.yourdomain.com
Jobs → Filter: "SelfHeal"
```

**Prometheus Metrics:**
```promql
# Success rate
rate(selfhealing_jobs_success_total[1h]) / 
rate(selfhealing_jobs_total[1h])

# Most triggered scenarios
topk(5, selfhealing_jobs_total)
```

### Disabling Self-Healing (Emergency)

**Temporary disable:**
```bash
# Silence all self-healing alerts
kubectl exec -n monitoring alertmanager-0 -- amtool silence add \
  --comment="Maintenance window" \
  --duration=2h \
  self_heal=enabled
```

**Permanent disable:**
```yaml
# Remove from alert rules
kubectl edit configmap prometheus-rules -n monitoring
# Remove: self_heal: enabled label
```

### Common Self-Healing Scenarios

| Scenario | Trigger | Action | MTTR |
|----------|---------|--------|------|
| DC Service Down | No heartbeat 5min | Restart service | 1min |
| Disk Space Low | <10% free | Clean temp files | 2min |
| Migration Failed | Job error | Retry with logging | 5min |
| DNS Down | DNS queries fail | Restart DNS service | 1min |
| Network Issue | Ping fails | Reset adapter | 2min |

---

## 🛡️ Disaster Recovery

### Running DR Validation

```powershell
cd tests/dr
.\Validate-DRReadiness.ps1 -Tier Tier2 -GenerateReport
```

**Check:**
- Backup freshness (< 24h)
- Snapshot availability
- DR site readiness
- Runbook accessibility

### Performing Test Restore

**Monthly Test (Required):**
```bash
# Restore one VM
az backup restore restore-azurevm \
  --resource-group admt-tier2-rg \
  --vault-name admt-vault \
  --container-name dc01-source \
  --item-name dc01-source \
  --rp-name $(az backup recoverypoint list ... | jq -r '.[0].name') \
  --restore-mode AlternateLocation \
  --target-vm-name dc01-source-test
```

**Document:**
- Restore duration (verify RTO)
- Data integrity
- Issues encountered
- Lessons learned

### Emergency Failover

**When to use:**
- Regional Azure outage
- Ransomware attack
- Catastrophic failure

**Command:**
```bash
ansible-playbook playbooks/dr/automated-failover.yml \
  --extra-vars "target_region=westus2 trigger_reason='Regional outage'"
```

**Estimated time:** 4 hours

---

## 🔧 Troubleshooting

### Common Issues

#### Issue 1: Trust Relationship Failed

**Symptoms:**
- "Trust relationship failed" error
- Cannot authenticate between domains

**Solution:**
```powershell
# On target DC
Test-ComputerSecureChannel -Server source.local -Credential (Get-Credential)

# If fails, reset trust
netdom trust target.local /domain:source.local /reset
```

#### Issue 2: Migration Job Stuck

**Symptoms:**
- Job running > 2 hours
- No progress in logs

**Solution:**
```powershell
# Check ADMT service
Get-Service -Name "ADMT*"

# Restart if needed
Restart-Service -Name "ADMT*"

# Check for locks
Get-ADUser -Identity "username" -Properties LockedOut
```

#### Issue 3: File Server Inaccessible

**Symptoms:**
- Cannot access shares
- "Network path not found"

**Solution:**
```powershell
# Check SMB service
Get-Service -Name LanmanServer

# Test share access
Test-NetConnection -ComputerName fs01.target.local -Port 445

# Verify share exists
Get-SmbShare -Name "ShareName"
```

#### Issue 4: Self-Healing Not Working

**Symptoms:**
- Alerts not triggering jobs
- Jobs failing immediately

**Solution:**
```bash
# Check webhook receiver
kubectl logs -n monitoring deployment/webhook-receiver

# Check AWX connectivity
curl https://awx.yourdomain.com/api/v2/ping/

# Verify AWX token
kubectl get secret awx-api-token -n monitoring -o yaml
```

### Getting Help

**Documentation:**
- README.md - Project overview
- docs/ - Detailed guides
- tests/README.md - Testing guide

**Logs:**
- ADMT: `C:\ADMT\Logs\`
- Ansible: `/var/log/ansible/`
- AWX: AWX UI → Jobs → View output
- Kubernetes: `kubectl logs -n <namespace> <pod>`

**Support:**
- GitHub Issues
- Internal wiki
- On-call engineer

---

## ✅ Best Practices

### Pre-Migration

1. **Backup Everything**
   - Source DC
   - Target DC
   - File servers
   - Databases

2. **Test in Lower Environment**
   - Deploy Tier 1 first
   - Migrate test users
   - Validate before production

3. **Communicate**
   - Email users 1 week before
   - Remind 1 day before
   - Send instructions

4. **Schedule Appropriately**
   - Off-hours for computers
   - Low-usage time for file servers
   - Allow buffer time

### During Migration

1. **Monitor Actively**
   - Watch dashboards
   - Check logs frequently
   - Respond to alerts quickly

2. **Document Issues**
   - Screenshot errors
   - Note timestamps
   - Record resolutions

3. **Communicate Status**
   - Update stakeholders hourly
   - Report blockers immediately
   - Set expectations

### Post-Migration

1. **Validate Thoroughly**
   - Test user logins
   - Verify file access
   - Check group memberships
   - Test applications

2. **Keep Source Domain**
   - Don't decommission immediately
   - Keep for 30-90 days
   - Monitor for issues

3. **Update Documentation**
   - New domain info
   - Server locations
   - Contact information

4. **Train Users**
   - New login process
   - File share locations
   - Support contacts

### Operational Excellence

1. **Run DR Tests Monthly**
   - Document results
   - Update procedures
   - Fix issues

2. **Review Self-Healing Weekly**
   - Check success rate
   - Identify patterns
   - Tune thresholds

3. **Update Regularly**
   - Windows updates
   - Ansible playbooks
   - Terraform modules

4. **Monitor Costs**
   - Run cost optimization script monthly
   - Right-size resources
   - Delete unused resources

---

## 📝 Certification

Upon completion of this guide, you should be able to:

- ✅ Deploy migration infrastructure independently
- ✅ Execute user/computer/file migrations
- ✅ Monitor and troubleshoot issues
- ✅ Perform rollback if needed
- ✅ Manage self-healing automation
- ✅ Execute disaster recovery procedures
- ✅ Follow operational best practices

### Next Steps

1. **Practice:** Deploy Tier 1 in your own subscription
2. **Experiment:** Break things and fix them
3. **Document:** Keep notes of your learnings
4. **Share:** Teach others what you've learned

---

## 📚 Additional Resources

- **Architecture:** `docs/00_MASTER_DESIGN.md`
- **Self-Healing:** `docs/31_SELF_HEALING_ARCHITECTURE.md`
- **Disaster Recovery:** `docs/32_DISASTER_RECOVERY_RUNBOOK.md`
- **Testing:** `tests/README.md`
- **CI/CD:** `.github/workflows/README.md`

---

**Congratulations on completing the Administrator Training!** 🎉

**Questions?** Create an issue on GitHub or contact your team lead.

**Version:** 1.0  
**Last Updated:** January 2025  
**Feedback:** Please submit feedback to improve this guide!

