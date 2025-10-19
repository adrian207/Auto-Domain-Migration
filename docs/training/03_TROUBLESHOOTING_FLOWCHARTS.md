# Troubleshooting Decision Trees

**Version:** 1.0  
**Last Updated:** January 2025  
**Target Audience:** IT Support, System Administrators

---

## 📋 Table of Contents

1. [Login Issues](#login-issues)
2. [Migration Job Failures](#migration-job-failures)
3. [Network Connectivity](#network-connectivity)
4. [File Server Access](#file-server-access)
5. [Self-Healing Failures](#self-healing-failures)
6. [Performance Issues](#performance-issues)

---

## 🔐 Login Issues

```
User Cannot Login
       │
       ├─> Check: Error Message?
       │
       ├─────> "Trust relationship failed"
       │       │
       │       ├─> ACTION: Test trust
       │       │   Command: Test-ComputerSecureChannel -Server source.local
       │       │   
       │       ├─────> Returns False?
       │       │       │
       │       │       └─> ACTION: Reset trust
       │       │           Command: netdom trust target.local /domain:source.local /reset
       │       │           ✅ RESOLVED
       │       │
       │       └─────> Returns True?
       │               │
       │               └─> ESCALATE: Check domain controller logs
       │
       ├─────> "Account is locked out"
       │       │
       │       ├─> ACTION: Check lockout status
       │       │   Command: Get-ADUser -Identity username -Properties LockedOut
       │       │
       │       ├─────> LockedOut = True?
       │       │       │
       │       │       └─> ACTION: Unlock account
       │       │           Command: Unlock-ADAccount -Identity username
       │       │           ✅ RESOLVED
       │       │
       │       └─────> LockedOut = False?
       │               │
       │               └─> ACTION: Check password expiration
       │                   Command: Get-ADUser -Identity username -Properties PasswordExpired
       │
       ├─────> "Password expired"
       │       │
       │       └─> ACTION: Reset password
       │           Command: Set-ADAccountPassword -Identity username -Reset
       │           ✅ RESOLVED
       │
       ├─────> "User profile cannot be loaded"
       │       │
       │       ├─> ACTION: Check profile size
       │       │   Path: C:\Users\username
       │       │
       │       ├─────> Profile > 5GB?
       │       │       │
       │       │       └─> ACTION: Clean profile
       │       │           - Delete temp files
       │       │           - Archive old files
       │       │           - Restart computer
       │       │           ✅ RESOLVED
       │       │
       │       └─────> Profile corrupt?
       │               │
       │               └─> ACTION: Rename profile folder
       │                   1. Login as local admin
       │                   2. Rename C:\Users\username to username.old
       │                   3. User logs in (creates new profile)
       │                   4. Copy data from username.old
       │                   ✅ RESOLVED
       │
       └─────> "Cannot contact domain controller"
               │
               ├─> ACTION: Test DC connectivity
               │   Command: Test-NetConnection -ComputerName dc01.target.local -Port 389
               │
               ├─────> Connection failed?
               │       │
               │       ├─> ACTION: Check network
               │       │   - Verify IP address
               │       │   - Check DNS settings
               │       │   - Ping gateway
               │       │
               │       └─> ESCALATE: Network team
               │
               └─────> Connection success?
                       │
                       └─> ACTION: Check DNS
                           Command: nslookup dc01.target.local
                           - Fix DNS if incorrect
                           - Restart DNS Client service
                           ✅ RESOLVED
```

---

## 🔄 Migration Job Failures

```
Migration Job Failed
       │
       ├─> Check: Job Type?
       │
       ├─────> User Migration Failed
       │       │
       │       ├─> Check: Error Message?
       │       │
       │       ├─────> "Access denied"
       │       │       │
       │       │       └─> ACTION: Verify service account permissions
       │       │           - Check Domain Admin membership
       │       │           - Verify delegated permissions
       │       │           - Check OU permissions
       │       │           ✅ RESOLVED
       │       │
       │       ├─────> "User already exists"
       │       │       │
       │       │       └─> ACTION: Check target domain
       │       │           Command: Get-ADUser -Filter "Name -eq 'username'" -Server target.local
       │       │           - Delete duplicate if test account
       │       │           - Skip if prod account migrated previously
       │       │           ✅ RESOLVED
       │       │
       │       └─────> "SID History failed"
       │               │
       │               ├─> ACTION: Check SID filtering
       │               │   Command: netdom trust target.local /domain:source.local /quarantine:no
       │               │
       │               └─> ACTION: Verify auditing enabled
       │                   - Source DC: Audit policy
       │                   - Target DC: Audit policy
       │                   ✅ RESOLVED
       │
       ├─────> Computer Migration Failed
       │       │
       │       ├─> Check: Error Message?
       │       │
       │       ├─────> "Computer cannot be contacted"
       │       │       │
       │       │       ├─> ACTION: Verify computer online
       │       │       │   Command: Test-NetConnection -ComputerName pc-name
       │       │       │
       │       │       ├─────> Computer offline?
       │       │       │       │
       │       │       │       └─> ACTION: Schedule for next batch
       │       │       │           ✅ RESOLVED (retry later)
       │       │       │
       │       │       └─────> Computer online?
       │       │               │
       │       │               └─> ACTION: Check firewall
       │       │                   - Allow RPC (135)
       │       │                   - Allow NetBIOS (137-139)
       │       │                   - Allow SMB (445)
       │       │                   ✅ RESOLVED
       │       │
       │       ├─────> "User logged on"
       │       │       │
       │       │       └─> ACTION: Wait for logoff
       │       │           - Contact user
       │       │           - Schedule for off-hours
       │       │           ✅ RESOLVED (retry later)
       │       │
       │       └─────> "Failed to join domain"
       │               │
       │               ├─> ACTION: Check OU permissions
       │               │   - Verify target OU exists
       │               │   - Check create computer object permission
       │               │
       │               └─> ACTION: Manual join
       │                   1. Unjoin from source domain
       │                   2. Join to target domain
       │                   3. Update ADMT tracking
       │                   ✅ RESOLVED
       │
       └─────> Group Migration Failed
               │
               ├─> Check: Error Message?
               │
               ├─────> "Group already exists"
               │       │
               │       └─> ACTION: Check group type
               │           - If same SID: Skip (already migrated)
               │           - If different: Rename or merge
               │           ✅ RESOLVED
               │
               └─────> "Cannot add members"
                       │
                       └─> ACTION: Check member migration status
                           Command: Get-ADGroupMember -Identity groupname
                           - Ensure all members migrated first
                           - Retry group migration
                           ✅ RESOLVED
```

---

## 🌐 Network Connectivity

```
Network Issue Detected
       │
       ├─> Check: What can't connect?
       │
       ├─────> Cannot reach Domain Controller
       │       │
       │       ├─> ACTION: Test basic connectivity
       │       │   Command: Test-NetConnection -ComputerName dc01.target.local
       │       │
       │       ├─────> Ping fails?
       │       │       │
       │       │       ├─> ACTION: Check DC status
       │       │       │   Command: Get-AzVM -Status -Name dc01-target
       │       │       │
       │       │       ├─────> VM stopped?
       │       │       │       │
       │       │       │       └─> ACTION: Start VM
       │       │       │           Command: Start-AzVM -Name dc01-target
       │       │       │           ⏱️ Wait 2-3 minutes
       │       │       │           ✅ RESOLVED
       │       │       │
       │       │       └─────> VM running?
       │       │               │
       │       │               ├─> ACTION: Check NSG rules
       │       │               │   - Verify port 389 (LDAP) allowed
       │       │               │   - Verify port 53 (DNS) allowed
       │       │               │   - Check source IP allowed
       │       │               │
       │       │               └─> ESCALATE: Azure networking team
       │       │
       │       └─────> Ping succeeds but service fails?
               │               │
               │               └─> ACTION: Check AD DS service
               │                   Command: Get-Service -Name NTDS -ComputerName dc01
               │                   - If stopped: Start-Service NTDS
               │                   ✅ RESOLVED
               │
       ├─────> Cannot reach File Server
       │       │
       │       ├─> ACTION: Test SMB connectivity
       │       │   Command: Test-NetConnection -ComputerName fs01.target.local -Port 445
       │       │
       │       ├─────> Port 445 blocked?
       │       │       │
       │       │       └─> ACTION: Check firewall/NSG
       │       │           - Allow SMB (445)
       │       │           - Check Windows Firewall on file server
               │           ✅ RESOLVED
       │       │
       │       └─────> Port 445 open but shares inaccessible?
       │               │
       │               └─> ACTION: Check SMB service
       │                   Command: Get-Service -Name LanmanServer
       │                   - If stopped: Start-Service LanmanServer
       │                   ✅ RESOLVED
       │
       └─────> Database connection fails
               │
               ├─> ACTION: Check PostgreSQL status
               │   Command: az postgres flexible-server show -n admt-postgres
               │
               ├─────> Server stopped?
               │       │
               │       └─> ACTION: Start server
               │           Command: az postgres flexible-server start -n admt-postgres
               │           ✅ RESOLVED
               │
               └─────> Server running?
                       │
                       ├─> ACTION: Test connection
                       │   Command: psql -h server.postgres.database.azure.com -U admin -d awx
                       │
                       ├─────> Connection refused?
                       │       │
                       │       └─> ACTION: Check firewall rules
                       │           - Add client IP to allowed list
                       │           ✅ RESOLVED
                       │
                       └─────> Authentication failed?
                               │
                               └─> ACTION: Check credentials
                                   - Verify username/password
                                   - Check connection string
                                   - Reset password if needed
                                   ✅ RESOLVED
```

---

## 📁 File Server Access

```
Cannot Access File Share
       │
       ├─> Check: What's the error?
       │
       ├─────> "Network path not found"
       │       │
       │       ├─> ACTION: Verify server name
       │       │   Command: Resolve-DnsName fs01.target.local
       │       │
       │       ├─────> DNS resolution fails?
       │       │       │
       │       │       └─> ACTION: Check DNS
       │       │           - Verify DNS server settings
       │       │           - Flush DNS cache: ipconfig /flushdns
       │       │           - Register DNS: ipconfig /registerdns
       │       │           ✅ RESOLVED
       │       │
       │       └─────> DNS OK but still can't reach?
       │               │
       │               └─> ACTION: Check file server status
       │                   Command: Test-NetConnection -ComputerName fs01.target.local -Port 445
       │                   - See "Network Connectivity" tree
       │
       ├─────> "Access is denied"
       │       │
       │       ├─> ACTION: Check permissions
       │       │   Command: Get-SmbShareAccess -Name ShareName
       │       │
       │       ├─────> User not in ACL?
       │       │       │
       │       │       └─> ACTION: Add permission
       │       │           Command: Grant-SmbShareAccess -Name Share -AccountName user -AccessRight Full
       │       │           ✅ RESOLVED
       │       │
       │       └─────> User in ACL?
       │               │
       │               ├─> ACTION: Check NTFS permissions
       │               │   Command: Get-Acl \\fs01\share | Format-List
       │               │
       │               └─> ACTION: Verify group membership
       │                   Command: Get-ADPrincipalGroupMembership username
       │                   - User may need to logout/login
       │                   ✅ RESOLVED
       │
       ├─────> "The specified network name is no longer available"
       │       │
       │       └─> ACTION: Check SMB signing
       │           - Source: RequireSecuritySignature = disabled
       │           - Target: EnableSecuritySignature = enabled
       │           - Match settings between source/target
       │           ✅ RESOLVED
       │
       └─────> "The file cannot be accessed by the system"
               │
               ├─> ACTION: Check file locks
               │   Command: Get-SmbOpenFile | Where-Object Path -like "*filename*"
               │
               ├─────> File locked?
               │       │
               │       └─> ACTION: Close open file
               │           Command: Close-SmbOpenFile -FileId <id> -Force
               │           ✅ RESOLVED
               │
               └─────> Disk full?
                       │
                       └─> ACTION: Check disk space
                           Command: Get-PSDrive
                           - Free up space if < 10%
                           - Trigger self-healing cleanup
                           ✅ RESOLVED
```

---

## 🤖 Self-Healing Failures

```
Self-Healing Not Working
       │
       ├─> Check: What's failing?
       │
       ├─────> Alert not triggering AWX job
       │       │
       │       ├─> ACTION: Check Alertmanager
       │       │   Command: kubectl logs -n monitoring alertmanager-0
       │       │
       │       ├─────> Webhook errors in logs?
       │       │       │
       │       │       └─> ACTION: Check webhook receiver
       │       │           Command: kubectl logs -n monitoring deployment/webhook-receiver
               │           - Verify webhook URL
               │           - Check authentication token
               │           ✅ RESOLVED
       │       │
       │       └─────> No errors but job not starting?
       │               │
       │               └─> ACTION: Test webhook manually
       │                   curl -X POST https://webhook.domain.com/alertmanager \
       │                        -H "Authorization: Bearer $TOKEN" \
       │                        -d '{"alerts":[{"labels":{"self_heal":"enabled"}}]}'
       │                   - Check AWX for job
       │                   ✅ RESOLVED
       │
       ├─────> AWX job starts but fails immediately
       │       │
       │       ├─> ACTION: Check job output
       │       │   - Login to AWX
       │       │   - Jobs → View failed job
       │       │   - Read error message
       │       │
       │       ├─────> "Credentials invalid"
       │       │       │
       │       │       └─> ACTION: Update credentials
       │       │           - AWX → Credentials
       │       │           - Update password/token
       │       │           - Re-run job
       │       │           ✅ RESOLVED
       │       │
       │       ├─────> "Inventory sync failed"
       │       │       │
       │       │       └─> ACTION: Check inventory source
       │       │           - AWX → Inventories → Sources
       │       │           - Update source configuration
       │       │           - Sync inventory
       │       │           ✅ RESOLVED
       │       │
       │       └─────> "Playbook not found"
       │               │
       │               └─> ACTION: Update project
       │                   - AWX → Projects → Update
       │                   - Verify playbook path
       │                   ✅ RESOLVED
       │
       └─────> AWX job runs but doesn't fix issue
               │
               ├─> ACTION: Check playbook logic
               │   - Review Ansible playbook
               │   - Check task conditions
               │   - Verify target host
               │
               ├─> ACTION: Run manually with verbose
               │   ansible-playbook -vvv playbook.yml
               │   - Review detailed output
               │   - Identify failing task
               │
               └─> ACTION: Check permissions
                   - Verify service account has required permissions
                   - Check sudo/privilege escalation
                   ✅ RESOLVED (after fixing playbook)
```

---

## ⚡ Performance Issues

```
Performance Degradation Detected
       │
       ├─> Check: What's slow?
       │
       ├─────> Migration job slow (> 2x expected)
       │       │
       │       ├─> ACTION: Check CPU usage
       │       │   Command: Get-Counter '\Processor(_Total)\% Processor Time'
       │       │
       │       ├─────> CPU > 90%?
       │       │       │
       │       │       ├─> ACTION: Identify process
       │       │       │   Command: Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
       │       │       │
       │       │       └─> ACTION: Scale up or wait
       │       │           - If ADMT: Wait (normal during large migration)
       │       │           - If other process: Stop if safe
       │       │           ✅ RESOLVED
       │       │
       │       └─────> CPU normal?
       │               │
       │               └─> ACTION: Check network throughput
       │                   Command: Test-NetConnection -TraceRoute dc01.target.local
       │                   - Check latency
       │                   - Look for packet loss
       │                   - ESCALATE if network issue
       │
       ├─────> File transfer slow (< 10 MB/s)
       │       │
       │       ├─> ACTION: Check bandwidth
       │       │   Command: Test-NetConnection -ComputerName fs01 -DiagnoseRouting
       │       │
       │       ├─> ACTION: Check disk I/O
       │       │   Command: Get-Counter '\PhysicalDisk(_Total)\% Disk Time'
       │       │
       │       ├─────> Disk I/O > 80%?
       │       │       │
       │       │       └─> ACTION: Check for other processes
       │       │           - Antivirus scan running?
       │       │           - Backup job running?
       │       │           - Wait for completion
       │       │           ✅ RESOLVED
       │       │
       │       └─────> Network saturated?
       │               │
       │               └─> ACTION: Throttle transfer or schedule off-hours
       │                   ✅ RESOLVED
       │
       └─────> Database queries slow
               │
               ├─> ACTION: Check database CPU
               │   Azure Portal → PostgreSQL → Metrics → CPU percent
               │
               ├─────> CPU > 80%?
               │       │
               │       ├─> ACTION: Scale up database tier
               │       │   Command: az postgres flexible-server update --sku-name Standard_D4s_v3
               │       │   ✅ RESOLVED
               │       │
               │       └─> ACTION: Identify slow queries
               │           - Enable query store
               │           - Review slow queries
               │           - Add indexes if needed
               │
               └─────> CPU normal?
                       │
                       └─> ACTION: Check connections
                           Command: SELECT count(*) FROM pg_stat_activity;
                           - If > max_connections: Scale up or kill idle connections
                           ✅ RESOLVED
```

---

## 📝 Escalation Matrix

| Issue Type | L1 Actions | Escalate To | SLA |
|------------|-----------|-------------|-----|
| **Login** | Reset password, unlock account | L2 Admin | 30 min |
| **Migration** | Retry job, check logs | Migration Engineer | 1 hour |
| **Network** | Check basic connectivity | Network Team | 2 hours |
| **Performance** | Check resources, restart services | L2 Admin | 4 hours |
| **Self-Healing** | Check logs, manual remediation | DevOps Team | 2 hours |
| **Disaster** | Follow runbook | Manager + Azure Support | Immediate |

---

## ✅ Best Practices

1. **Always check logs first** - Most issues show clear errors
2. **Test connectivity before escalating** - Rule out network issues
3. **Document everything** - Screenshot errors, note timestamps
4. **Follow the tree** - Don't skip steps
5. **Know when to escalate** - Don't waste time if beyond your expertise

---

**Version:** 1.0  
**Last Updated:** January 2025  
**Feedback:** Submit improvements via GitHub Issues

