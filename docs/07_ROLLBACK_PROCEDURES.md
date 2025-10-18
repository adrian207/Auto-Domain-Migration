# Rollback Procedures

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Emergency procedures to revert migrations when failures exceed acceptable thresholds or critical issues are discovered post-migration.

**Decision Authority:** Migration Lead + CAB Chair (or designated backup)

---

## Rollback Decision Matrix

| Scenario | Severity | Rollback Required? | Timeframe |
|----------|----------|-------------------|-----------|
| Single workstation USMT failure | LOW | No – fix individually | N/A |
| <5% hosts failed in wave | MEDIUM | No – remediate failed hosts | 24-48 hours |
| 5-15% hosts failed in wave | HIGH | Evaluate – may pause and fix | 2-4 hours decision |
| >15% hosts failed in wave | CRITICAL | Yes – immediate rollback | <1 hour decision |
| Critical app down >1 hour | CRITICAL | Yes – rollback affected servers | Immediate |
| Data loss detected | CRITICAL | Yes – full rollback | Immediate |
| User access completely broken | CRITICAL | Yes – rollback all users/machines | Immediate |
| Domain trust broken | CRITICAL | Yes – full rollback + escalation | Immediate |

---

## Pre-Rollback Checklist

Before executing rollback, verify:

- [ ] **Root cause identified** – Ensure rollback will fix the issue (not a separate problem)
- [ ] **Backup verification** – Confirm rollback artifacts exist and are accessible
  - [ ] `state/host/<hostname>/rollback.json` present
  - [ ] `backups/acls/<hostname>_<timestamp>.txt` present
  - [ ] `backups/services/<hostname>_<timestamp>.json` present
  - [ ] USMT stores accessible at `\\statestore\<hostname>\` or S3 path
- [ ] **CAB notification** – Inform stakeholders of rollback decision
- [ ] **Change window confirmed** – Rollback within original maintenance window if possible
- [ ] **Team availability** – Minimum 3 engineers on call (1 lead, 2 executors)

---

## Rollback Procedures

### 1. Identity Rollback (Users/Groups)

**Scope:** Revert users and groups created in target domain/Entra

**Impact:** Newly migrated users lose access to target resources; must re-authenticate to source

**Time:** 30-60 minutes for 500 users

---

#### 1.1 Disable Target Users (AD)

**Playbook:** `playbooks/99_rollback_identity.yml`

```yaml
---
- name: Rollback Identity - Disable Target Users
  hosts: target_dc
  gather_facts: no
  vars:
    rollback_filter: "extensionAttribute1 -eq 'MIGRATED_WAVE{{ wave_id }}'"

  tasks:
    - name: Get migrated users
      microsoft.ad.user:
        identity: "*"
        filter: "{{ rollback_filter }}"
        properties: samAccountName, distinguishedName
      register: migrated_users

    - name: Disable target users
      microsoft.ad.user:
        identity: "{{ item.samAccountName }}"
        enabled: no
      loop: "{{ migrated_users.objects }}"

    - name: Remove from target groups
      microsoft.ad.group_member:
        identity: "{{ group_map[item.group] }}"
        members:
          - name: "{{ item.user }}"
        state: absent
      loop: "{{ group_memberships }}"
      when: group_map[item.group] is defined
```

**Manual Steps (if playbook fails):**
```powershell
# On target DC
$wave = "wave1"
Get-ADUser -Filter {extensionAttribute1 -eq "MIGRATED_$wave"} | Disable-ADAccount

# Remove from all groups except Domain Users
Get-ADUser -Filter {extensionAttribute1 -eq "MIGRATED_$wave"} | ForEach-Object {
    $user = $_
    Get-ADPrincipalGroupMembership $user | Where-Object {$_.Name -ne "Domain Users"} | ForEach-Object {
        Remove-ADGroupMember -Identity $_ -Members $user -Confirm:$false
    }
}
```

---

#### 1.2 Re-Enable Source Users (AD)

**If users were disabled in source during migration:**

```powershell
# On source DC
$wave = "wave1"
Get-ADUser -Filter {extensionAttribute2 -eq "PENDING_MIGRATION_$wave"} | Enable-ADAccount
```

---

#### 1.3 Rollback Entra Users (Cloud-Only)

**For Graph API provisioned users:**

```bash
# Use Graph API to disable or delete
ansible-playbook -i inventories/tier2_medium/hosts.ini playbooks/99_rollback_entra_users.yml --extra-vars "wave=wave1 action=disable"
```

**Playbook snippet:**
```yaml
- name: Disable Entra users
  uri:
    url: https://graph.microsoft.com/v1.0/users/{{ item.userPrincipalName }}
    method: PATCH
    headers:
      Authorization: "Bearer {{ graph_token }}"
    body:
      accountEnabled: false
    body_format: json
    status_code: [200, 204]
  loop: "{{ migrated_users }}"
```

**WARNING:** Deleting Entra users is **irreversible**. Use `disable` unless certain.

---

### 2. Workstation Rollback

**Scope:** Rejoin source domain, optionally restore USMT from old profile

**Impact:** User must re-login; any data saved post-migration on workstation will be lost unless backed up separately

**Time:** 30-45 minutes per workstation (can parallelize up to concurrency limits)

---

#### 2.1 Automated Rollback (Preferred)

**Playbook:** `playbooks/99_rollback_machine.yml`

```yaml
---
- name: Rollback Workstation to Source Domain
  hosts: "{{ target_hosts }}"
  gather_facts: no
  serial: 50  # Tune based on runner capacity

  tasks:
    - name: Load rollback state
      slurp:
        src: "{{ state_dir }}/host/{{ inventory_hostname }}/rollback.json"
      register: rollback_state_raw
      delegate_to: localhost

    - name: Parse rollback state
      set_fact:
        rollback_state: "{{ rollback_state_raw.content | b64decode | from_json }}"

    - name: Verify rollback state exists
      fail:
        msg: "No rollback state found for {{ inventory_hostname }}"
      when: rollback_state is not defined or rollback_state.original_domain is not defined

    - name: Create break-glass local admin (if not exists)
      win_user:
        name: LocalBreakGlass
        password: "{{ breakglass_password }}"
        groups:
          - Administrators
        state: present
      failed_when: false

    - name: Disjoin from target domain
      win_domain_membership:
        state: workgroup
        workgroup_name: ROLLBACK
        domain_admin_user: "{{ target_admin_user }}"
        domain_admin_password: "{{ vault_target_admin_pass }}"
      register: disjoin_result

    - name: Reboot after disjoin
      win_reboot:
        reboot_timeout: 600
      when: disjoin_result.reboot_required

    - name: Rejoin source domain
      win_domain_membership:
        dns_domain_name: "{{ rollback_state.original_domain }}"
        domain_admin_user: "{{ source_admin_user }}"
        domain_admin_password: "{{ vault_source_admin_pass }}"
        state: domain
      register: rejoin_result

    - name: Reboot after rejoin
      win_reboot:
        reboot_timeout: 600
      when: rejoin_result.reboot_required

    - name: Restore ACLs from backup
      win_shell: |
        icacls C:\Data /restore "{{ rollback_state.acl_backup }}"
      when: rollback_state.acl_backup is defined
      failed_when: false

    - name: Mark rollback complete
      copy:
        dest: "{{ state_dir }}/host/{{ inventory_hostname }}/progress.json"
        content: |
          {
            "phase": "rolled_back",
            "timestamp": "{{ ansible_date_time.iso8601 }}",
            "original_domain": "{{ rollback_state.original_domain }}"
          }
      delegate_to: localhost
```

**Execution:**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/99_rollback_machine.yml \
  --limit wave1_workstations \
  --forks 50 \
  --extra-vars "state_dir=state vault_source_admin_pass='{{ vault_lookup }}'"
```

---

#### 2.2 Manual Rollback (If Automation Fails)

**Per-workstation steps:**

1. **Local login** (using break-glass account or safe mode)
2. **Disjoin target domain:**
   ```powershell
   Remove-Computer -UnjoinDomainCredential (Get-Credential) -WorkgroupName ROLLBACK -Force -Restart
   ```
3. **After reboot, rejoin source domain:**
   ```powershell
   Add-Computer -DomainName source.example.com -Credential (Get-Credential) -Restart
   ```
4. **Restore user profile (optional):**
   ```powershell
   # If USMT store still available
   C:\USMT\loadstate.exe \\statestore\<hostname>_PRE_MIGRATION /v:13 /c
   ```

---

### 3. Server Rollback

**Scope:** Rejoin source domain, restore service principals, ACLs, SPNs

**Impact:** Services will restart; brief downtime (5-15 minutes per server)

**Time:** 45-90 minutes per server

---

#### 3.1 Automated Server Rollback

**Playbook:** `playbooks/99_rollback_server.yml` (extends `99_rollback_machine.yml`)

```yaml
---
- name: Rollback Server to Source Domain
  hosts: "{{ target_servers }}"
  gather_facts: no
  serial: 10

  tasks:
    - include_tasks: 99_rollback_machine.yml

    - name: Load service backup
      slurp:
        src: "{{ backup_dir }}/services_{{ inventory_hostname }}_{{ rollback_state.timestamp }}.json"
      register: service_backup_raw
      delegate_to: localhost

    - name: Parse service backup
      set_fact:
        service_backup: "{{ service_backup_raw.content | b64decode | from_json }}"

    - name: Stop services before reconfiguration
      win_service:
        name: "{{ item.name }}"
        state: stopped
      loop: "{{ service_backup.services | selectattr('start_mode', 'equalto', 'auto') }}"
      failed_when: false

    - name: Restore service principals
      win_service:
        name: "{{ item.name }}"
        username: "{{ item.username }}"
        password: "{{ lookup('community.hashi_vault.hashi_vault', 'secret/data/migration/service_passwords/' + item.username).password }}"
      loop: "{{ service_backup.services | selectattr('username', 'defined') }}"
      when: item.username is search(target_domain)
      failed_when: false

    - name: Start services
      win_service:
        name: "{{ item.name }}"
        state: started
      loop: "{{ service_backup.services | selectattr('start_mode', 'equalto', 'auto') }}"
      failed_when: false

    - name: Remove SPNs from target accounts
      win_shell: |
        setspn -D {{ item }} {{ target_domain }}\{{ service_account }}
      loop: "{{ registered_spns }}"
      failed_when: false

    - name: Re-register SPNs on source accounts
      win_shell: |
        setspn -S {{ item }} {{ source_domain }}\{{ service_account }}
      loop: "{{ registered_spns }}"
      failed_when: false

    - name: Restore scheduled tasks
      # ... similar to services ...

    - name: Validate services running
      win_service_info:
        name: "{{ item.name }}"
      loop: "{{ service_backup.services | selectattr('start_mode', 'equalto', 'auto') }}"
      register: service_status
      failed_when: service_status.services[0].state != 'running'
```

---

#### 3.2 Manual Server Rollback

**Critical servers requiring hands-on:**

1. **Notify app owners** – Coordinate downtime
2. **Stop critical services:**
   ```powershell
   Stop-Service <ServiceName>
   ```
3. **Rejoin source domain** (same as workstation steps)
4. **Restore service accounts:**
   ```powershell
   sc.exe config <ServiceName> obj= "SOURCE\ServiceAccount" password= "password"
   ```
5. **Restore SPNs:**
   ```powershell
   setspn -S HTTP/appserver.source.com SOURCE\AppServiceAccount
   ```
6. **Restore ACLs:**
   ```powershell
   icacls C:\AppData /restore C:\Backup\acls_backup.txt
   ```
7. **Start services and validate:**
   ```powershell
   Start-Service <ServiceName>
   Test-NetConnection -ComputerName appserver.source.com -Port 443
   ```

---

### 4. Linux Rollback

**Scope:** Rejoin source domain (sssd), restore file ownerships

**Time:** 15-30 minutes per server

---

#### 4.1 Domain-Joined Linux Rollback

**Playbook:** `playbooks/99_rollback_linux.yml`

```yaml
---
- name: Rollback Linux Domain Membership
  hosts: "{{ target_linux }}"
  become: yes

  tasks:
    - name: Leave target domain
      command: realm leave {{ target_domain }}
      register: leave_result
      failed_when: false

    - name: Clear sssd cache
      command: sss_cache -E

    - name: Rejoin source domain
      command: realm join {{ source_domain }} -U {{ source_admin_user }}
      environment:
        REALM_PASSWORD: "{{ vault_source_admin_pass }}"

    - name: Restart sssd
      service:
        name: sssd
        state: restarted

    - name: Validate domain join
      command: getent passwd {{ test_user }}@{{ source_domain }}
      register: getent_check
      failed_when: getent_check.rc != 0

    - name: Restore file ownerships (if mapped)
      # This is complex – requires original UID/GID map
      # May need to restore from backup instead
      debug:
        msg: "Manual file ownership restoration required if UIDs changed"
```

---

#### 4.2 Manual Linux Rollback

```bash
# As root on Linux server
realm leave target.example.com
sss_cache -E
realm join source.example.com -U admin
systemctl restart sssd

# Validate
getent passwd testuser@source.example.com
id testuser@source.example.com

# Restore file ownerships (if needed)
# Requires old->new UID mapping file
# find /data -uid <target_uid> -exec chown <source_uid> {} \;
```

---

### 5. Rollback Validation

After rollback execution, validate:

---

#### 5.1 User Access

**Test login to source domain:**
```bash
# From pilot workstation
mstsc /v:sourceserver.source.com
# Login with source\testuser
```

**Check group memberships restored:**
```powershell
Get-ADPrincipalGroupMembership testuser | Select-Object Name
# Should match pre-migration groups
```

---

#### 5.2 Application Access

**Test critical apps:**
- [ ] File share access: `\\fileserver\share`
- [ ] SQL Server: `sqlcmd -S sqlserver -U testuser`
- [ ] Web apps: Browse to intranet portal, verify login
- [ ] Email (if integrated): Open Outlook, send test email

---

#### 5.3 Service Health

**Verify services running:**
```powershell
Get-Service | Where-Object {$_.StartType -eq "Automatic" -and $_.Status -ne "Running"}
# Should return empty
```

**Check SPNs registered:**
```powershell
setspn -L SOURCE\ServiceAccount
# Verify all expected SPNs present
```

---

### 6. Post-Rollback Actions

Once rollback validated:

1. **Update status dashboard**
   ```sql
   UPDATE mig.run SET status='rolled_back', finished_at=now() WHERE id='{{ run_id }}';
   ```

2. **Notify stakeholders**
   - Slack: "#migration-ops: Wave {{ wave_id }} rolled back successfully. Users restored to source domain."
   - Email CAB: "Rollback complete. Root cause analysis in progress."

3. **Preserve evidence**
   ```bash
   # Archive rollback logs
   tar -czf rollback_{{ wave_id }}_{{ date }}.tar.gz \
     state/run/{{ run_id }}/ \
     artifacts/{{ wave_id }}/ \
     /var/log/ansible.log
   aws s3 cp rollback_{{ wave_id }}_{{ date }}.tar.gz s3://migration-incidents/
   ```

4. **Root cause analysis**
   - Convene incident review within 24 hours
   - Document findings in `docs/incidents/{{ wave_id }}_rollback_{{ date }}.md`
   - Update playbooks/roles based on lessons learned

5. **Clean up target artifacts**
   - Disable (don't delete) target users/groups
   - Preserve USMT stores for 90 days (may need for forensics)
   - Document cleanup date in change log

---

## Rollback Time Estimates

| Scope | Automated | Manual | Total (with validation) |
|-------|-----------|--------|-------------------------|
| 100 users | 15 min | 60 min | 20 min / 75 min |
| 50 workstations | 40 min | 150 min | 60 min / 180 min |
| 10 servers | 90 min | 240 min | 120 min / 300 min |
| **Full wave (100U+50WS+10S)** | **2.5 hours** | **8+ hours** | **3-4 hours / 10+ hours** |

**Key Takeaway:** Automated rollback is **3-4x faster** than manual and has **lower error rate**. Test rollback playbooks in pilot!

---

## Rollback Failure Scenarios

### Scenario: Rollback Playbook Fails Mid-Execution

**Symptoms:** Hosts stuck in workgroup, some rejoined source, some still in target

**Recovery:**
1. Generate host status report:
   ```bash
   ansible -i inventories/tier2_medium/hosts.ini all -m win_shell -a "Get-WmiObject -Class Win32_ComputerSystem | Select-Object Domain"
   ```
2. Re-run rollback playbook with `--limit` to subset:
   ```bash
   ansible-playbook playbooks/99_rollback_machine.yml --limit "wave1_workstations:&WORKGROUP"
   ```
3. If persistent failures, switch to manual rollback for affected hosts

---

### Scenario: USMT Store Deleted or Corrupted

**Symptoms:** Cannot restore user profiles after rollback

**Recovery:**
1. **If Volume Shadow Copy enabled:**
   ```powershell
   vssadmin list shadows /for=C:
   mklink /D C:\USMT_Restore \\?\GLOBALROOT\Device\HarddiskVolumeShadowCopy1\StateStore\
   ```
2. **If no backup:** User profile lost; re-create from roaming profile or OneDrive

**Prevention:** Enable versioning on object storage (S3 versioning, MinIO bucket versioning)

---

### Scenario: Domain Trust Broken

**Symptoms:** `The trust relationship between this workstation and the primary domain failed`

**Recovery:**
1. **Reset computer account:**
   ```powershell
   # On DC
   Reset-ComputerMachinePassword -Server DC01 -Credential (Get-Credential)
   ```
2. **Or re-join domain:**
   ```powershell
   # On workstation (as local admin)
   Remove-Computer -UnjoinDomaincredential (Get-Credential) -Force -Restart
   Add-Computer -DomainName source.com -Credential (Get-Credential) -Restart
   ```

---

## Testing Rollback Procedures

**Frequency:** Test rollback on 2-3 pilot hosts **before each production wave**

**Test Playbook:**
```bash
# Test forward migration + rollback cycle
ansible-playbook playbooks/20_machine_move.yml --limit rollback_test_hosts
# Wait 10 minutes
ansible-playbook playbooks/99_rollback_machine.yml --limit rollback_test_hosts
# Validate
ansible-playbook playbooks/40_validate.yml --limit rollback_test_hosts
```

**Success Criteria:**
- [ ] Rollback completes in <45 min for 3 workstations
- [ ] All test users can log in to source domain
- [ ] All services running post-rollback
- [ ] No data loss (files in home directory intact)

---

## Rollback Authority & Approvals

**Tier 1 (Minor Issues):**
- Authority: Migration Lead
- Approval: Email to CAB (post-facto notification)
- Example: Roll back 3 failed workstations

**Tier 2 (Significant Issues):**
- Authority: Migration Lead + IT Director
- Approval: CAB Chair (phone/email)
- Example: Roll back 50 workstations due to >10% failure rate

**Tier 3 (Critical Issues):**
- Authority: CIO or designee
- Approval: Emergency CAB (conference call within 1 hour)
- Example: Roll back entire wave (100+ hosts) due to critical app outage

**Documentation:** All rollback decisions logged in `docs/incidents/` and PostgreSQL `mig.run` table.

---

## Summary

Rollback procedures are a **critical safety mechanism** but should be:
- **Tested regularly** (every pilot, every 5th wave)
- **Automated where possible** (playbook-driven)
- **Time-boxed** (decision within 1 hour of issue detection)
- **Well-documented** (runbook, incident logs)

**Golden Rule:** If in doubt about whether to roll back, **pause the wave and assess**. Do not proceed with additional hosts until root cause is understood.

---

**For detailed troubleshooting steps, see `docs/06_RUNBOOK_TROUBLESHOOTING.md`.**

**For operational procedures, see `docs/05_RUNBOOK_OPERATIONS.md`.**

---

**END OF DOCUMENT**

