# Entra Connect Synchronization Strategy

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Define anchor attributes, sync timing, conflict resolution, and validation procedures for Entra Connect (Azure AD Connect) synchronization during hybrid identity migrations.

**Applies To:** Pathway 4.1 (On-Prem → Separate Cloud Tenant), Pathway 3.4 (On-Prem → Cloud)

---

## 1) Anchor Attribute Strategy

### 1.1 What is an Anchor (Source Anchor / Immutable ID)?

The **anchor attribute** uniquely identifies a user between on-premises AD and Entra ID. Once set, it **cannot be changed** without deleting and recreating the Entra user (data loss).

**Entra Connect uses this attribute to:**
- Match on-prem users to Entra users during sync
- Prevent duplicate user creation
- Maintain consistency across sync cycles

---

### 1.2 Anchor Options

| Attribute | Pros | Cons | Recommended? |
|-----------|------|------|--------------|
| **ms-DS-ConsistencyGuid** | Globally unique, immutable, auto-populated by Entra Connect | Requires Entra Connect Cloud Sync or AADConnect v1.1.524+ | ✅ **YES** (default) |
| **objectGUID** | Globally unique, immutable, exists on all AD objects | Cannot be changed if migration requires object GUID swap | ✅ YES (if ms-DS-ConsistencyGuid unavailable) |
| **employeeID** | Business-meaningful, portable across forests | Not enforced unique, may have collisions, requires HR system accuracy | ⚠️ CONDITIONAL (only if HR is source of truth) |
| **mail** | User-friendly, matches Exchange mailbox | High collision risk (shared mailboxes, aliases), can change | ❌ NO (use only for soft-match in Exchange migrations) |
| **userPrincipalName** | Built-in, email-like | Can change (marriage, typo fixes), not suitable as anchor | ❌ NO |

---

### 1.3 Recommended Strategy: ms-DS-ConsistencyGuid

**Why:** Globally unique, immutable, designed for Entra Connect.

**Implementation:**

**Step 1: Pre-populate ms-DS-ConsistencyGuid from objectGUID**

```powershell
# On source DC (before migration)
# This ensures users have a consistent anchor even if moved to new forest
Get-ADUser -Filter {ms-DS-ConsistencyGuid -notlike "*"} -Properties objectGUID,ms-DS-ConsistencyGuid | ForEach-Object {
    $guid = [System.Convert]::ToBase64String($_.objectGUID.ToByteArray())
    Set-ADUser $_ -Replace @{"ms-DS-ConsistencyGuid"=$guid}
}
```

**Step 2: Provision users in target AD with same ms-DS-ConsistencyGuid**

```yaml
# In ad_provision role (roles/ad_provision/tasks/main.yml)
- name: Create user in target AD with anchor
  microsoft.ad.user:
    name: "{{ user.samAccountName }}"
    sam_account_name: "{{ user.samAccountName }}"
    upn: "{{ user.upn }}"
    path: "{{ target_ou }}"
    enabled: yes
    password: "{{ temp_password }}"
    attributes:
      set:
        employeeID: "{{ user.employeeID }}"
        mail: "{{ user.mail }}"
        ms-DS-ConsistencyGuid: "{{ user.ms_ds_consistencyguid }}"  # Preserve from source
  delegate_to: "{{ target_dc }}"
```

**Step 3: Configure Entra Connect to use ms-DS-ConsistencyGuid**

```powershell
# On Entra Connect server
# During initial configuration wizard, select:
# "Use a specific Active Directory attribute" -> ms-DS-ConsistencyGuid

# Or via PowerShell (if already installed):
Import-Module ADSync
Set-ADSyncScheduler -SyncCycleEnabled $false  # Pause sync

$connector = Get-ADSyncConnector | Where-Object {$_.ConnectorType -eq "AD"}
$params = $connector.GlobalParameters | Where-Object {$_.Name -eq "Microsoft.Synchronize.SourceAnchorAttribute"}
$params.Value = "ms-DS-ConsistencyGuid"
$connector | Set-ADSyncConnector

Set-ADSyncScheduler -SyncCycleEnabled $true
Start-ADSyncSyncCycle -PolicyType Delta
```

---

### 1.4 Alternative: employeeID (HR-Driven)

**When to use:**
- HR system is authoritative source of identity
- employeeID is enforced unique in source AD
- Migration involves merging identities from multiple forests

**Risks:**
- Collisions if employeeID not truly unique
- HR data quality issues cause sync failures
- Not suitable for non-employee accounts (contractors, vendors)

**Implementation:**

```powershell
# Validate employeeID uniqueness
$duplicates = Get-ADUser -Filter * -Properties employeeID | Group-Object employeeID | Where-Object {$_.Count -gt 1 -and $_.Name -ne ""}
if ($duplicates) {
    Write-Error "Duplicate employeeIDs found: $($duplicates.Name -join ', ')"
    exit 1
}

# Configure Entra Connect
# Use "employeeID" as source anchor during wizard
```

---

## 2) Sync Scope and Filtering

### 2.1 OU-Based Filtering (Recommended)

**Strategy:** Sync only migration staging OUs to avoid polluting target Entra with service accounts, test users, etc.

**Configuration:**

```powershell
# On Entra Connect server
Import-Module ADSync

# Get AD connector
$connector = Get-ADSyncConnector | Where-Object {$_.ConnectorType -eq "AD"}

# Configure OU filtering
$partition = Get-ADSyncConnectorPartition -Connector $connector.Identifier | Select-Object -First 1
Set-ADSyncConnectorPartition -Connector $connector.Identifier -Partition $partition.Identifier `
    -IncludeOus @(
        "OU=Migration,OU=Users,DC=target,DC=com",
        "OU=Migration,OU=Groups,DC=target,DC=com"
    )

# Run delta sync
Start-ADSyncSyncCycle -PolicyType Delta
```

**Benefits:**
- Clean Entra tenant (only real users)
- Faster sync cycles
- Easier troubleshooting

---

### 2.2 Group-Based Filtering

**Strategy:** Sync only members of a specific AD group (e.g., `CN=MigrationUsers,OU=Groups,DC=target,DC=com`)

**Configuration:**

```powershell
# In Entra Connect Synchronization Rules Editor:
# 1. Create new inbound rule: "In from AD - User Scoping Filter"
# 2. Add scoping filter:
#    Attribute: memberOf
#    Operator: EQUAL
#    Value: CN=MigrationUsers,OU=Groups,DC=target,DC=com
# 3. Precedence: 50 (before default rules)

# Run full sync to apply
Start-ADSyncSyncCycle -PolicyType Initial
```

---

### 2.3 Attribute-Based Filtering

**Strategy:** Sync only users with specific attribute value (e.g., `extensionAttribute1 = "MIGRATE"`)

**Configuration:**

```powershell
# Synchronization Rules Editor -> New Rule
# Scoping filter:
#   Attribute: extensionAttribute1
#   Operator: EQUAL
#   Value: MIGRATE

# Run sync
Start-ADSyncSyncCycle -PolicyType Delta
```

---

## 3) Sync Timing and Convergence

### 3.1 Default Sync Schedule

**Entra Connect default:** 30-minute sync cycle

**View schedule:**
```powershell
Get-ADSyncScheduler
# SyncCycleEnabled: True
# NextSyncCyclePolicyType: Delta
# NextSyncCycleStartTimeInUTC: 2025-10-18T15:30:00Z
```

---

### 3.2 Manual Sync Triggers

**Delta Sync (only changes since last sync):**
```powershell
Start-ADSyncSyncCycle -PolicyType Delta
```

**Full Sync (all objects, slow):**
```powershell
Start-ADSyncSyncCycle -PolicyType Initial
```

**When to use manual sync:**
- After bulk user provisioning (don't wait 30 min)
- Before device domain joins (ensure users exist in Entra first)
- After configuration changes (OU filters, sync rules)

---

### 3.3 Sync Wait Loop (Automation)

**Problem:** Device joins fail if user not yet in Entra

**Solution:** Poll Graph API until user appears

**Playbook snippet:**
```yaml
# In machine_move_usmt role, before domain join for Entra-joined devices
- name: Wait for user to sync to Entra
  uri:
    url: https://graph.microsoft.com/v1.0/users/{{ user_upn }}
    method: GET
    headers:
      Authorization: "Bearer {{ graph_token }}"
    status_code: [200, 404]
  register: user_sync_check
  retries: 20
  delay: 90  # 90 sec × 20 = 30 min max wait
  until: user_sync_check.status == 200
  delegate_to: localhost
  failed_when: user_sync_check.status != 200

- name: Fail if user not synced after 30 min
  fail:
    msg: "User {{ user_upn }} not synced to Entra after 30 minutes. Check Entra Connect health."
  when: user_sync_check.status != 200
```

---

### 3.4 Monitoring Sync Health

**Entra Connect Health (Cloud):**
- Install Azure AD Connect Health agent on Entra Connect server
- View sync errors in Azure Portal: Azure AD → Azure AD Connect → Health

**Local Monitoring:**
```powershell
# Check last sync time
Get-ADSyncScheduler | Select-Object LastSyncTime,LastSyncResult

# View sync errors
Get-ADSyncCSObject -DistinguishedName "CN=John Doe,OU=Migration,DC=target,DC=com" |
    Select-Object -ExpandProperty LineageDetails |
    Select-Object Error

# Export sync errors to CSV
Export-ADSyncToolsDiagnostics -FilePath C:\Temp\SyncErrors.csv
```

**Grafana Dashboard (Tier 2/3):**
- Query Azure AD Graph for sync stats
- Alert if sync cycle fails or >10 objects in error state

---

## 4) Conflict Resolution

### 4.1 Conflict Scenarios

| Scenario | Cause | Resolution |
|----------|-------|------------|
| **Duplicate UPN** | User exists in target Entra with same UPN | Rename one UPN (suffix with `-mig` temporarily) |
| **Duplicate ProxyAddresses** | Mailbox with same SMTP address | Remove proxy address from one object, sync, re-add |
| **Anchor Mismatch** | ms-DS-ConsistencyGuid collision (rare) | Investigate: likely data corruption or manual edit |
| **Hard Match vs. Soft Match** | Object exists but anchor doesn't match | Force hard-match by setting ImmutableID in Entra |
| **Orphaned Entra Object** | Source AD object deleted, Entra object remains | Delete Entra object or disable sync for that object |

---

### 4.2 Detecting Conflicts

**Pre-Migration Validation:**

```powershell
# On source DC
# Check for UPN duplicates between source and target
$sourceUsers = Get-ADUser -Filter * -Properties UserPrincipalName -Server source-dc.source.com
$targetUsers = Get-ADUser -Filter * -Properties UserPrincipalName -Server target-dc.target.com

$upnConflicts = $sourceUsers.UserPrincipalName | Where-Object {$_ -in $targetUsers.UserPrincipalName}

if ($upnConflicts) {
    Write-Warning "UPN conflicts detected: $($upnConflicts -join ', ')"
}
```

**Playbook:**
```yaml
# roles/preflight_validation/tasks/entra_conflicts.yml
- name: Get target Entra users
  uri:
    url: https://graph.microsoft.com/v1.0/users?$select=userPrincipalName,mail
    headers:
      Authorization: "Bearer {{ graph_token }}"
  register: entra_users
  delegate_to: localhost

- name: Check for UPN conflicts
  set_fact:
    upn_conflicts: "{{ source_users | selectattr('upn', 'in', entra_users.json.value | map(attribute='userPrincipalName')) | list }}"

- name: Fail if conflicts found
  fail:
    msg: "UPN conflicts detected: {{ upn_conflicts | map(attribute='upn') | join(', ') }}"
  when: upn_conflicts | length > 0 and not force_proceed
```

---

### 4.3 Resolving Duplicate UPN

**Option A: Temporary Rename (Recommended)**

```powershell
# Rename source user UPN with suffix
Set-ADUser jdoe -UserPrincipalName "jdoe-mig@source.com" -Server source-dc.source.com

# Provision in target AD with final UPN
New-ADUser -SamAccountName jdoe -UserPrincipalName "jdoe@target.com" -Server target-dc.target.com

# Sync to Entra
Start-ADSyncSyncCycle -PolicyType Delta

# After validation, delete old Entra object or change UPN back in source
```

**Option B: Force Hard-Match (Advanced)**

```powershell
# Get ms-DS-ConsistencyGuid from source
$guid = (Get-ADUser jdoe -Properties ms-DS-ConsistencyGuid -Server source-dc.source.com)."ms-DS-ConsistencyGuid"
$immutableId = [System.Convert]::ToBase64String($guid)

# Set ImmutableID in target Entra (forces match)
Set-MsolUser -UserPrincipalName "jdoe@target.com" -ImmutableId $immutableId
# WARNING: This will merge identities; ensure you want this!

# Sync
Start-ADSyncSyncCycle -PolicyType Delta
```

---

### 4.4 Resolving ProxyAddresses Conflict

**Scenario:** Source user `jdoe@source.com` has proxy address `jdoe@company.com`, target user also has it (e.g., from previous migration)

**Resolution:**

```powershell
# Remove proxy address from target user temporarily
Set-ADUser jdoe -Remove @{proxyAddresses="smtp:jdoe@company.com"} -Server target-dc.target.com

# Sync
Start-ADSyncSyncCycle -PolicyType Delta

# Wait for sync to complete
Start-Sleep 120

# Re-add proxy address
Set-ADUser jdoe -Add @{proxyAddresses="smtp:jdoe@company.com"} -Server target-dc.target.com

# Sync again
Start-ADSyncSyncCycle -PolicyType Delta
```

---

## 5) Validation Procedures

### 5.1 Post-Provision Validation

**After user provisioning in target AD, before machine moves:**

```yaml
# Playbook: playbooks/10b_validate_sync.yml
- name: Validate Entra Sync Status
  hosts: localhost
  gather_facts: no

  tasks:
    - name: Trigger delta sync
      win_shell: Start-ADSyncSyncCycle -PolicyType Delta
      delegate_to: "{{ entra_connect_server }}"

    - name: Wait for sync cycle to complete
      pause:
        seconds: 300  # 5 min (one full cycle)

    - name: Check users in Entra
      uri:
        url: https://graph.microsoft.com/v1.0/users?$filter=startswith(userPrincipalName,'{{ item.upn }}')
        headers:
          Authorization: "Bearer {{ graph_token }}"
      loop: "{{ provisioned_users }}"
      register: entra_user_check

    - name: Report missing users
      debug:
        msg: "User {{ item.item.upn }} NOT FOUND in Entra"
      loop: "{{ entra_user_check.results }}"
      when: item.json.value | length == 0

    - name: Fail if >5% missing
      fail:
        msg: "More than 5% of users not synced to Entra. Check Entra Connect health."
      when: (entra_user_check.results | selectattr('json.value', 'equalto', []) | list | length) / (provisioned_users | length) > 0.05
```

---

### 5.2 Attribute Verification

**Ensure critical attributes synced correctly:**

```powershell
# Compare AD user to Entra user
$adUser = Get-ADUser jdoe -Properties employeeID,mail,displayName -Server target-dc.target.com
$entraUser = Get-MgUser -UserId "jdoe@target.com"

# Validate attributes match
if ($adUser.employeeID -ne $entraUser.EmployeeId) {
    Write-Error "employeeID mismatch: AD=$($adUser.employeeID), Entra=$($entraUser.EmployeeId)"
}

if ($adUser.mail -ne $entraUser.Mail) {
    Write-Error "mail mismatch: AD=$($adUser.mail), Entra=$($entraUser.Mail)"
}
```

---

### 5.3 License Assignment (Post-Sync)

**After users appear in Entra, assign M365 licenses:**

```powershell
# Via PowerShell
Set-MgUserLicense -UserId "jdoe@target.com" -AddLicenses @{SkuId="ENTERPRISEPACK"}

# Or via Graph API (in Ansible)
- name: Assign M365 license
  uri:
    url: https://graph.microsoft.com/v1.0/users/{{ user_upn }}/assignLicense
    method: POST
    headers:
      Authorization: "Bearer {{ graph_token }}"
    body:
      addLicenses:
        - skuId: "6fd2c87f-b296-42f0-b197-1e91e994b900"  # ENTERPRISEPACK (E3)
      removeLicenses: []
    body_format: json
    status_code: 200
```

---

## 6) Troubleshooting Common Issues

### Issue: User Not Syncing (Stuck in Pending)

**Symptoms:** User created in AD, but doesn't appear in Entra after 30+ minutes

**Diagnosis:**

```powershell
# Check if user is in sync scope
$user = Get-ADUser jdoe -Properties DistinguishedName,extensionAttribute1
if ($user.DistinguishedName -notlike "*OU=Migration*") {
    Write-Error "User not in sync scope OU"
}

# Check Entra Connect sync status
Get-ADSyncCSObject -DistinguishedName $user.DistinguishedName |
    Select-Object -ExpandProperty LineageDetails |
    Select-Object Error,InboundSyncRuleApplied
```

**Common Causes:**
- User in excluded OU
- User lacks required attributes (e.g., `mail` if rule requires it)
- Sync rule filtering user out (check `extensionAttribute1` value)
- Entra Connect service stopped

**Fix:**
1. Move user to correct OU OR update filter rules
2. Run delta sync: `Start-ADSyncSyncCycle -PolicyType Delta`
3. If still stuck after 2 cycles, run full sync: `Start-ADSyncSyncCycle -PolicyType Initial`

---

### Issue: Sync Error "Unable to update this object because the following attributes have values that may already be associated with another object"

**Cause:** Duplicate `proxyAddresses` or `userPrincipalName`

**Fix:**
```powershell
# Find conflicting object in Entra
Get-MgUser -Filter "proxyAddresses/any(x:x eq 'smtp:jdoe@company.com')"

# Remove conflict (see §4.4 above)
```

---

### Issue: Entra Connect Server Offline

**Symptoms:** Sync cycles not running, `Get-ADSyncScheduler` shows `SyncCycleEnabled: False`

**Fix:**
```powershell
# On Entra Connect server
# Check service status
Get-Service ADSync
# If stopped:
Start-Service ADSync

# Re-enable scheduler
Set-ADSyncScheduler -SyncCycleEnabled $true

# Run delta sync
Start-ADSyncSyncCycle -PolicyType Delta
```

---

## 7) Best Practices Summary

1. **Use ms-DS-ConsistencyGuid** as anchor (globally unique, portable)
2. **Filter sync scope** to Migration OUs (avoid service accounts, test users)
3. **Pre-populate anchor** in source AD before migration (consistency across forests)
4. **Validate conflicts** before provisioning (UPN, proxyAddresses)
5. **Wait for sync** before device joins (poll Graph API, don't assume)
6. **Monitor Entra Connect Health** (alerts on sync failures)
7. **Test sync in pilot** (validate 50 users sync within 10 minutes)
8. **Document exceptions** (users manually created, anchor mismatches)

---

## 8) Decision Matrix

| Migration Type | Anchor | Sync Scope | Manual Sync? | Wait Loop? |
|----------------|--------|------------|--------------|------------|
| On-Prem → Hybrid (staged) | ms-DS-ConsistencyGuid | Migration OU | Yes (after provision) | Yes (before device join) |
| On-Prem → Cloud-Only (no Connect) | N/A (Graph API direct) | N/A | N/A | No |
| Cloud → Cloud (tenant-to-tenant) | N/A (re-create users) | N/A | N/A | No |
| Forest Merge (on-prem → on-prem with sync) | employeeID (HR-driven) | Group-based | Yes (after ADMT) | Yes |

---

## 9) Appendix: Entra Connect Cloud Sync vs. AAD Connect

| Feature | Entra Connect Cloud Sync | Azure AD Connect (AADConnect) |
|---------|--------------------------|-------------------------------|
| **Architecture** | Lightweight agent, cloud-managed | Full sync engine on-premises |
| **Deployment** | Install agent on DC or member server | Dedicated Windows Server |
| **HA** | Multi-agent (active-active) | Active-standby (requires clustering) |
| **Sync Speed** | 2-minute cycle | 30-minute cycle (configurable) |
| **Filtering** | Cloud-based rules (Azure Portal) | On-premises rules (Sync Rules Editor) |
| **Password Hash Sync** | ✓ | ✓ |
| **Passthrough Auth** | ✓ | ✓ |
| **Federation** | ❌ (use ADFS separately) | ✓ (integrated) |
| **Device Writeback** | ❌ | ✓ |
| **Group Writeback** | ❌ | ✓ |
| **Hybrid Exchange** | Limited | Full support |
| **Best For** | New deployments, simple sync, cloud-first | Complex migrations, hybrid Exchange, device writeback |

**Recommendation for Migrations:**
- **Tier 1/2:** Entra Connect Cloud Sync (simpler, faster)
- **Tier 3:** AADConnect if hybrid Exchange or device writeback required

---

## 10) Checklist for Entra Sync Setup

**Pre-Migration:**
- [ ] Entra Connect installed and configured
- [ ] Anchor attribute strategy decided (ms-DS-ConsistencyGuid recommended)
- [ ] Sync scope defined (OU filter, group filter, or attribute filter)
- [ ] Conflict detection script run (UPN, proxyAddresses)
- [ ] Entra Connect Health agent installed (Tier 2/3)
- [ ] Monitoring dashboard configured (Grafana or Azure Portal)

**During Migration:**
- [ ] Users provisioned in target AD with anchor attribute
- [ ] Manual delta sync triggered after provisioning
- [ ] Sync wait loop in playbooks (before device joins)
- [ ] License assignment automation configured (Graph API)

**Post-Migration:**
- [ ] Validate all users synced (compare AD count vs. Entra count)
- [ ] Check attributes match (employeeID, mail, displayName)
- [ ] Verify licenses assigned (via Azure Portal or Graph API)
- [ ] Monitor sync health for 7 days (catch delayed sync errors)

---

**For operational procedures, see `docs/05_RUNBOOK_OPERATIONS.md`.**

**For troubleshooting, see `docs/06_RUNBOOK_TROUBLESHOOTING.md`.**

---

**END OF DOCUMENT**

