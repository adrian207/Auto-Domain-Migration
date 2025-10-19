# Quick Reference Cards

**Version:** 1.0  
**Last Updated:** January 2025  
**Purpose:** Printable quick reference cards for common tasks

---

## 📋 Table of Contents

1. [Administrator Quick Reference](#administrator-quick-reference)
2. [Migration Commands](#migration-commands)
3. [Troubleshooting Commands](#troubleshooting-commands)
4. [Self-Healing Commands](#self-healing-commands)
5. [DR Commands](#dr-commands)
6. [End User Quick Reference](#end-user-quick-reference)

---

## 👨‍💼 Administrator Quick Reference

**Print this page and laminate for your desk!**

```
╔══════════════════════════════════════════════════════════════════════╗
║                ADMINISTRATOR QUICK REFERENCE CARD                    ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ DEPLOYMENT                                                           ║
║ ─────────────────────────────────────────────────────────────────── ║
║  terraform init && terraform plan && terraform apply                 ║
║  ansible-playbook playbooks/01_prerequisites.yml                     ║
║  ansible-playbook playbooks/master_migration.yml                     ║
║                                                                      ║
║ MIGRATION                                                            ║
║ ─────────────────────────────────────────────────────────────────── ║
║  ansible-playbook playbooks/04_migration.yml \                       ║
║    --extra-vars "batch_id=batch001 migration_type=users"             ║
║                                                                      ║
║  Get-ADMTMigrationStatus                                             ║
║  Export-ADMTReport -ReportType Summary                               ║
║                                                                      ║
║ ROLLBACK                                                             ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Invoke-ADMTRollback -BatchId batch001 -Force                        ║
║  ansible-playbook playbooks/99_rollback.yml                          ║
║                                                                      ║
║ MONITORING                                                           ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Grafana:     https://grafana.yourdomain.com                         ║
║  Prometheus:  https://prometheus.yourdomain.com                      ║
║  AWX:         https://awx.yourdomain.com                             ║
║                                                                      ║
║ DISASTER RECOVERY                                                    ║
║ ─────────────────────────────────────────────────────────────────── ║
║  .\Validate-DRReadiness.ps1 -Tier Tier2 -GenerateReport              ║
║  ansible-playbook playbooks/dr/automated-failover.yml                ║
║                                                                      ║
║ EMERGENCY CONTACTS                                                   ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Primary On-Call:  ___________________  Phone: _____________        ║
║  Backup On-Call:   ___________________  Phone: _____________        ║
║  Azure Support:    1-800-xxx-xxxx                                    ║
║                                                                      ║
║ KEY PATHS                                                            ║
║ ─────────────────────────────────────────────────────────────────── ║
║  ADMT Logs:       C:\ADMT\Logs\                                      ║
║  Ansible Logs:    /var/log/ansible/                                  ║
║  Terraform:       terraform/azure-tier2/                             ║
║  Documentation:   docs/                                              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 🔄 Migration Commands

```
╔══════════════════════════════════════════════════════════════════════╗
║                     MIGRATION COMMAND CARD                           ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ ADMT MODULE                                                          ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Import-Module C:\ADMT\ADMT-Functions.psm1                           ║
║                                                                      ║
║ CREATE BATCH                                                         ║
║ ─────────────────────────────────────────────────────────────────── ║
║  New-ADMTMigrationBatch `                                            ║
║    -BatchId "batch001" `                                             ║
║    -Users @("user1", "user2") `                                      ║
║    -Computers @("pc1", "pc2") `                                      ║
║    -Groups @("group1") `                                             ║
║    -SourceDomain "source.local" `                                    ║
║    -TargetDomain "target.local" `                                    ║
║    -TargetOU "OU=Migrated,DC=target,DC=local"                        ║
║                                                                      ║
║ CHECK STATUS                                                         ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Get-ADMTMigrationStatus                                             ║
║  Get-ADMTMigrationStatus -BatchId "batch001"                         ║
║                                                                      ║
║ EXPORT REPORTS                                                       ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Export-ADMTReport -ReportType Summary                               ║
║  Export-ADMTReport -ReportType Detailed -OutputPath C:\Reports       ║
║  Export-ADMTReport -ReportType Failures                              ║
║                                                                      ║
║ ROLLBACK                                                             ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Invoke-ADMTRollback -BatchId "batch001" -Force                      ║
║                                                                      ║
║ VALIDATION                                                           ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Check user migrated                                               ║
║  Get-ADUser -Identity username -Server target.local                  ║
║                                                                      ║
║  # Verify group membership                                           ║
║  Get-ADPrincipalGroupMembership username -Server target.local        ║
║                                                                      ║
║  # Check SID history                                                 ║
║  Get-ADUser -Identity username -Properties SIDHistory                ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 🔧 Troubleshooting Commands

```
╔══════════════════════════════════════════════════════════════════════╗
║                  TROUBLESHOOTING COMMAND CARD                        ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ DOMAIN CONTROLLER                                                    ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Check DC status                                                   ║
║  Get-Service -Name NTDS                                              ║
║  dcdiag /v                                                           ║
║  repadmin /showrepl                                                  ║
║                                                                      ║
║  # Test trust                                                        ║
║  Get-ADTrust -Filter * | Select-Object Name, Direction               ║
║  Test-ComputerSecureChannel -Server source.local                     ║
║  netdom trust target.local /domain:source.local /verify              ║
║                                                                      ║
║ NETWORK                                                              ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Basic connectivity                                                ║
║  Test-NetConnection -ComputerName dc01.target.local                  ║
║  Test-NetConnection -ComputerName dc01.target.local -Port 389        ║
║                                                                      ║
║  # DNS                                                               ║
║  Resolve-DnsName dc01.target.local                                   ║
║  nslookup dc01.target.local                                          ║
║  ipconfig /flushdns                                                  ║
║                                                                      ║
║ FILE SERVERS                                                         ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Check shares                                                      ║
║  Get-SmbShare                                                        ║
║  Get-SmbShareAccess -Name ShareName                                  ║
║                                                                      ║
║  # Check service                                                     ║
║  Get-Service -Name LanmanServer                                      ║
║  Test-NetConnection -ComputerName fs01 -Port 445                     ║
║                                                                      ║
║  # File locks                                                        ║
║  Get-SmbOpenFile                                                     ║
║  Close-SmbOpenFile -FileId <id> -Force                               ║
║                                                                      ║
║ ACTIVE DIRECTORY                                                     ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # User issues                                                       ║
║  Get-ADUser -Identity username -Properties *                         ║
║  Unlock-ADAccount -Identity username                                 ║
║  Set-ADAccountPassword -Identity username -Reset                     ║
║                                                                      ║
║  # Account status                                                    ║
║  Get-ADUser -Filter {Enabled -eq $false}                             ║
║  Get-ADUser -Filter * -Properties PasswordExpired                    ║
║                                                                      ║
║ AZURE                                                                ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # VM status                                                         ║
║  Get-AzVM -Status                                                    ║
║  Start-AzVM -Name vmname -ResourceGroupName rg                       ║
║  Restart-AzVM -Name vmname -ResourceGroupName rg                     ║
║                                                                      ║
║  # Database                                                          ║
║  az postgres flexible-server show -n servername                      ║
║  az postgres flexible-server start -n servername                     ║
║                                                                      ║
║ KUBERNETES                                                           ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Pod status                                                        ║
║  kubectl get pods -n awx                                             ║
║  kubectl logs -n awx pod-name                                        ║
║  kubectl describe pod -n awx pod-name                                ║
║                                                                      ║
║  # Service status                                                    ║
║  kubectl get svc -n monitoring                                       ║
║  kubectl port-forward -n monitoring svc/grafana 3000:80              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 🤖 Self-Healing Commands

```
╔══════════════════════════════════════════════════════════════════════╗
║                   SELF-HEALING COMMAND CARD                          ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ VIEW SELF-HEALING EVENTS                                             ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # In Prometheus                                                     ║
║  selfhealing_jobs_total                                              ║
║  selfhealing_jobs_success_total                                      ║
║  rate(selfhealing_jobs_total[1h])                                    ║
║                                                                      ║
║  # In AWX                                                            ║
║  Jobs → Filter by "SelfHeal"                                         ║
║                                                                      ║
║ DISABLE SELF-HEALING (EMERGENCY)                                     ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Temporary (2 hours)                                               ║
║  kubectl exec -n monitoring alertmanager-0 -- amtool silence add \   ║
║    --comment="Maintenance" \                                         ║
║    --duration=2h \                                                   ║
║    self_heal=enabled                                                 ║
║                                                                      ║
║ ENABLE SELF-HEALING                                                  ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Remove silence                                                    ║
║  kubectl exec -n monitoring alertmanager-0 -- amtool silence expire  ║
║                                                                      ║
║ MANUALLY TRIGGER REMEDIATION                                         ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Via AWX                                                           ║
║  curl -X POST https://awx.domain.com/api/v2/job_templates/123/launch/║
║    -H "Authorization: Bearer $TOKEN"                                 ║
║                                                                      ║
║ CHECK WEBHOOK STATUS                                                 ║
║ ─────────────────────────────────────────────────────────────────── ║
║  kubectl logs -n monitoring deployment/webhook-receiver              ║
║  kubectl get svc -n monitoring webhook-receiver                      ║
║                                                                      ║
║ COMMON SCENARIOS                                                     ║
║ ─────────────────────────────────────────────────────────────────── ║
║  DC Service Down      → Auto-restart in ~1 min                       ║
║  Disk Space Low       → Auto-cleanup in ~2 min                       ║
║  Migration Failed     → Auto-retry in ~5 min                         ║
║  DNS Down             → Auto-restart in ~1 min                       ║
║  Network Issue        → Auto-reset in ~2 min                         ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 🛡️ DR Commands

```
╔══════════════════════════════════════════════════════════════════════╗
║                    DISASTER RECOVERY CARD                            ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ VALIDATION                                                           ║
║ ─────────────────────────────────────────────────────────────────── ║
║  .\Validate-DRReadiness.ps1 -Tier Tier2 -GenerateReport              ║
║                                                                      ║
║ BACKUP                                                               ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # Enable Azure Backup                                               ║
║  .\Enable-AzureBackup.ps1 `                                          ║
║    -ResourceGroupName "admt-tier2-rg" `                              ║
║    -VaultName "admt-vault" `                                         ║
║    -BackupTier Standard                                              ║
║                                                                      ║
║  # List recovery points                                              ║
║  az backup recoverypoint list \                                      ║
║    --resource-group admt-tier2-rg \                                  ║
║    --vault-name admt-vault \                                         ║
║    --container-name vmname \                                         ║
║    --item-name vmname                                                ║
║                                                                      ║
║ RESTORE VM                                                           ║
║ ─────────────────────────────────────────────────────────────────── ║
║  az backup restore restore-azurevm \                                 ║
║    --resource-group admt-tier2-rg \                                  ║
║    --vault-name admt-vault \                                         ║
║    --container-name vmname \                                         ║
║    --item-name vmname \                                              ║
║    --rp-name <recovery-point> \                                      ║
║    --target-resource-group admt-tier2-rg \                           ║
║    --restore-mode AlternateLocation \                                ║
║    --target-vm-name vmname-restored                                  ║
║                                                                      ║
║ ZFS SNAPSHOTS                                                        ║
║ ─────────────────────────────────────────────────────────────────── ║
║  # List snapshots                                                    ║
║  ssh root@fs01 "zfs list -t snapshot"                                ║
║                                                                      ║
║  # Rollback to snapshot                                              ║
║  ssh root@fs01 "zfs rollback tank/shares@snapshot-name"              ║
║                                                                      ║
║ AUTOMATED FAILOVER                                                   ║
║ ─────────────────────────────────────────────────────────────────── ║
║  ansible-playbook playbooks/dr/automated-failover.yml \              ║
║    --extra-vars "target_region=westus2 trigger_reason='Outage'"      ║
║                                                                      ║
║ RTO/RPO TARGETS                                                      ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Domain Controllers:  RTO 1h  | RPO 12h                              ║
║  File Servers:        RTO 2h  | RPO 1h                               ║
║  Database:            RTO 30m | RPO 5m                               ║
║  AWX:                 RTO 1h  | RPO Real-time                        ║
║                                                                      ║
║ EMERGENCY CONTACTS                                                   ║
║ ─────────────────────────────────────────────────────────────────── ║
║  Primary On-Call:    _______________   Phone: _____________         ║
║  Azure Support:      1-800-xxx-xxxx                                  ║
║  Runbook Location:   docs/32_DISASTER_RECOVERY_RUNBOOK.md            ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 👥 End User Quick Reference

**Print this for end users!**

```
╔══════════════════════════════════════════════════════════════════════╗
║                    END USER QUICK REFERENCE                          ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║ YOUR NEW LOGIN                                                       ║
║ ─────────────────────────────────────────────────────────────────── ║
║                                                                      ║
║  OLD USERNAME:  OLD-DOMAIN\firstname.lastname                        ║
║  NEW USERNAME:  NEW-DOMAIN\firstname.lastname                        ║
║                                                                      ║
║  PASSWORD:      (same as before)                                     ║
║                                                                      ║
║ ─────────────────────────────────────────────────────────────────── ║
║                                                                      ║
║ BEFORE MIGRATION (Day Before)                                        ║
║ ─────────────────────────────────────────────────────────────────── ║
║  □  Save all work                                                    ║
║  □  Close all applications by 6:00 PM                                ║
║  □  Leave computer ON                                                ║
║  □  Do NOT turn off computer                                         ║
║                                                                      ║
║ AFTER MIGRATION (Next Morning)                                       ║
║ ─────────────────────────────────────────────────────────────────── ║
║  1. Login with:  NEW-DOMAIN\your.username                            ║
║  2. Wait 2-3 minutes for first login                                 ║
║  3. Check your desktop and files                                     ║
║  4. Verify network drives (H:, S:)                                   ║
║  5. Test printer                                                     ║
║                                                                      ║
║ IF YOU HAVE PROBLEMS                                                 ║
║ ─────────────────────────────────────────────────────────────────── ║
║                                                                      ║
║  Can't Login?           → Try restarting computer                    ║
║  Network Drives Missing? → Open File Explorer → Type \\newserver     ║
║  Printer Not Working?   → Settings → Printers → Add printer          ║
║                                                                      ║
║  Still Not Working?     → Contact IT Support                         ║
║                                                                      ║
║ ─────────────────────────────────────────────────────────────────── ║
║                                                                      ║
║ IT SUPPORT CONTACT                                                   ║
║ ─────────────────────────────────────────────────────────────────── ║
║                                                                      ║
║  Phone:  ________________                                            ║
║  Email:  it-support@company.com                                      ║
║  Portal: https://helpdesk.company.com                                ║
║                                                                      ║
║  When calling, have ready:                                           ║
║   - Your name                                                        ║
║   - Your computer name                                               ║
║   - What's not working                                               ║
║   - Any error messages (take photo)                                  ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

## 📝 Printing Instructions

### For Administrators

1. **Print on cardstock** (for durability)
2. **Laminate** (protection from spills)
3. **Keep at desk** (quick reference)
4. **Also save digital copy** (searchable)

### For End Users

1. **Print on regular paper**
2. **Distribute 1 week before migration**
3. **Post on bulletin boards**
4. **Email PDF version**

### Customization

**Fill in the blanks before printing:**
- Contact names and phone numbers
- Migration dates and times
- Domain names (if different)
- Server names (if different)

---

**Version:** 1.0  
**Last Updated:** January 2025  
**Format:** Printable ASCII cards for easy reference

