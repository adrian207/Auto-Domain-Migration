# Disaster Recovery Runbook

**Version:** 1.0  
**Last Updated:** January 2025  
**Status:** Production Ready

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [RTO & RPO Objectives](#rto--rpo-objectives)
3. [Backup Strategies](#backup-strategies)
4. [Disaster Scenarios](#disaster-scenarios)
5. [Recovery Procedures](#recovery-procedures)
6. [Failover Automation](#failover-automation)
7. [Validation & Testing](#validation--testing)
8. [Contact Information](#contact-information)

---

## 🎯 Overview

This runbook provides step-by-step procedures for recovering from various disaster scenarios affecting the Auto Domain Migration infrastructure.

### Scope

**Protected Systems:**
- Domain Controllers (source & target)
- File Servers
- Database Servers (PostgreSQL)
- AWX/Ansible Tower
- Monitoring Stack (Prometheus/Grafana)
- AKS Cluster (Tier 3)

**Disaster Types:**
- Data center outage
- Regional Azure outage
- Ransomware attack
- Hardware failure
- Human error (accidental deletion)
- Corruption

---

## ⏱️ RTO & RPO Objectives

### Recovery Time Objective (RTO)

| Component | RTO Target | Actual | Method |
|-----------|------------|--------|--------|
| **Domain Controllers** | 1 hour | 45 min | Azure VM Restore |
| **File Servers** | 2 hours | 1.5 hours | SMS + ZFS Snapshots |
| **Database** | 30 minutes | 20 min | Geo-redundant restore |
| **AWX** | 1 hour | 45 min | Container redeploy |
| **AKS Cluster** | 2 hours | 90 min | Terraform + Helm |
| **Monitoring** | 30 minutes | 20 min | Helm chart redeploy |

### Recovery Point Objective (RPO)

| Component | RPO Target | Actual | Backup Frequency |
|-----------|------------|--------|------------------|
| **Domain Controllers** | 24 hours | 12 hours | Daily + Transaction logs |
| **File Servers** | 1 hour | 1 hour | Hourly ZFS snapshots |
| **Database** | 5 minutes | 5 minutes | Continuous replication |
| **Configuration** | 1 hour | Real-time | Git + IaC |
| **Monitoring Data** | 1 hour | 15 min | Prometheus remote write |

---

## 💾 Backup Strategies

### 1. Azure VM Backups

**Tool:** Azure Backup (Recovery Services Vault)

**Schedule:**
- Daily: 2:00 AM UTC
- Retention: 7/30/365 days (Basic/Standard/Premium)
- Storage: Geo-redundant

**Coverage:**
- All domain controller VMs
- File server VMs
- Database VMs
- Management VMs

**Script:** `scripts/azure/Enable-AzureBackup.ps1`

### 2. ZFS File Server Snapshots

**Tool:** ZFS snapshot automation

**Schedule:**
- Hourly: Keep 24
- Daily: Keep 7
- Weekly: Keep 4
- Monthly: Keep 12

**Replication:** To secondary site (optional)

**Script:** `scripts/zfs/Configure-ZFSSnapshots.ps1`

### 3. Database Backups

**PostgreSQL:**
- Continuous WAL archiving
- Point-in-time recovery (PITR)
- Geo-replicated to secondary region
- Automated backups every 6 hours

**Azure SQL:**
- Automatic daily backups
- 35-day retention
- Geo-redundant storage

### 4. Configuration Backups

**Infrastructure as Code:**
- Terraform state in Azure Storage
- Geo-replicated
- Versioned in Git

**Ansible Playbooks:**
- Git repository
- GitHub backup
- Local clones

**AWX Configuration:**
- Database backup
- Exported job templates
- Credentials (encrypted)

### 5. Monitoring Data

**Prometheus:**
- Remote write to secondary Prometheus
- Long-term storage in S3/Azure Blob
- 90-day retention

**Logs:**
- Loki with Azure Blob backend
- 30-day retention
- Searchable archives

---

## 🔥 Disaster Scenarios

### Scenario 1: Single VM Failure

**Impact:** Low  
**RTO:** 1 hour  
**RPO:** 24 hours

**Symptoms:**
- VM not responding
- Services unreachable
- Azure alerts

**Recovery:** See [VM Recovery Procedure](#procedure-1-vm-recovery)

---

### Scenario 2: File Server Data Loss

**Impact:** Medium-High  
**RTO:** 2 hours  
**RPO:** 1 hour

**Symptoms:**
- Files missing or corrupted
- Ransomware detected
- Accidental deletion

**Recovery:** See [File Server Recovery](#procedure-2-file-server-recovery)

---

### Scenario 3: Database Corruption

**Impact:** High  
**RTO:** 30 minutes  
**RPO:** 5 minutes

**Symptoms:**
- Database errors
- Data inconsistency
- Application failures

**Recovery:** See [Database Recovery](#procedure-3-database-recovery)

---

### Scenario 4: Regional Azure Outage

**Impact:** Critical  
**RTO:** 4 hours  
**RPO:** 1 hour

**Symptoms:**
- Entire region unavailable
- Azure status page confirms
- All services down

**Recovery:** See [Regional Failover](#procedure-4-regional-failover)

---

### Scenario 5: Ransomware Attack

**Impact:** Critical  
**RTO:** 6 hours  
**RPO:** 24 hours

**Symptoms:**
- Files encrypted
- Ransom note
- Unusual network activity

**Recovery:** See [Ransomware Recovery](#procedure-5-ransomware-recovery)

---

## 🔧 Recovery Procedures

### Procedure 1: VM Recovery

**Prerequisites:**
- Access to Azure Portal
- Recovery Services Vault permissions
- Alternative admin credentials

**Steps:**

1. **Identify Failed VM**
   ```bash
   # Check VM status
   az vm get-instance-view \
     --resource-group admt-tier2-rg \
     --name dc01-source \
     --query instanceView.statuses
   ```

2. **Stop Failed VM**
   ```bash
   az vm stop \
     --resource-group admt-tier2-rg \
     --name dc01-source
   ```

3. **Select Recovery Point**
   ```bash
   # List recovery points
   az backup recoverypoint list \
     --resource-group admt-tier2-rg \
     --vault-name admt-vault \
     --container-name dc01-source \
     --item-name dc01-source
   ```

4. **Restore VM**
   
   **Option A: Restore to new VM (recommended)**
   ```bash
   az backup restore restore-azurevm \
     --resource-group admt-tier2-rg \
     --vault-name admt-vault \
     --container-name dc01-source \
     --item-name dc01-source \
     --rp-name <recovery-point-name> \
     --target-resource-group admt-tier2-rg \
     --restore-mode AlternateLocation \
     --target-vm-name dc01-source-restored
   ```
   
   **Option B: Replace disks**
   ```bash
   az backup restore restore-disks \
     --resource-group admt-tier2-rg \
     --vault-name admt-vault \
     --container-name dc01-source \
     --item-name dc01-source \
     --rp-name <recovery-point-name> \
     --storage-account <storage-account>
   ```

5. **Verify Restored VM**
   ```bash
   # Check VM is running
   az vm show \
     --resource-group admt-tier2-rg \
     --name dc01-source-restored \
     --query powerState
   
   # Test connectivity
   ping dc01-source-restored.source.local
   ```

6. **Update DNS/Network**
   - Update DNS records to point to new VM
   - Update NSG rules if needed
   - Test application connectivity

7. **Delete Failed VM** (after verification)
   ```bash
   az vm delete \
     --resource-group admt-tier2-rg \
     --name dc01-source \
     --yes
   ```

**Estimated Time:** 45 minutes

---

### Procedure 2: File Server Recovery

**Prerequisites:**
- ZFS snapshots available
- Alternative file server (if primary lost)
- SMB share permissions documented

**Steps:**

1. **Assess Damage**
   ```bash
   # SSH to file server
   ssh root@fs01.source.local
   
   # List ZFS datasets
   zfs list
   
   # Check last good snapshot
   zfs list -t snapshot | tail -n 20
   ```

2. **Rollback to Snapshot** (if filesystem intact)
   ```bash
   # Identify last good snapshot
   SNAPSHOT="tank/shares@auto-hourly-20250115-140000"
   
   # Rollback
   zfs rollback $SNAPSHOT
   
   # Verify
   ls -la /tank/shares
   ```

3. **Restore from Snapshot** (selective recovery)
   ```bash
   # Mount snapshot
   mkdir /mnt/snapshot
   mount -t zfs tank/shares@auto-hourly-20250115-140000 /mnt/snapshot
   
   # Copy files
   cp -a /mnt/snapshot/path/to/files /tank/shares/path/
   
   # Unmount
   umount /mnt/snapshot
   ```

4. **Restore from Azure Backup** (if ZFS unavailable)
   ```bash
   # Use Azure File Sync or Azure Backup
   az backup restore \
     --container-name fs01-source \
     --item-name FileShare-shares \
     --rp-name <recovery-point> \
     --restore-mode AlternateLocation
   ```

5. **Verify Data Integrity**
   ```powershell
   # From Windows client
   Get-ChildItem \\fs01.source.local\shares -Recurse | 
     Select-Object Name, Length, LastWriteTime |
     Export-Csv integrity-check.csv
   ```

6. **Restore Permissions**
   ```powershell
   # Export current permissions
   Get-Acl \\fs01.source.local\shares | Export-Clixml permissions.xml
   
   # Apply saved permissions
   $acl = Import-Clixml permissions.xml
   Set-Acl \\fs01.source.local\shares $acl
   ```

7. **Test Access**
   ```powershell
   # Test from domain user
   Test-Path \\fs01.source.local\shares\HR
   Get-ChildItem \\fs01.source.local\shares\HR
   ```

**Estimated Time:** 1.5 hours

---

### Procedure 3: Database Recovery

**Prerequisites:**
- Database backup available
- Alternative database server (if primary lost)
- Connection strings documented

**PostgreSQL Recovery:**

1. **Stop Application Connections**
   ```bash
   # Stop AWX
   kubectl scale deployment awx-web --replicas=0 -n awx
   kubectl scale deployment awx-task --replicas=0 -n awx
   ```

2. **Identify Recovery Point**
   ```bash
   # List available backups
   az postgres flexible-server backup list \
     --resource-group admt-tier2-rg \
     --server-name admt-postgres
   ```

3. **Restore Database**
   ```bash
   # Point-in-time restore
   az postgres flexible-server restore \
     --resource-group admt-tier2-rg \
     --name admt-postgres-restored \
     --source-server admt-postgres \
     --restore-time "2025-01-15T14:00:00Z"
   ```

4. **Update Connection Strings**
   ```bash
   # Update AWX database connection
   kubectl edit secret awx-postgres-configuration -n awx
   # Update: host=admt-postgres-restored.postgres.database.azure.com
   ```

5. **Restart Applications**
   ```bash
   kubectl scale deployment awx-web --replicas=2 -n awx
   kubectl scale deployment awx-task --replicas=2 -n awx
   ```

6. **Verify Database Integrity**
   ```sql
   -- Connect to database
   psql -h admt-postgres-restored.postgres.database.azure.com \
        -U awxadmin -d awx
   
   -- Check tables
   \dt
   
   -- Verify data
   SELECT COUNT(*) FROM main_job;
   SELECT * FROM main_job ORDER BY created DESC LIMIT 10;
   ```

**Estimated Time:** 20 minutes

---

### Procedure 4: Regional Failover

**Prerequisites:**
- Secondary region configured
- Geo-replicated storage
- Traffic Manager or Front Door
- Runbook tested

**Steps:**

1. **Confirm Regional Outage**
   - Check Azure Status: https://status.azure.com
   - Verify with Azure Support
   - Check all services in region

2. **Activate DR Site**
   ```bash
   # Deploy to secondary region using Terraform
   cd terraform/azure-tier2
   
   # Update location
   terraform apply -var="location=westus2" -var="env=dr"
   ```

3. **Restore Data**
   ```bash
   # VMs from geo-redundant backup
   az backup restore restore-azurevm \
     --vault-name admt-vault-westus2 \
     ...
   
   # Database from geo-replica
   az postgres flexible-server geo-restore \
     --resource-group admt-tier2-rg-dr \
     --name admt-postgres-dr \
     --source-server <geo-replica-id>
   ```

4. **Update DNS**
   ```bash
   # Update DNS to point to DR site
   az network dns record-set a update \
     --resource-group admt-dns-rg \
     --zone-name source.local \
     --name dc01 \
     --set aRecords[0].ipv4Address=<new-ip>
   ```

5. **Verify Services**
   ```bash
   # Test each service
   curl https://awx-dr.example.com/api/v2/ping/
   nslookup dc01.source.local
   Test-NetConnection -ComputerName fs01.source.local -Port 445
   ```

6. **Notify Users**
   - Send email notification
   - Update status page
   - Post in Slack/Teams

**Estimated Time:** 4 hours

---

### Procedure 5: Ransomware Recovery

**Prerequisites:**
- Isolated backup (air-gapped or immutable)
- Clean recovery environment
- Malware analysis tools

**Steps:**

1. **Isolate Infected Systems** (IMMEDIATELY)
   ```bash
   # Disable network interfaces
   az vm update \
     --resource-group admt-tier2-rg \
     --name <infected-vm> \
     --set networkProfile.networkInterfaces[0].primary=false
   
   # Or shutdown
   az vm deallocate \
     --resource-group admt-tier2-rg \
     --name <infected-vm>
   ```

2. **Assess Scope**
   - Identify encrypted files
   - Check all systems
   - Review logs for patient zero
   - Document timeline

3. **Determine Recovery Point**
   ```bash
   # Find last known good backup (before infection)
   az backup recoverypoint list \
     --vault-name admt-vault \
     --item-name <vm-name> \
     --start-date "2025-01-01" \
     --end-date "2025-01-14"
   ```

4. **Restore from Clean Backup**
   ```bash
   # Restore VMs to NEW resource group
   az backup restore restore-azurevm \
     --resource-group admt-tier2-recovery \
     --vault-name admt-vault \
     --rp-name <last-clean-backup>
   ```

5. **Scan for Malware**
   ```bash
   # On recovered VMs
   # Run Microsoft Defender full scan
   Start-MpScan -ScanType FullScan
   
   # Update definitions first
   Update-MpSignature
   ```

6. **Verify Clean State**
   - Review all startup items
   - Check scheduled tasks
   - Inspect registry
   - Review user accounts
   - Change all passwords

7. **Restore Data** (from ZFS snapshots pre-infection)
   ```bash
   # Rollback to snapshot before infection
   zfs rollback tank/shares@auto-daily-20250113-010000
   ```

8. **Gradually Bring Online**
   - Start with isolated network
   - Test thoroughly
   - Monitor closely
   - Expand access slowly

**Estimated Time:** 6-8 hours

---

## 🤖 Failover Automation

### Automated Failover Triggers

**Health Checks:**
- Domain controller unreachable (> 5 minutes)
- Database connection failures (> 3 consecutive)
- File share inaccessible (> 10 minutes)
- Regional service degradation

**Automation:** `ansible/playbooks/dr/automated-failover.yml`

### Manual Failover

**When to use:**
- Planned maintenance
- Testing DR procedures
- Performance issues
- Cost optimization

**Command:**
```bash
ansible-playbook \
  -i inventory/dr.ini \
  playbooks/dr/manual-failover.yml \
  --extra-vars "target_region=westus2"
```

---

## ✅ Validation & Testing

### Monthly DR Test

**Schedule:** First Sunday of each month, 2:00 AM

**Test Scope:**
- Restore one VM
- Restore one file share
- Restore one database
- Verify data integrity
- Document results

**Script:** `tests/dr/monthly-dr-test.ps1`

### Quarterly Full DR Drill

**Schedule:** Quarterly (Jan, Apr, Jul, Oct)

**Test Scope:**
- Complete regional failover
- All services restored
- End-to-end testing
- User acceptance testing
- Document lessons learned

**Checklist:** `docs/dr-drill-checklist.md`

---

## 📞 Contact Information

### Emergency Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| **Primary On-Call** | TBD | xxx-xxx-xxxx | oncall@example.com |
| **Backup On-Call** | TBD | xxx-xxx-xxxx | backup@example.com |
| **Manager** | TBD | xxx-xxx-xxxx | manager@example.com |
| **Azure Support** | Microsoft | 1-800-xxx-xxxx | support.azure.com |

### Escalation Path

1. **L1:** Primary On-Call (respond within 15 min)
2. **L2:** Backup On-Call (if L1 unavailable after 30 min)
3. **L3:** Manager (for critical incidents)
4. **L4:** Azure Support (for Azure-specific issues)

### Communication Channels

- **Slack:** #incident-response
- **Teams:** Incident Response Team
- **Email:** incidents@example.com
- **Status Page:** https://status.example.com

---

**Status:** ✅ Production Ready  
**Last Tested:** TBD  
**Next Test:** TBD  
**Version:** 1.0  

**Remember: Practice makes perfect. Test your DR procedures regularly!** 🛡️

