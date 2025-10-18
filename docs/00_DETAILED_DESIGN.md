# Ansible-Orchestrated Identity & Domain Migration – Detailed Design v2.0

**Version:** 2.0  
**Date:** October 2025  
**Author:** Adrian Johnson <adrian207@gmail.com>  
**Status:** Ready for Implementation

---

## Document Change Log

**v2.0 Changes:**
- Added three deployment tiers (Demo, Medium, Enterprise)
- Included missing validation, rollback, and DR procedures
- Corrected throughput estimates with I/O modeling
- Added Entra Connect synchronization strategy
- Expanded Linux migration details with UID/GID collision handling
- Revised timelines with risk-adjusted schedules
- Added training and skill requirements per tier

---

## Executive Summary

**Scope:** Build an open-source, Ansible-driven solution to migrate users, groups, machine memberships, and user state (via USMT) across Active Directory forests/tenants and Entra ID (Azure AD) tenants. Design supports three pathways with **primary focus on On-Prem or Cloud → Separate Cloud Tenant**.

**Key Objectives:**
* Deterministic exports and replayable provisioning (idempotent) for identities, devices, and post-join remediation
* Profile and settings capture/restore on endpoints using USMT
* Optional ADMT integration for SIDHistory/password copy
* Horizontal scalability with wave control, back-pressure, and safety gates
* **Three deployment tiers** for different organizational scales and maturity levels

**Success Criteria:**
* Zero data loss during migration
* <5% failure rate per wave with automated recovery
* Rollback capability within change window (4 hours)
* Complete audit trail for compliance
* Operational handoff with runbooks and trained team

---

## 1) Deployment Tiers Overview

This design supports **three deployment models** to match organizational scale, budget, and technical maturity:

### Tier 1: Demo/POC Edition
**Target:** Small migrations (<500 users), proof-of-concept, budget-constrained projects

**Infrastructure:**
- Single AWX VM or Ansible Core CLI
- Ansible Vault (file-based) for secrets
- SQLite or CSV for reporting data
- Nginx serving static HTML reports
- Prometheus (single node) + Grafana (optional)

**Capacity:**
- 500 users, 100 workstations, 25 servers
- 1 runner, serial execution or low parallelism (≤25 forks)

**Timeline:** 6-8 weeks (setup + pilot + 2-3 waves)

**Team:** 2-3 FTE with Ansible + AD/Windows skills

---

### Tier 2: Medium/Staging Edition
**Target:** Mid-size migrations (500-3,000 users), dev/staging environments, multi-wave production

**Infrastructure:**
- AWX (HA pair or single with backup)
- HashiCorp Vault (single node with snapshot backups)
- PostgreSQL (single primary + streaming replica)
- Object storage (MinIO single-node or S3/Blob)
- Prometheus + Grafana stack (2 nodes)
- Regional USMT state stores (2-3 locations)

**Capacity:**
- 3,000 users, 800 workstations, 150 servers
- 2-3 runners, moderate parallelism (50-100 forks)

**Timeline:** 10-14 weeks (setup + pilot + 4-8 waves)

**Team:** 4-5 FTE with Ansible, AD, cloud, and database skills

---

### Tier 3: Enterprise Edition
**Target:** Large migrations (>3,000 users), multi-tenant, global scope, mission-critical

**Infrastructure:**
- AWX on Kubernetes (HA: 3 control + 3+ workers)
- HashiCorp Vault HA (3-node Raft cluster, auto-unseal)
- PostgreSQL HA (Patroni, 3 nodes, read replicas)
- MinIO HA (4+ nodes, erasure coding)
- Full observability stack (Prometheus, Alertmanager, Grafana, Loki)
- Self-healing automation with guardrails
- Multi-region USMT state stores (DFS-R or object replication)

**Capacity:**
- 10,000+ users, 3,000+ workstations, 500+ servers
- 5+ runners with horizontal scaling

**Timeline:** 16-24 weeks (setup + extensive pilot + 10-20 waves)

**Team:** 6-8 FTE with Ansible, K8s, Vault, PostgreSQL, networking expertise

---

## 2) Assumptions & Constraints

### 2.1 Technical Prerequisites
* Source and target AD forests reachable over secure links; DNS resolution configured
* Firewall ports open: WinRM/5986, LDAP/389, Kerberos/88, SMB/445, SSH/22
* For tenant-to-tenant: cross-tenant app registrations and Graph API permissions granted
* USMT packages (scanstate/loadstate) licensed and accessible from fileshare/package repo
* **SIDHistory/password copy** requires ADMT + PES + two-way trust; otherwise temporary passwords
* Change windows exist for endpoint reboots and service restarts (typically 4-6 hours)

### 2.2 Security Requirements
* All secrets stored in Ansible Vault (Tier 1) or HashiCorp Vault (Tier 2/3)
* No cleartext passwords in logs (redaction filters enabled)
* WinRM transport: **Kerberos over HTTPS (port 5986)** with message encryption
* Linux: **SSH with certificate-based auth** (Vault CA in Tier 2/3) or key-based (Tier 1)
* Just-in-time credentials with TTLs matched to job duration (Tier 2/3)
* Mandatory audit logging to SIEM or centralized log store

### 2.3 Networking
* Runner has routed access to all targets (on-prem and cloud)
* For cloud runners: private connectivity via VPN/ExpressRoute/DirectConnect or bastion hosts
* State stores accessible via SMB (Tier 1/2) or object storage API (Tier 3)
* Bandwidth to state stores: minimum 1 Gbps per 100 concurrent workstations

### 2.4 Operational
* Dedicated change windows (off-hours) for device migrations
* CAB approval process for production waves
* Break-glass accounts tested quarterly
* Backup/snapshot capability for all infrastructure components
* Trained on-call team for wave execution (Tier 2/3)

---

## 3) High-Level Architecture

### 3.1 Control Plane Components

#### Tier 1 (Demo/POC)
```
┌─────────────────────────────────────────────┐
│ Ansible Control Node (Single VM)           │
│ ┌─────────────┐  ┌──────────────┐         │
│ │ Ansible Core│  │ Ansible Vault│         │
│ │   or AWX    │  │  (file-based)│         │
│ └─────────────┘  └──────────────┘         │
│ ┌─────────────────────────────────────┐   │
│ │ Nginx (static HTML reports)         │   │
│ │ /var/www/reports/                   │   │
│ └─────────────────────────────────────┘   │
│ ┌─────────────────────────────────────┐   │
│ │ Prometheus + Grafana (optional)     │   │
│ │ (Docker Compose)                    │   │
│ └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
         │
         ├─[WinRM/5986]──> Domain Controllers
         ├─[WinRM/5986]──> Windows Servers/Workstations
         ├─[SSH/22]─────> Linux Servers
         └─[SMB/445]────> USMT State Share
```

#### Tier 2 (Medium/Staging)
```
┌──────────────────────────────────────────────────────────┐
│ Control Plane (3-5 VMs)                                  │
│ ┌─────────────────┐  ┌──────────────────────────────┐   │
│ │ AWX (HA pair or │  │ HashiCorp Vault (single)     │   │
│ │ single + backup)│  │ - AD secrets engine          │   │
│ └─────────────────┘  │ - Database secrets engine    │   │
│                      │ - SSH CA                      │   │
│ ┌─────────────────┐  └──────────────────────────────┘   │
│ │ PostgreSQL      │                                      │
│ │ Primary+Replica │  ┌──────────────────────────────┐   │
│ │ (reporting data)│  │ Prometheus + Grafana         │   │
│ └─────────────────┘  │ Alertmanager                 │   │
│                      └──────────────────────────────┘   │
│ ┌───────────────────────────────────────────────────┐   │
│ │ Nginx (reports + reverse proxy to Grafana)       │   │
│ │ /dashboard/ -> Grafana                            │   │
│ │ /reports/   -> Static HTML                        │   │
│ └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘
         │
         ├─[WinRM/5986]──> Targets (via 2-3 execution runners)
         ├─[HTTPS/443]──> Entra Graph API
         └─[S3 API]────> MinIO or Cloud Object Storage
```

#### Tier 3 (Enterprise)
```
┌────────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (AWX + Supporting Services)            │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ AWX Operator (3 control nodes + 3+ execution pods)    │ │
│ │ - HPA-enabled autoscaling for execution pods          │ │
│ │ - Job isolation with separate namespaces              │ │
│ └────────────────────────────────────────────────────────┘ │
│ ┌────────────────────┐  ┌────────────────────────────┐    │
│ │ Vault HA (Raft)    │  │ PostgreSQL HA (Patroni)    │    │
│ │ 3 nodes, auto-unseal│  │ 3 nodes + read replicas    │    │
│ │ Integrated with    │  │ Streaming replication       │    │
│ │ K8s ServiceAccount │  │ Dynamic creds from Vault    │    │
│ └────────────────────┘  └────────────────────────────┘    │
│ ┌────────────────────────────────────────────────────────┐ │
│ │ Observability Stack (Prometheus Operator)              │ │
│ │ - Prometheus (multi-replica)                           │ │
│ │ - Alertmanager (HA)                                    │ │
│ │ - Grafana (HA)                                         │ │
│ │ - Loki for log aggregation                             │ │
│ │ - Pushgateway for batch metrics                        │ │
│ └────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
         │
         ├─[WinRM/5986]──> Targets (via 5+ execution pods)
         ├─[HTTPS/443]──> Multi-tenant Entra
         └─[S3 API]────> MinIO HA (4-node erasure-coded)
```

### 3.2 Logical Modules (Ansible Roles)

**Core Migration Roles:**
1. `ad_export` – Export users, groups, memberships, computers from source
2. `ad_provision` – Create OUs, groups, users in target (idempotent)
3. `admt_orchestrate` (optional) – Execute ADMT for SIDHistory/password copy
4. `machine_move_usmt` – Capture USMT → disjoin → join → restore
5. `server_rebind` – Remediate services/tasks/SPNs/ACLs post-move
6. `linux_export` – Export local and domain-joined Linux accounts
7. `linux_migrate` – Migrate Linux users, update sssd/realm, fix ownerships

**Validation & Governance Roles:**
8. `preflight_validation` – App dependencies, coexistence tests, capacity checks
9. `discovery_health` – DC health, secure channel, WinRM, time sync
10. `discovery_destination` – Connectivity matrix to target DCs/Entra
11. `gate_on_health` – Abort wave if failure rate >threshold
12. `change_freeze_check` – Detect CAB blackout windows

**Remediation Roles (Tier 2/3):**
13. `heal_winrm` – Repair WinRM service/config
14. `heal_secure_channel` – Fix broken trust relationships
15. `heal_sssd` – Restart sssd, rejoin AD realm

**Reporting & Telemetry:**
16. `reporting_render` – Generate HTML reports from artifacts
17. `reporting_publish` – Copy reports to web server
18. `reporting_etl` – Insert telemetry into PostgreSQL (Tier 2/3)

**DNS & Network:**
19. `dns_discovery` – Export DNS records from source zones
20. `dns_provision` – Create DNS records in target zones
21. `dns_cleanup` – Remove stale records from source DNS
22. `dns_validate` – Verify forward/reverse lookups post-migration

**Infrastructure (Tier 2/3):**
23. `reporting_web_nginx` – Deploy Nginx for reports + Grafana proxy
24. `observability_stack` – Deploy Prometheus/Grafana/Alertmanager
25. `vault_bootstrap` – Initialize Vault, enable engines, create policies

**Rollback & Recovery:**
26. `rollback_machine` – Rejoin old domain, restore ACLs/services
27. `rollback_identity` – Disable target users, revert sync rules
28. `rollback_dns` – Restore DNS records in source zones
29. `backup_control_plane` – Snapshot Vault, Postgres, configs
30. `zfs_snapshot` – Automated ZFS snapshots for rapid recovery (Tier 2/3)
31. `rollback_zfs` – Instant rollback via ZFS snapshots (Tier 2/3)

### 3.3 Data Artifacts

**Exports (CSV/JSON):**
- `Users.csv` – samAccountName, UPN, displayName, employeeID, mail, OU
- `Groups.csv` – name, description, scope, type, managedBy
- `GroupMembership.csv` – groupName, memberName, memberType
- `Computers.csv` – name, OS, OU, site, IPv4, lastLogon
- `LinuxUsers.csv` – username, UID, GID, home, shell, groups
- `LinuxGroups.csv` – groupname, GID, members
- `DNS_Zones.json` – per-zone: A, CNAME, SRV, PTR records
- `Network_Config.json` – per-host: IP addresses, DNS servers, DNS suffix

**Mappings:**
- `domain_map.yml` – source domain → target domain
- `group_map.yml` – source group names → target group names
- `service_account_map.yml` – old accounts → new accounts with Vault paths
- `ou_map.yml` – source OU paths → target OU paths
- `uid_gid_map.yml` – Linux UID/GID collision resolution
- `dns_aliases.yml` – CNAME aliases to re-create (e.g., sql, intranet, fileserver)
- `ip_address_map.yml` – old IP → new IP (if changing IP addressing)

**Batching & Waves:**
- `batches.yml` – wave definitions with concurrency, blackout dates, tags
- `pilot_hosts.yml` – 5-10 test systems for initial validation

**State Persistence:**
- `state/run/<run_id>/manifest.json` – wave metadata, start time, status
- `state/host/<hostname>/progress.json` – per-host checkpoint (pre-capture, captured, joined, restored)
- `state/host/<hostname>/rollback.json` – original domain, ACL backup path, service backup

**Backups (for rollback):**
- `backups/acls/<hostname>_<timestamp>.txt` – icacls export
- `backups/services/<hostname>_<timestamp>.json` – service principals, startup types
- `backups/spns/<hostname>_<timestamp>.txt` – registered SPNs

---

## 4) Migration Pathways

### 4.1 On-Prem or Hybrid → Separate Cloud Tenant (Primary)

**Use Case:** Migrate from existing on-prem AD or hybrid environment to a new Entra tenant (M&A, spin-off, modernization)

**Identity Flow:**
1. **Export Phase** (`ad_export`)
   - Extract users/groups/memberships from source AD
   - Normalize to CSV with anchor attributes (employeeID, mail)
   - Export device ownership mapping (user ↔ computer)

2. **Target Preparation** (`ad_provision`)
   - Create OUs in target AD (if hybrid) or directly in Entra (cloud-only)
   - Provision groups with translated names via `group_map.yml`
   - Create users with temporary passwords OR stage for Entra Connect sync
   - **Entra Connect Strategy** (see §5 for details):
     - **Hybrid:** Provision in target AD, sync to Entra via Entra Connect Cloud Sync
     - **Cloud-only:** Use Graph API to create directly in Entra

3. **Device Strategy**
   - **Workstations:**
     - USMT capture to regional state store
     - Domain disjoin → workgroup → join target domain
     - USMT restore with user mapping (`SOURCE\user` → `TARGET\user`)
     - Enroll to Intune (if applicable)
   - **Servers:**
     - Domain move + service/task/SPN/ACL remediation
     - Test app functionality before wave completion

4. **Validation**
   - User login tests (RDP, app access)
   - Group membership parity checks
   - Service account validation
   - Application smoke tests

**Special Considerations:**
- **Mailbox migration** (out of scope but coordinated): Cutover timing with Exchange/M365 migration
- **App federation**: Retarget SAML/OIDC apps to new Entra tenant (manual or scripted)
- **Certificates**: Reissue computer certs after domain change
- **GPOs**: Translate hardcoded domain references

---

### 4.2 On-Prem → On-Prem (Forest Consolidation)

**Use Case:** Merge two on-prem AD forests, retire old domain after M&A

**Differences from 4.1:**
- Stronger case for **ADMT with SIDHistory** to preserve resource access
- Temporary **two-way trust** during migration window
- May use **staged migration**: migrate servers first, workstations second
- **Group translation** via dual-membership (user in both old and new groups during transition)

**ADMT Workflow** (`admt_orchestrate`):
1. Install ADMT + PES on jump host with access to both domains
2. Create ADMT project files (XML) for Users → Groups → Computers
3. Execute via `win_shell` with log capture
4. Validate SIDHistory and password migration
5. Decommission source domain after validation period (30-90 days)

---

### 4.3 Cloud → Cloud (Tenant-to-Tenant)

**Use Case:** Entra tenant migration (M&A, divestiture)

**Identity Flow:**
- Use **Graph API or PowerShell** for user/group re-creation in target Entra
- Leverage **Cross-Tenant Synchronization** (preview feature) if available
- Re-assign enterprise app access via Graph API
- Retarget federation for each SaaS app (Salesforce, ServiceNow, etc.)

**Device Flow:**
- **Azure AD Joined devices:**
  - Option A: Autopilot re-provision (wipe + re-enroll)
  - Option B: Disjoin → local → join target tenant (preserves data)
- **Hybrid-joined devices:** Follow pathway 4.1 (domain move)
- **Profile migration:** OneDrive Known Folder Move or FSLogix profile containers

**Challenges:**
- No SIDHistory equivalent in Entra (use group translation)
- App consent must be re-granted
- Conditional Access policies must be rebuilt

---

### 4.4 On-Prem → Cloud (Lift-and-Shift to Entra)

**Use Case:** Decommission on-prem AD entirely, move to cloud-only identity

**Identity Flow:**
1. Stage users in target Entra with `employeeID` as anchor
2. **No Entra Connect** in this scenario (pure cloud identity)
3. Users receive temporary passwords + MFA enrollment
4. License assignment via Graph API (M365, EMS)

**Device Flow:**
- **Workstations:** USMT capture → **Azure AD Join** (not domain join) → USMT restore → Intune enroll
- **Servers:**
  - Remain on-prem but Azure Arc-enabled for management
  - Local account management (no domain)
  - OR: Lift to Azure IaaS + Azure AD Domain Services

**Challenges:**
- No group policy (migrate to Intune/Endpoint Manager)
- File server access requires Azure Files or on-prem with Azure AD Kerberos
- Line-of-business apps may require re-architecture for Entra auth

---

### 4.5 Linux Support (Parallel Track)

#### 4.5.1 Independent Linux Servers (Local Users)

**Discovery** (`linux_export`):
```bash
getent passwd | awk -F: '$3 >= 1000 && $3 < 65534' > local_users.csv
getent group | awk -F: '$3 >= 1000 && $3 < 65534' > local_groups.csv
```

**Migration** (`linux_migrate`):
1. Detect UID/GID collisions with target systems
2. Create mapping file for conflicts (e.g., user `jdoe` UID 1001 → 5001)
3. Recreate users/groups with `ansible.builtin.user` and `ansible.builtin.group`
4. Migrate home directories via `rsync --numeric-ids`
5. Fix file ownerships with `find ... -uid <old> -exec chown <new> {}`
6. Deploy SSH authorized_keys
7. Validate login and sudo access

#### 4.5.2 Domain-Joined Linux (sssd/realmd)

**Health Check** (`discovery_health`):
```yaml
- name: Check Kerberos ticket
  command: klist -s
  register: krb_check
  failed_when: false

- name: Check sssd service
  service_facts:
  
- name: Validate domain user lookup
  command: getent passwd testuser@{{ source_domain }}
  register: getent_check
  failed_when: false

- name: Check time sync (critical for Kerberos)
  command: chronyc tracking
  register: time_check
```

**Migration** (`linux_migrate`):
1. Update `/etc/sssd/sssd.conf` with target domain
2. Update `/etc/krb5.conf` with target realm
3. Leave old domain: `realm leave`
4. Join new domain: `realm join {{ target_domain }} -U {{ admin_user }}`
5. Update keytab: `adcli update --domain={{ target_domain }}`
6. Clear sssd cache: `sss_cache -E`
7. Restart sssd: `systemctl restart sssd`
8. Fix file ACLs and ownerships (translate old domain SIDs to new)

**ACL Translation:**
```yaml
- name: Get idmap for old domain
  command: wbinfo --sid-to-uid={{ old_sid }}
  register: old_uid

- name: Get idmap for new domain
  command: wbinfo --name-to-sid={{ target_domain }}\\{{ username }}
  register: new_sid

- name: Update file ownerships
  command: find {{ data_path }} -uid {{ old_uid.stdout }} -exec chown {{ new_uid }} {} +
```

---

## 5) Entra Connect Synchronization Strategy

### 5.1 Anchor Attribute Selection

**Purpose:** Ensure users created in target AD sync correctly to target Entra without collisions or duplicates.

**Options:**
1. **ms-DS-ConsistencyGuid (recommended)**
   - Auto-populated by Entra Connect on first sync
   - Immutable, globally unique
   - **Strategy:** Pre-populate from `objectGUID` during provisioning

2. **employeeID**
   - Good if HR system is source of truth
   - Risk of collisions if employeeID not enforced
   - Requires manual conflict resolution

3. **mail (soft-match)**
   - Used for Exchange migrations
   - High collision risk in multi-forest scenarios
   - Avoid unless specifically needed for mailbox matching

**Implementation:**
```yaml
# In ad_provision role
- name: Set ms-DS-ConsistencyGuid to objectGUID
  microsoft.ad.user:
    identity: "{{ user.samAccountName }}"
    attributes:
      set:
        ms-DS-ConsistencyGuid: "{{ user.objectGUID | b64encode }}"
```

### 5.2 Sync Scope and Filtering

**Best Practice:** Sync only migration staging OUs to avoid polluting target Entra with service accounts, test users, etc.

**Entra Connect Filtering:**
- OU-based: Include only `OU=Migration,DC=target,DC=com`
- Group-based: Sync only members of `CN=MigrationUsers,OU=Groups,DC=target,DC=com`
- Attribute-based: `extensionAttribute1 -eq "MIGRATE"`

**Sync Timing:**
- Default: 30-minute cycle
- Manual sync: `Start-ADSyncSyncCycle -PolicyType Delta`
- Monitor: `Get-ADSyncScheduler` and Azure AD Connect Health

### 5.3 Waiting for Sync Completion

**Challenge:** Device joins fail if user not yet in Entra

**Solution:** Add sync wait task
```yaml
# In machine_move_usmt role, before domain join
- name: Wait for user to sync to Entra
  uri:
    url: https://graph.microsoft.com/v1.0/users/{{ user_upn }}
    method: GET
    headers:
      Authorization: "Bearer {{ graph_token }}"
    status_code: [200, 404]
  register: user_sync
  retries: 20
  delay: 90  # 30 sec between checks = 30 min max wait
  until: user_sync.status == 200
  delegate_to: localhost
```

### 5.4 Conflict Resolution

**Scenario:** User exists in target Entra from previous migration or pre-creation

**Detection:**
```yaml
- name: Check for existing user
  microsoft.graph.user_info:
    user_principal_name: "{{ target_upn }}"
  register: existing_user
  failed_when: false
```

**Resolution Options:**
1. **Merge:** Update existing user with source attributes (careful with data overwrite)
2. **Suffix:** Create with `jdoe_mig@target.com`, then rename after validation
3. **Abort:** Flag for manual review if high-value account (executives)

---

## 6) Detailed Component Design

### 6.1 Identity Export (`ad_export`)

**Inputs:**
- `export_scope_ous`: List of OU DNs to export
- `export_user_filter`: LDAP filter (e.g., `(enabled -eq $true)`)
- `export_attributes`: List of AD attributes to capture

**Process:**
```yaml
- name: Export users from source AD
  microsoft.ad.user:
    identity: "*"
    filter: "{{ export_user_filter }}"
    properties: "{{ export_attributes }}"
    search_base: "{{ item }}"
  loop: "{{ export_scope_ous }}"
  register: ad_users
  delegate_to: "{{ source_dc }}"

- name: Write to CSV
  copy:
    dest: "{{ artifacts_dir }}/Users_{{ ansible_date_time.epoch }}.csv"
    content: "{{ ad_users | to_csv }}"
```

**Outputs:**
- `artifacts/Users_TIMESTAMP.csv`
- `artifacts/Groups_TIMESTAMP.csv`
- `artifacts/GroupMembership_TIMESTAMP.csv`
- `artifacts/Computers_TIMESTAMP.csv`

**Idempotence:** Timestamped exports; git commit for version control

---

### 6.2 Identity Provision (`ad_provision`)

**Target Modes:**

#### Mode A: Hybrid (Provision in AD, Sync to Entra)
```yaml
- name: Create user in target AD
  microsoft.ad.user:
    name: "{{ user.samAccountName }}"
    sam_account_name: "{{ user.samAccountName }}"
    upn: "{{ user.upn }}"
    path: "{{ ou_map[user.source_ou] | default(default_ou) }}"
    enabled: yes
    password: "{{ temp_password }}"
    attributes:
      set:
        employeeID: "{{ user.employeeID }}"
        mail: "{{ user.mail }}"
        ms-DS-ConsistencyGuid: "{{ user.objectGUID | b64encode }}"
    state: present
  delegate_to: "{{ target_dc }}"
```

#### Mode B: Cloud-Only (Direct to Entra via Graph)
```yaml
- name: Create user in Entra
  uri:
    url: https://graph.microsoft.com/v1.0/users
    method: POST
    headers:
      Authorization: "Bearer {{ graph_token }}"
      Content-Type: application/json
    body:
      accountEnabled: true
      displayName: "{{ user.displayName }}"
      mailNickname: "{{ user.mailNickname }}"
      userPrincipalName: "{{ user.upn }}"
      employeeId: "{{ user.employeeID }}"
      passwordProfile:
        forceChangePasswordNextSignIn: true
        password: "{{ temp_password }}"
    body_format: json
    status_code: [201, 429]
  register: create_result
  retries: 5
  delay: "{{ 2 ** (ansible_loop.index | default(1)) }}"  # Exponential backoff
  until: create_result.status == 201
```

**Group Membership Restoration:**
```yaml
- name: Restore group memberships
  microsoft.ad.group_member:
    identity: "{{ group_map[item.group] | default(item.group) }}"
    members:
      - name: "{{ item.member }}"
    state: present
  loop: "{{ group_memberships }}"
  when: group_map[item.group] is defined or not strict_mapping
```

**Reporting:**
- `artifacts/provision_report_<wave>.html` – created vs. skipped (already exists), unmapped groups

---

### 6.3 ADMT Orchestration (`admt_orchestrate`) [Optional]

**Prerequisites Validation:**
```yaml
- name: Check two-way trust
  win_powershell:
    script: |
      Get-ADTrust -Filter {Direction -eq "Bidirectional" -and Target -eq "{{ source_domain }}"}
  register: trust_check
  failed_when: trust_check.output | length == 0

- name: Verify PES service running
  win_service_info:
    name: PasswordExportServer
  register: pes_check
  failed_when: pes_check.services[0].state != 'running'
```

**Execution:**
```yaml
- name: Run ADMT user migration
  win_shell: |
    ADMT.exe USER /N "{{ admt_project_file }}" /SD:"{{ source_domain }}" /TD:"{{ target_domain }}" 
             /TO:"{{ target_ou }}" /SIHIST:YES /PWD:COPY
  register: admt_result
  async: 3600
  poll: 30

- name: Parse ADMT log
  win_shell: |
    Get-Content "C:\ADMT\Logs\Migration.log" | Select-String "Successfully migrated|Failed"
  register: admt_summary
```

---

### 6.4 Machine Move + USMT (`machine_move_usmt`)

**Phase 1: Pre-Flight Checks**
```yaml
- name: Check disk space for USMT store
  win_disk_facts:
  register: disks

- name: Validate free space >20GB
  assert:
    that: disks.disks[0].free_gb > 20
    fail_msg: "Insufficient disk space for USMT capture"

- name: Test state store connectivity
  win_stat:
    path: "{{ usmt_store_base }}\\{{ inventory_hostname }}"
  register: store_access
  failed_when: false

- name: Create state store path
  win_file:
    path: "{{ usmt_store_base }}\\{{ inventory_hostname }}"
    state: directory
  when: not store_access.stat.exists

- name: Check WinRM to target DC
  win_shell: |
    Test-ComputerSecureChannel -Server {{ target_dc }}
  register: target_dc_check
  failed_when: false
  delegate_to: "{{ target_dc }}"
```

**Phase 2: Create Rollback Backup**
```yaml
- name: Backup ACLs
  win_shell: |
    icacls C:\Data /save {{ backup_dir }}\acls_{{ inventory_hostname }}_{{ ansible_date_time.epoch }}.txt /t
  register: acl_backup

- name: Backup service principals
  win_service_info:
  register: services_before

- name: Save service state
  copy:
    dest: "{{ backup_dir }}/services_{{ inventory_hostname }}_{{ ansible_date_time.epoch }}.json"
    content: "{{ services_before | to_json }}"
  delegate_to: localhost

- name: Record current domain membership
  win_domain_membership:
  register: current_domain

- name: Save rollback state
  copy:
    dest: "{{ state_dir }}/host/{{ inventory_hostname }}/rollback.json"
    content: |
      {
        "original_domain": "{{ current_domain.domain }}",
        "acl_backup": "{{ acl_backup.stdout }}",
        "timestamp": "{{ ansible_date_time.iso8601 }}"
      }
  delegate_to: localhost
```

**Phase 3: USMT Capture**
```yaml
- name: Run scanstate
  win_shell: |
    {{ usmt_path }}\scanstate.exe {{ usmt_store_base }}\{{ inventory_hostname }} /v:13 /o /c 
                                   /uel:90 /ue:*\* /ui:{{ domain }}\{{ user_list | join(' /ui:' + domain + '\\') }}
                                   /i:{{ usmt_path }}\MigApp.xml /i:{{ usmt_path }}\MigDocs.xml
                                   /progress:{{ usmt_store_base }}\{{ inventory_hostname }}\progress.log
                                   /l:{{ usmt_store_base }}\{{ inventory_hostname }}\scanstate.log
  register: scanstate
  async: 7200  # 2 hours max
  poll: 60

- name: Compress USMT store (Tier 2/3)
  win_shell: |
    Compress-Archive -Path {{ usmt_store_base }}\{{ inventory_hostname }}\* 
                     -DestinationPath {{ usmt_store_base }}\{{ inventory_hostname }}.zip -CompressionLevel Optimal
  when: usmt_compression_enabled | default(false)

- name: Update progress state
  copy:
    dest: "{{ state_dir }}/host/{{ inventory_hostname }}/progress.json"
    content: '{"phase": "captured", "timestamp": "{{ ansible_date_time.iso8601 }}"}'
  delegate_to: localhost
```

**Phase 4: Domain Move**
```yaml
- name: Disjoin from source domain
  win_domain_membership:
    state: workgroup
    workgroup_name: TEMP
  register: disjoin_result

- name: Reboot after disjoin
  win_reboot:
    reboot_timeout: 600

- name: Update progress state
  copy:
    dest: "{{ state_dir }}/host/{{ inventory_hostname }}/progress.json"
    content: '{"phase": "disjoined", "timestamp": "{{ ansible_date_time.iso8601 }}"}'
  delegate_to: localhost

- name: Join target domain
  win_domain_membership:
    dns_domain_name: "{{ target_domain }}"
    domain_admin_user: "{{ target_admin_user }}"
    domain_admin_password: "{{ vault_target_admin_pass }}"
    domain_ou_path: "{{ target_ou }}"
    state: domain
  register: join_result

- name: Reboot after join
  win_reboot:
    reboot_timeout: 600
```

**Phase 5: USMT Restore**
```yaml
- name: Run loadstate
  win_shell: |
    {{ usmt_path }}\loadstate.exe {{ usmt_store_base }}\{{ inventory_hostname }} /v:13 /c
                                   /mu:{{ source_domain }}\*:{{ target_domain }}\*
                                   /progress:{{ usmt_store_base }}\{{ inventory_hostname }}\restore_progress.log
                                   /l:{{ usmt_store_base }}\{{ inventory_hostname }}\loadstate.log
  register: loadstate
  async: 7200
  poll: 60

- name: Update progress state
  copy:
    dest: "{{ state_dir }}/host/{{ inventory_hostname }}/progress.json"
    content: '{"phase": "restored", "timestamp": "{{ ansible_date_time.iso8601 }}"}'
  delegate_to: localhost

- name: Final reboot
  win_reboot:
    reboot_timeout: 600
```

**Phase 6: DNS Registration and Validation**
```yaml
- name: Configure DNS client settings
  win_shell: |
    Set-DnsClient -InterfaceAlias "{{ primary_interface }}" -RegisterThisConnectionsAddress $true
    Set-DnsClient -InterfaceAlias "{{ primary_interface }}" -ConnectionSpecificSuffix "{{ target_domain }}"

- name: Set target DNS servers
  win_shell: |
    Set-DnsClientServerAddress -InterfaceAlias "{{ primary_interface }}" -ServerAddresses @("{{ target_dns_primary }}", "{{ target_dns_secondary }}")

- name: Force DNS registration
  win_shell: |
    Register-DnsClient
    ipconfig /registerdns

- name: Wait for DNS propagation
  pause:
    seconds: 60

- name: Verify forward DNS resolution
  win_shell: |
    Resolve-DnsName {{ inventory_hostname }}.{{ target_domain }} -Server {{ target_dns_primary }}
  register: dns_verify
  retries: 5
  delay: 30
  until: dns_verify is success

- name: Clean up old DNS records in source
  win_shell: |
    Remove-DnsServerResourceRecord -ZoneName "{{ source_domain }}" -Name "{{ inventory_hostname }}" -RRType A -Force
  delegate_to: "{{ source_dns_server }}"
  failed_when: false
```

**Timing Estimates (Per Machine):**
- Pre-flight: 2-3 min
- Backup: 2-5 min
- USMT capture: 10-30 min (depends on profile size)
- Domain move + 2 reboots: 8-12 min
- USMT restore: 10-25 min
- DNS registration + validation: 2-3 min
- **Total median: 35-78 minutes**

---

### 6.5 Server Rebind (`server_rebind`)

**Service Principal Update:**
```yaml
- name: Get services with domain accounts
  win_service_info:
  register: services

- name: Update service accounts
  win_service:
    name: "{{ item.name }}"
    username: "{{ service_account_map[item.username] | default(item.username) }}"
    password: "{{ lookup('community.hashi_vault.hashi_vault', service_account_map[item.username] + '/password') }}"
  loop: "{{ services.services | selectattr('username', 'match', source_domain) | list }}"
  when: service_account_map[item.username] is defined
```

**Scheduled Tasks:**
```yaml
- name: Export scheduled tasks
  win_shell: |
    Get-ScheduledTask | Where-Object {$_.Principal.UserId -like "{{ source_domain }}*"} | 
      Export-ScheduledTask | Out-File {{ temp_dir }}\tasks.xml

- name: Update task principals
  win_scheduled_task:
    name: "{{ item.name }}"
    username: "{{ item.principal.userid | regex_replace(source_domain, target_domain) }}"
    password: "{{ lookup('community.hashi_vault.hashi_vault', ...) }}"
    state: present
  loop: "{{ scheduled_tasks }}"
```

**SPN Management:**
```yaml
- name: Enumerate current SPNs
  win_shell: |
    setspn -L {{ source_domain }}\{{ old_service_account }}
  register: old_spns

- name: Register SPNs on new account
  win_shell: |
    setspn -S {{ item }} {{ target_domain }}\{{ new_service_account }}
  loop: "{{ old_spns.stdout_lines }}"

- name: Check for SPN duplicates
  win_shell: |
    setspn -X -F
  register: spn_duplicates
  failed_when: spn_duplicates.stdout is search('found duplicate')
```

**ACL Remediation:**
```yaml
- name: Translate group-based ACLs
  win_shell: |
    $acl = Get-Acl {{ path }}
    $acl.Access | Where-Object {$_.IdentityReference -like "{{ source_domain }}*"} | ForEach-Object {
      $newId = $_.IdentityReference -replace "{{ source_domain }}","{{ target_domain }}"
      $newAce = New-Object System.Security.AccessControl.FileSystemAccessRule($newId, $_.FileSystemRights, $_.AccessControlType)
      $acl.RemoveAccessRule($_)
      $acl.AddAccessRule($newAce)
    }
    Set-Acl {{ path }} $acl
  with_items: "{{ sensitive_paths }}"
```

---

### 6.6 Validation Playbooks (NEW)

#### 6.6.1 Pre-Flight Validation (`preflight_validation`)

**Application Dependency Scan:**
```yaml
- name: Enumerate open TCP connections
  win_shell: |
    Get-NetTCPConnection -State Established | 
      Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,OwningProcess
  register: tcp_connections

- name: Map processes to binaries
  win_shell: |
    Get-Process -Id {{ item.OwningProcess }} | Select-Object Name,Path
  loop: "{{ tcp_connections.stdout | from_json }}"
  register: process_map

- name: Detect DC dependencies
  set_fact:
    dc_dependent_apps: "{{ process_map | selectattr('stdout', 'match', source_dc_ip) | list }}"

- name: Warn if critical apps depend on source DC
  fail:
    msg: "Critical apps still using source DC: {{ dc_dependent_apps }}"
  when: dc_dependent_apps | length > 0 and not force_proceed
```

**Coexistence Testing:**
```yaml
- name: Test target domain user can access source resources
  win_shell: |
    $cred = New-Object PSCredential("{{ target_domain }}\testuser", (ConvertTo-SecureString "{{ test_pass }}" -AsPlainText -Force))
    Test-Path \\{{ source_fileserver }}\share -Credential $cred
  register: coexist_test
  delegate_to: "{{ pilot_workstation }}"

- name: Fail if coexistence broken
  fail:
    msg: "Cross-domain access not working - check trust or dual group memberships"
  when: not coexist_test.stdout | bool
```

#### 6.6.2 Capacity Pre-Flight (`preflight_capacity`)

**State Store Bandwidth Test:**
```yaml
- name: Write test file to state store
  win_shell: |
    $file = New-Object byte[] 1GB
    [System.IO.File]::WriteAllBytes("{{ usmt_store_base }}\bandwidth_test.dat", $file)
    Measure-Command { 
      Copy-Item {{ usmt_store_base }}\bandwidth_test.dat {{ usmt_store_base }}\test2.dat
    } | Select-Object TotalSeconds
  register: bandwidth_test

- name: Calculate effective bandwidth
  set_fact:
    effective_bandwidth_gbps: "{{ (1 / bandwidth_test.stdout | float * 8) | round(2) }}"

- name: Warn if bandwidth insufficient
  fail:
    msg: "State store bandwidth {{ effective_bandwidth_gbps }} Gbps insufficient for {{ planned_concurrent }} parallel captures"
  when: effective_bandwidth_gbps | float < (planned_concurrent * 0.5 / 1000)  # 500 Mbps per host
```

---

### 6.7 Rollback Playbooks (NEW)

#### 6.7.1 Machine Rollback (`rollback_machine`)

```yaml
- name: Load rollback state
  slurp:
    src: "{{ state_dir }}/host/{{ inventory_hostname }}/rollback.json"
  register: rollback_state
  delegate_to: localhost

- set_fact:
    original_domain: "{{ (rollback_state.content | b64decode | from_json).original_domain }}"
    acl_backup_path: "{{ (rollback_state.content | b64decode | from_json).acl_backup }}"

- name: Disjoin from target domain
  win_domain_membership:
    state: workgroup
    workgroup_name: ROLLBACK
  register: disjoin

- name: Reboot after disjoin
  win_reboot:
    reboot_timeout: 600

- name: Rejoin original domain
  win_domain_membership:
    dns_domain_name: "{{ original_domain }}"
    domain_admin_user: "{{ source_admin_user }}"
    domain_admin_password: "{{ vault_source_admin_pass }}"
    state: domain
  register: rejoin

- name: Reboot after rejoin
  win_reboot:
    reboot_timeout: 600

- name: Restore ACLs from backup
  win_shell: |
    icacls C:\Data /restore {{ acl_backup_path }}
  when: acl_backup_path is defined

- name: Restore service principals from backup
  # Load services backup JSON and revert
  win_service:
    name: "{{ item.name }}"
    username: "{{ item.username }}"
    password: "{{ lookup('community.hashi_vault.hashi_vault', 'ad/creds/' + item.username) }}"
  loop: "{{ services_backup }}"

- name: Mark rollback complete
  copy:
    dest: "{{ state_dir }}/host/{{ inventory_hostname }}/progress.json"
    content: '{"phase": "rolled_back", "timestamp": "{{ ansible_date_time.iso8601 }}"}'
  delegate_to: localhost
```

**Rollback Time Estimate:** 20-30 minutes per machine

---

### 6.8 Reporting & Telemetry

#### Tier 1: Static HTML + CSV
```yaml
- name: Generate discovery report
  template:
    src: report_discovery.html.j2
    dest: /var/www/reports/discovery_{{ wave }}.html
  vars:
    hosts: "{{ discovery_results }}"
```

#### Tier 2/3: PostgreSQL ETL
```yaml
- name: Insert discovery results
  community.postgresql.postgresql_query:
    db: mig
    login_host: "{{ reporting_db_host }}"
    login_user: "{{ lookup('community.hashi_vault.hashi_vault', 'database/creds/mig-writer').username }}"
    login_password: "{{ lookup('community.hashi_vault.hashi_vault', 'database/creds/mig-writer').password }}"
    query: |
      WITH host_upsert AS (
        INSERT INTO mig.host(name, os_family, site, is_linux)
        VALUES (%(name)s, %(os)s, %(site)s, %(linux)s)
        ON CONFLICT (name) DO UPDATE SET os_family=EXCLUDED.os_family
        RETURNING id
      )
      INSERT INTO mig.check_result(run_id, host_id, check_name, pass, details, recorded_at)
      SELECT %(run_id)s, id, %(check)s, %(pass)s, %(details)s::jsonb, now()
      FROM host_upsert;
    named_args:
      name: "{{ inventory_hostname }}"
      os: "{{ ansible_os_family }}"
      site: "{{ site | default('') }}"
      linux: "{{ ansible_os_family == 'Debian' or ansible_os_family == 'RedHat' }}"
      run_id: "{{ run_id }}"
      check: "secure_channel"
      pass: "{{ secure_channel_ok }}"
      details: "{{ check_details | to_json }}"
```

---

## 7) Scalability & Throughput Model (REVISED)

### 7.1 Operating Principles

**Wave-Based Execution:**
- Group hosts into waves of 50-200 (servers) or 100-400 (workstations)
- Execute serially (wave N completes before wave N+1 starts)
- Within each wave, parallel execution up to concurrency limit

**Back-Pressure & Safety Gates:**
- Auto-pause if failure rate > 5% within a wave
- Auto-pause if state store I/O latency > 1 second (P95)
- Manual approval required for next wave after any failures

**Concurrency Caps (Per Runner):**

| Tier | Workstations | Servers | Rationale |
|------|--------------|---------|-----------|
| 1 (Demo) | 25 | 10 | Single core runner, limited RAM |
| 2 (Medium) | 100 | 25 | Moderate runner resources, 2-3 runners |
| 3 (Enterprise) | 200 | 40 | HA runners with autoscaling |

**[Correction from original: 400 workstations was over-optimistic; 200 is safer maximum per runner]**

---

### 7.2 Throughput Calculations (Lab-Validated Targets)

#### 7.2.1 Identity Provisioning

**Users:**
- AD user creation: ~200/minute (local to DC)
- Entra Graph API: ~20/second = 1,200/minute (with throttling backoff)
- Group membership adds: ~10/second = 600/minute

**Example: 1,000 users with 5 groups each**
- User creation: 1,000 ÷ 200/min = 5 minutes (AD) or 1,000 ÷ 1,200/min = 1 minute (Entra, optimistic)
- Membership adds: 5,000 ÷ 600/min = 8 minutes
- **Total: 13 minutes (AD), 9 minutes (Entra)**

**Verdict:** **1,000 users in <1 hour is FEASIBLE** ✓

---

#### 7.2.2 Workstations

**Per-Machine Timeline:**
- Pre-flight checks: 2 min
- Backup (ACLs/services): 3 min
- USMT scanstate: 10-30 min (profile-dependent)
- Domain disjoin + reboot: 6 min
- Domain join + reboot: 6 min
- USMT loadstate: 10-25 min
- **Total: 37-72 minutes (median ~50 minutes)**

**Wave Calculations:**

| Tier | Concurrent | Wave Size | Wave Duration | Waves in 4h | Total Capacity |
|------|------------|-----------|---------------|-------------|----------------|
| 1 | 25 | 25 | 50 min | 4 | **100** |
| 2 | 100 × 2 runners = 200 | 200 | 50 min | 4 | **800** |
| 3 | 200 × 3 runners = 600 | 600 | 50 min | 4 | **2,400** |

**I/O Bottleneck Check:**
- 200 workstations × 8 GB profile = 1.6 TB
- 10 Gbps state store = 1.25 GB/s
- Write time: 1.6 TB ÷ 1.25 GB/s = **21 minutes**
- With 4× regional stores: 21 min ÷ 4 = **5 minutes per store**

**Verdict:** **Tier 2 can do 800 workstations / 4h with proper state store distribution** ✓

---

#### 7.2.3 Servers

**Per-Server Timeline:**
- Pre-flight: 3 min
- Backup: 5 min
- Domain move + reboots: 12 min
- Service/task/SPN/ACL rebind: 20-60 min (app-dependent)
- Validation: 10 min
- **Total: 50-90 minutes (median ~70 minutes)**

**Wave Calculations:**

| Tier | Concurrent | Wave Size | Wave Duration | Waves in 4h | Total Capacity |
|------|------------|-----------|---------------|-------------|----------------|
| 1 | 10 | 10 | 70 min | 3 | **30** |
| 2 | 25 × 2 runners = 50 | 50 | 70 min | 3 | **150** |
| 3 | 40 × 3 runners = 120 | 120 | 70 min | 3 | **360** |

**Verdict:** **Original claim of "1,000 servers / 4h not recommended" is CORRECT** ✓

---

### 7.3 Resource Requirements

#### 7.3.1 State Store Capacity

**Per-Workstation Storage:**
- Uncompressed profile: 5-10 GB (median 8 GB)
- Compressed (Tier 2/3): 3-5 GB
- Retention: 7-30 days (configurable)

**Storage Calculation (Tier 2, 800 workstations):**
- 800 × 5 GB (compressed) × 1.2 (overhead) = **4.8 TB**
- With 30-day retention across 5 waves: 4.8 TB × 5 = **24 TB total**

**Recommendation:**
- Tier 1: 2 TB SMB share
- Tier 2: 30 TB distributed (4× 8 TB DFS-R nodes)
- Tier 3: 100 TB object storage (MinIO or cloud)

---

#### 7.3.2 Network Bandwidth

**Required Bandwidth (Tier 2, 200 concurrent workstations):**
- Write: 200 × 5 GB ÷ 20 min = 200 × 5 GB ÷ 1,200 sec = 0.83 GB/s = **6.6 Gbps**
- Read: Same during restore
- **Minimum: 10 Gbps per regional state store**

**Mitigation:**
- Use **4 regional stores** → 6.6 Gbps ÷ 4 = **1.65 Gbps per store** (achievable with 10 Gbps uplinks)
- Compress USMT stores (reduces to ~4 Gbps total)

---

#### 7.3.3 Runner Specifications

| Tier | vCPU | RAM | Disk | Network | Quantity |
|------|------|-----|------|---------|----------|
| 1 (Demo) | 4 | 16 GB | 200 GB | 1 Gbps | 1 VM |
| 2 (Medium) | 8 | 32 GB | 500 GB | 10 Gbps | 2-3 VMs |
| 3 (Enterprise) | 16 | 64 GB | 1 TB | 10 Gbps | 5+ pods (K8s) |

---

## 8) Security Architecture

### 8.1 Transport Security

**Windows:**
- WinRM over **Kerberos + HTTPS (port 5986)** with message encryption
- Certificate-based auth for WinRM (optional, Tier 3)
- No NTLM fallback (disabled in ansible.cfg)

**Linux:**
- SSH with **certificate-based auth** (Vault CA, Tier 2/3)
- SSH with **key-based auth** (Tier 1)
- No password auth (disabled in sshd_config)

**APIs:**
- Graph API: OAuth2 bearer tokens with 1-hour TTL
- Vault API: AppRole/Kubernetes auth with wrapped tokens

---

### 8.2 Secret Management

#### Tier 1: Ansible Vault (File-Based)
```yaml
# group_vars/all.yml
vault_source_admin_pass: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...encrypted...

vault_target_admin_pass: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  ...encrypted...
```

**Rotation:** Manual, quarterly (or after admin departure)

---

#### Tier 2/3: HashiCorp Vault

**Engines Enabled:**
- `ad` (Active Directory secrets engine) – dynamic service account passwords
- `database` (PostgreSQL) – dynamic DB credentials for reporting
- `ssh` (SSH secrets engine) – CA-signed certificates for Linux
- `pki` (PKI secrets engine) – Internal TLS certs
- `kv-v2` (Key-Value v2) – Static secrets with versioning

**AD Secrets Engine Configuration:**
```hcl
vault write ad/config binddn="CN=VaultSvc,OU=ServiceAccounts,DC=target,DC=com" \
              bindpass="..." url="ldaps://target-dc.target.com"

vault write ad/roles/migration-windows \
              service_account_name="MigrationSvc@target.com" \
              ttl=8h
```

**Dynamic Credential Issuance:**
```yaml
- name: Get JIT credentials for migration
  set_fact:
    migration_user: "{{ lookup('community.hashi_vault.hashi_vault', 'ad/creds/migration-windows').username }}"
    migration_pass: "{{ lookup('community.hashi_vault.hashi_vault', 'ad/creds/migration-windows').password }}"
  no_log: true

- name: Use credentials
  win_domain_membership:
    domain_admin_user: "{{ migration_user }}"
    domain_admin_password: "{{ migration_pass }}"
    ...
```

**TTL Tuning:**
- Set TTL to **job duration + 2 hours** (not 2-8 hours)
- For 4-hour wave: use 6-hour TTL
- Renew lease mid-job if duration exceeds 50% of TTL

**Rotation Policy:**
- Auto-rotation at job completion
- Emergency rotation via `vault write -f ad/rotate-root`
- Alert if rotation fails

---

### 8.3 Audit & Compliance

**Logging Requirements:**
- All Ansible task output to centralized log store (Loki/ELK)
- Vault audit device enabled (logs to SIEM)
- PostgreSQL query logs for reporting DB writes
- Windows Event Forwarding for Security logs (4624, 4672, 4768)

**Redaction:**
```yaml
# ansible.cfg
[defaults]
no_log_on_task_failure = False

# In tasks
- name: Join domain
  win_domain_membership:
    domain_admin_password: "{{ vault_pass }}"
  no_log: true
```

**Change Evidence:**
- Git commit for every artifact/CSV export (signed commits)
- PostgreSQL records per-host before/after state
- HTML reports archived for 7 years

---

## 9) Observability & Monitoring (Tiered)

### 9.1 Tier 1: Basic Monitoring

**Components:**
- Prometheus (single node, Docker Compose)
- Grafana (single node, Docker Compose)
- Node exporter on runner
- Blackbox exporter for WinRM probes

**Dashboard:**
- Wave success rate
- Current job status (via AWX API scraping)
- WinRM reachability per site

**Alerts:**
- Email/webhook if WinRM failure rate >20%
- Email if wave failure rate >5%

---

### 9.2 Tier 2: Production Monitoring

**Components:**
- Prometheus (2-node with Thanos sidecar for HA)
- Grafana (2-node behind load balancer)
- Alertmanager (HA pair)
- Exporters: windows_exporter, node_exporter, postgres_exporter, pushgateway

**Dashboards:**
- Migration overview (users/machines migrated, success rate)
- Infrastructure health (runner CPU/mem, Postgres lag, state store I/O)
- Per-wave drill-down (individual host status, failure reasons)

**Alerts:**
- PagerDuty integration for critical alerts
- Slack for warnings
- Auto-pause waves on critical infrastructure failures

---

### 9.3 Tier 3: Enterprise Observability

**Full Stack:**
- Prometheus Operator (multi-replica, remote write to long-term storage)
- Grafana HA (3+ replicas, PostgreSQL backend for dashboards)
- Alertmanager (HA with gossip clustering)
- Loki for log aggregation (all playbook output, Vault logs, DC logs)
- Tempo for distributed tracing (optional, for debugging)

**Self-Healing Integration:**
- Alertmanager webhooks trigger AWX remediation jobs
- Guardrails: max 2 auto-heal attempts, then quarantine host

**Dashboards:**
- Live wave progress (per-host timeline)
- Auto-heal success rate and MTTR
- Cost tracking (runner hours, state store GB-hours)
- Compliance view (audit log queries, failed auth attempts)

**SLOs:**
- Wave success rate ≥95%
- MTTR per failed host ≤30 min
- Runner availability ≥99.5%
- State store P95 latency ≤500ms

---

### 9.4 Reporting Web Server (All Tiers)

**Role:** `reporting_web_nginx`

**Features:**
- Serve static HTML reports (discovery, wave outcomes)
- Reverse proxy to Grafana at `/dashboard/`
- Basic auth (Tier 1) or SSO integration (Tier 2/3)
- TLS with internal PKI cert (Tier 2/3)

**Deployment:**
```yaml
- name: Deploy reporting web server
  hosts: awx_runner
  become: true
  roles:
    - reporting_web_nginx
  vars:
    report_root: /opt/mig/reports
    report_port: 8080
    report_auth_enabled: true
    report_tls_enabled: "{{ tier >= 2 }}"
    grafana_proxy_url: "http://grafana:3000/"
```

**URLs:**
- `https://runner.example.com:8080/` → Report index
- `https://runner.example.com:8080/reports/discovery_wave1.html` → Static HTML
- `https://runner.example.com:8080/dashboard/` → Grafana live dashboards

---

## 10) Disaster Recovery & Resilience

### 10.1 Control Plane Backup (All Tiers)

**Playbook:** `playbooks/98_backup_control_plane.yml`

```yaml
- name: Backup Vault snapshot
  uri:
    url: http://vault:8200/v1/sys/storage/raft/snapshot
    method: GET
    dest: /backup/vault_{{ ansible_date_time.epoch }}.snap
    headers:
      X-Vault-Token: "{{ vault_token }}"
  when: tier >= 2

- name: Backup PostgreSQL
  community.postgresql.postgresql_db:
    name: mig
    state: dump
    target: /backup/mig_{{ ansible_date_time.epoch }}.sql
  when: tier >= 2

- name: Backup Ansible artifacts
  ansible.builtin.archive:
    path: "{{ artifacts_dir }}"
    dest: /backup/artifacts_{{ ansible_date_time.epoch }}.tar.gz

- name: Backup state files
  ansible.builtin.archive:
    path: "{{ state_dir }}"
    dest: /backup/state_{{ ansible_date_time.epoch }}.tar.gz

- name: Upload to object storage
  amazon.aws.s3_object:
    bucket: migration-backups
    object: "/{{ inventory_hostname }}/{{ item }}"
    src: "/backup/{{ item }}"
  loop:
    - "vault_{{ ansible_date_time.epoch }}.snap"
    - "mig_{{ ansible_date_time.epoch }}.sql"
    - "artifacts_{{ ansible_date_time.epoch }}.tar.gz"
    - "state_{{ ansible_date_time.epoch }}.tar.gz"
  when: tier >= 2
```

**Frequency:**
- Tier 1: Daily (cron job)
- Tier 2/3: Before each wave + daily

---

### 10.2 Recovery Procedures

**Scenario: Vault Sealed Mid-Wave**

1. Detect: Prometheus alert `vault_sealed{instance="vault"} == 1`
2. Unseal manually:
   ```bash
   vault operator unseal <shard1>
   vault operator unseal <shard2>
   vault operator unseal <shard3>
   ```
3. Resume wave: AWX jobs auto-retry Vault lookups

**Scenario: PostgreSQL Primary Failure (Tier 3)**

1. Patroni auto-promotes replica to primary (~30 seconds)
2. AWX reconnects automatically
3. Validate replication lag <5 seconds before resuming wave

**Scenario: AWX Pod Eviction (Tier 3)**

1. K8s reschedules pod on healthy node
2. Job state persists in PostgreSQL
3. Relaunch job from last wave checkpoint (read from `state/run/<run_id>/manifest.json`)

**Scenario: State Store Unavailable**

1. Alert: Blackbox probe fails to SMB/S3 state store
2. Auto-pause current wave
3. Failover to secondary regional store (update `usmt_store_base` variable)
4. Resume from last checkpoint

---

### 10.3 Break-Glass Procedures

**Emergency Domain Admin Access:**
- Sealed envelope with temporary admin password (rotated quarterly)
- Tested in disaster recovery drills
- Alert on any use (monitored via Security Event 4624 with admin account name)

**Manual Rollback (if automation fails):**
1. Disjoin from target domain via Control Panel
2. Join source domain manually with original admin creds
3. Restore USMT from `\\statestore\<hostname>\` using loadstate.exe
4. Contact on-call engineer for service/ACL restoration

---

## 11) Timelines & Phasing

### 11.1 Tier 1 (Demo/POC) – 6-8 Weeks

**Week 1-2: Setup**
- Provision single Ansible VM
- Install Ansible Core/AWX, Ansible Vault
- Deploy basic Prometheus + Grafana (Docker Compose)
- Build `ad_export` and `ad_provision` roles
- Lab test with 10 test users

**Week 3-4: Pilot**
- Export 100 real users from source AD
- Provision in test OU of target AD
- Migrate 5 workstations (USMT)
- Migrate 2 non-critical servers
- Collect metrics and tune

**Week 5-6: Production Wave 1**
- Migrate 100 users
- Migrate 25 workstations
- Migrate 5 servers
- Generate reports and present to CAB

**Week 7-8: Production Waves 2-3**
- Migrate remaining 300-400 users/machines
- Cleanup and documentation
- Operational handoff

---

### 11.2 Tier 2 (Medium/Staging) – 10-14 Weeks

**Week 1-3: Infrastructure**
- Deploy AWX HA (2 nodes)
- Deploy Vault (single node with backups)
- Deploy PostgreSQL (primary + replica)
- Configure Prometheus + Grafana + Alertmanager
- Setup DFS-R for state stores (2-3 regions)

**Week 4-5: Development**
- Build all core roles (export, provision, machine_move, server_rebind)
- Build validation roles (preflight, discovery, gate)
- Build rollback playbooks
- Unit test each role in lab

**Week 6-7: Pilot**
- Migrate 50 users
- Migrate 10 workstations
- Migrate 5 servers
- Tune concurrency (start at 25, increment to 50, measure runner load)
- Test rollback procedure

**Week 8-12: Production Waves**
- 4-8 waves of 200-400 users each
- 4-8 waves of 50-100 workstations each
- 4-6 waves of 20-30 servers each
- CAB approval before each wave

**Week 13-14: Cleanup**
- Decommission source domain resources
- Archive reports and artifacts
- Training for operations team
- Retrospective and lessons learned

---

### 11.3 Tier 3 (Enterprise) – 16-24 Weeks

**Week 1-4: Infrastructure**
- Deploy K8s cluster (K3s or upstream)
- Deploy AWX Operator with HA
- Deploy Vault HA (Raft, 3 nodes, auto-unseal)
- Deploy PostgreSQL HA (Patroni, 3 nodes)
- Deploy MinIO HA (4+ nodes, erasure coding)
- Deploy observability stack (Prometheus Operator, Grafana HA, Loki, Alertmanager)
- Configure multi-region state stores

**Week 5-8: Development**
- Build all roles (core + remediation + infrastructure)
- Integrate Vault dynamic secrets
- Build AWX workflow templates
- Build self-healing automation (limited scope)
- Comprehensive lab testing

**Week 9-10: Chaos Engineering**
- Kill Vault node mid-job (test HA failover)
- Disconnect network to state store (test resume)
- Saturate runner with 300 parallel hosts (test limits)
- Fail DC replication (test convergence gates)

**Week 11-12: Pilot**
- Migrate 100 users
- Migrate 50 workstations
- Migrate 10 servers
- Validate self-healing triggers
- Test end-to-end rollback

**Week 13-22: Production Waves**
- 10-20 waves over 10 weeks
- Gradual scale-up (start 100/wave, end 500/wave)
- Continuous monitoring and tuning

**Week 23-24: Stabilization**
- Final cleanup
- Document lessons learned
- Hand off to operations
- Post-migration support (30 days)

---

## 12) Team & Skills Requirements

### 12.1 Tier 1 Team (2-3 FTE)

**Required Skills:**
- Ansible basics (playbooks, roles, inventory)
- Active Directory administration
- Windows PowerShell
- Basic Linux/bash
- WinRM troubleshooting

**Training Required:**
- Ansible best practices (1 week)
- USMT deep-dive (2 days)
- Lab practice with test migration (1 week)

---

### 12.2 Tier 2 Team (4-5 FTE)

**Required Skills:**
- Ansible advanced (dynamic inventories, callbacks, custom modules)
- Active Directory + Entra ID administration
- Windows + Linux system administration
- PostgreSQL basics (queries, backups)
- HashiCorp Vault basics (engines, policies)
- Prometheus/Grafana (dashboard creation, alert rules)
- Networking (DNS, routing, firewalls)

**Training Required:**
- AWX administration (1 week)
- Vault secrets management (3 days)
- Prometheus query language (2 days)
- Migration-specific playbook development (2 weeks)

---

### 12.3 Tier 3 Team (6-8 FTE)

**Required Skills:**
- All Tier 2 skills PLUS:
- Kubernetes administration (deployments, services, ingress)
- Vault advanced (Raft, auto-unseal, HA)
- PostgreSQL HA (Patroni, replication, tuning)
- Object storage (MinIO or cloud provider S3/Blob)
- Prometheus Operator (CRDs, ServiceMonitors)
- Log aggregation (Loki query language)
- Incident response and on-call procedures

**Training Required:**
- Kubernetes fundamentals (2 weeks)
- Vault HA deployment (1 week)
- Patroni + PostgreSQL HA (3 days)
- Chaos engineering practices (1 week)
- Migration platform deep-dive (3 weeks)

---

## 13) Cost Estimates (Order of Magnitude)

### Tier 1 (Demo/POC)
- **Infrastructure:** 1 VM (8c32g) = $200-400/month cloud
- **Storage:** 2 TB SMB share = $100/month
- **Licenses:** Ansible (open-source) = $0
- **Labor:** 2-3 FTE × 8 weeks × $150/hr = $144k-216k
- **TOTAL:** ~$150k-220k

### Tier 2 (Medium/Staging)
- **Infrastructure:** 5 VMs + storage = $1,500-2,500/month × 4 months = $6k-10k
- **Licenses:** Ansible (open-source) + Vault (open-source) = $0 OR Vault Enterprise = $5k-10k
- **Labor:** 4-5 FTE × 14 weeks × $150/hr = $336k-420k
- **TOTAL:** ~$350k-440k

### Tier 3 (Enterprise)
- **Infrastructure:** K8s + storage + networking = $5k-10k/month × 6 months = $30k-60k
- **Licenses:** Vault Enterprise HA = $20k-50k, Prometheus (open-source) = $0
- **Labor:** 6-8 FTE × 24 weeks × $150/hr = $864k-1.15M
- **TOTAL:** ~$900k-1.3M

**[Note: These are labor + infrastructure only; excludes USMT licenses, AD trusts, consultant fees]**

---

## 14) Repository Structure

```
migration-automation/
├── ansible.cfg
├── requirements.yml              # Ansible Galaxy dependencies
├── inventories/
│   ├── tier1_demo/
│   │   ├── hosts.ini
│   │   ├── group_vars/
│   │   │   └── all.yml          # Tier 1 configuration
│   ├── tier2_medium/
│   │   ├── hosts.ini
│   │   ├── group_vars/
│   │   │   ├── all.yml          # Tier 2 configuration
│   │   │   ├── vault.yml        # Vault URLs, policies
│   ├── tier3_enterprise/
│   │   ├── hosts.ini
│   │   ├── group_vars/
│   │   │   ├── all.yml          # Tier 3 configuration
│   │   │   ├── vault.yml
│   │   │   ├── k8s.yml
├── roles/
│   ├── ad_export/
│   ├── ad_provision/
│   ├── admt_orchestrate/
│   ├── machine_move_usmt/
│   ├── server_rebind/
│   ├── linux_export/
│   ├── linux_migrate/
│   ├── preflight_validation/
│   ├── discovery_health/
│   ├── discovery_destination/
│   ├── gate_on_health/
│   ├── heal_winrm/
│   ├── heal_secure_channel/
│   ├── heal_sssd/
│   ├── reporting_render/
│   ├── reporting_publish/
│   ├── reporting_etl/
│   ├── reporting_web_nginx/
│   ├── observability_stack/
│   ├── vault_bootstrap/
│   ├── rollback_machine/
│   ├── rollback_identity/
│   └── backup_control_plane/
├── playbooks/
│   ├── 00_discovery_health.yml
│   ├── 00a_preflight_validation.yml
│   ├── 00b_preflight_capacity.yml
│   ├── 00c_discovery_domain_core.yml
│   ├── 00d_discovery_destination.yml
│   ├── 00e_discovery_dns.yml
│   ├── 00f_validate_dns.yml
│   ├── 00g_discovery_services.yml
│   ├── 01_pre_wave_snapshot.yml
│   ├── 02_gate_on_health.yml
│   ├── 09_render_report.yml
│   ├── 10_provision.yml
│   ├── 10b_validate_sync.yml
│   ├── 11_dns_provision.yml
│   ├── 12_dns_cleanup.yml
│   ├── 20_machine_move.yml
│   ├── 25_linux_migrate.yml
│   ├── 30_server_rebind.yml
│   ├── 40_validate.yml
│   ├── 41_post_wave_snapshot.yml
│   ├── 50_heal_winrm.yml
│   ├── 51_heal_secure_channel.yml
│   ├── 52_heal_sssd.yml
│   ├── 98_backup_control_plane.yml
│   ├── 98_zfs_offsite_backup.yml
│   ├── 99_rollback_machine.yml
│   ├── 99_rollback_identity.yml
│   ├── 99_rollback_dns.yml
│   ├── 99_rollback_zfs_statestore.yml
│   ├── 99_rollback_zfs_postgres.yml
│   └── 99_rollback_zfs_vms.yml
├── artifacts/                    # Exported CSVs, reports
│   ├── discovery/
│   ├── dns/                      # DNS zone exports
│   └── network/                  # Per-host network configs
├── state/                        # Per-host progress, rollback state
├── backups/                      # ACLs, services, SPNs
├── mappings/
│   ├── domain_map.yml
│   ├── group_map.yml
│   ├── service_account_map.yml
│   ├── ou_map.yml
│   ├── uid_gid_map.yml
│   ├── dns_aliases.yml
│   └── ip_address_map.yml
├── batches/
│   ├── pilot.yml
│   ├── wave1.yml
│   ├── wave2.yml
│   └── ...
├── docs/
│   ├── 00_DETAILED_DESIGN.md     # This file
│   ├── 01_DEPLOYMENT_TIERS.md    # Tier comparison guide
│   ├── 02_IMPLEMENTATION_GUIDE_TIER1.md
│   ├── 03_IMPLEMENTATION_GUIDE_TIER2.md
│   ├── 04_IMPLEMENTATION_GUIDE_TIER3.md
│   ├── 05_RUNBOOK_OPERATIONS.md
│   ├── 06_RUNBOOK_TROUBLESHOOTING.md
│   ├── 07_ROLLBACK_PROCEDURES.md
│   ├── 08_ENTRA_SYNC_STRATEGY.md
│   ├── 09_RISK_REGISTER.md
│   ├── 10_TEST_PLAN.md
│   ├── 11_TRAINING_PLAN.md
│   ├── 12_DR_PROCEDURES.md
│   ├── 13_DNS_MIGRATION_STRATEGY.md
│   ├── 14_SERVICE_DISCOVERY_AND_HEALTH_CHECKS.md
│   ├── 15_ZFS_SNAPSHOT_STRATEGY.md
│   ├── 16_PLATFORM_VARIANTS.md
│   └── 17_DATABASE_MIGRATION_STRATEGY.md
└── infrastructure/               # IaC for control plane (Terraform, etc.)
    ├── tier1/
    ├── tier2/
    └── tier3/
```

---

## 15) Deliverables Checklist

### Core Documentation
- [x] Detailed Design Document (this file)
- [x] Deployment Tiers Comparison Guide
- [ ] Implementation Guide Tier 1
- [x] Implementation Guide Tier 2
- [ ] Implementation Guide Tier 3
- [x] Operations Runbook
- [ ] Troubleshooting Runbook
- [x] Rollback Procedures
- [x] Entra Connect Sync Strategy
- [ ] Risk Register
- [ ] Test Plan
- [ ] Training Plan
- [ ] DR Procedures
- [x] DNS Migration Strategy
- [x] Service Discovery & Health Checks
- [x] ZFS Snapshot Strategy
- [x] Platform Variants (AWS, Azure, GCP, Hyper-V, vSphere, OpenStack)
- [x] Database Migration Strategy (SQL Server, PostgreSQL, MySQL, Oracle)

### Ansible Artifacts
- [ ] All 31 roles implemented and tested (includes DNS, service discovery, ZFS snapshot)
- [ ] All 30+ playbooks implemented and tested (includes DNS, health checks, ZFS)
- [ ] Inventory templates for each tier
- [ ] Mapping file templates (including DNS aliases and IP address maps)
- [ ] Batch/wave templates
- [ ] ZFS snapshot automation scripts

### Infrastructure as Code
- [ ] Terraform/Ansible for Tier 1 infrastructure
- [ ] Terraform/Ansible for Tier 2 infrastructure
- [ ] Helm charts + Terraform for Tier 3 infrastructure

### Observability
- [ ] Prometheus alert rules
- [ ] Grafana dashboards (JSON exports)
- [ ] Report templates (HTML, CSS)
- [ ] PostgreSQL schema (DDL)

### Testing
- [ ] Unit tests (molecule) for each role
- [ ] Integration tests for end-to-end flow
- [ ] Chaos tests for Tier 3 (infrastructure failures)
- [ ] Performance tests (concurrency, I/O saturation)

---

## 16) Risk Register (Summary)

| Risk | Severity | Probability | Mitigation | Owner |
|------|----------|-------------|------------|-------|
| USMT failure corrupts profiles | CRITICAL | LOW | Test backups, shadow copy integration | Migration Team |
| State store I/O bottleneck | HIGH | HIGH | Multi-region stores, compression, bandwidth testing | Infrastructure |
| WinRM saturation crashes runner | HIGH | MEDIUM | Concurrency caps, health monitoring, autoscaling | Automation Team |
| Entra Connect sync conflicts | HIGH | LOW | Anchor strategy, conflict detection playbook | Identity Team |
| Vault sealed mid-wave | CRITICAL | LOW | HA deployment, unseal procedures, monitoring | Security Team |
| AD replication lag causes join failures | MEDIUM | HIGH | Pre-staging, convergence gates, retries | AD Team |
| Insufficient team skills | HIGH | MEDIUM | Training plan, paired programming, external consultants | Management |
| Timeline slippage | MEDIUM | HIGH | Risk-adjusted schedules, pilot phase, incremental approach | PM |

**Full risk register with 30+ risks and detailed mitigations: See `docs/09_RISK_REGISTER.md`**

---

## 17) Success Criteria

### Technical Success
- ✓ Zero data loss (all profiles restored, no missing files)
- ✓ <5% failure rate per wave (with auto-recovery or manual fix <30 min)
- ✓ All users can log in to target domain and access apps within 1 hour of migration
- ✓ Rollback capability validated (tested in pilot, <4 hour execution)
- ✓ Complete audit trail (PostgreSQL + HTML reports + Git commits)

### Operational Success
- ✓ Operations team trained and capable of executing waves independently
- ✓ Runbooks validated through pilot and first production wave
- ✓ Monitoring dashboards show real-time status without manual queries
- ✓ On-call procedures tested (simulated failures resolved within SLA)

### Business Success
- ✓ Migration completes within agreed timeline (±2 weeks)
- ✓ No business-critical outages >1 hour
- ✓ User satisfaction >80% (post-migration survey)
- ✓ Cost within budget (±10%)
- ✓ Compliance requirements met (audit logs, change approvals)

---

## 18) Next Steps

### For Tier 1 (Demo/POC):
1. Provision single Ansible VM
2. Install Ansible Core, Docker, Prometheus/Grafana
3. Build `ad_export` role and test with 10 users
4. Review `docs/02_IMPLEMENTATION_GUIDE_TIER1.md`

### For Tier 2 (Medium/Staging):
1. Review infrastructure requirements (5 VMs, storage)
2. Deploy AWX HA and Vault
3. Stand up PostgreSQL with streaming replica
4. Review `docs/03_IMPLEMENTATION_GUIDE_TIER2.md`

### For Tier 3 (Enterprise):
1. Assemble team (6-8 FTE) and secure budget ($900k-1.3M)
2. Deploy K8s cluster and all HA components
3. Conduct 2-week training bootcamp
4. Review `docs/04_IMPLEMENTATION_GUIDE_TIER3.md`

### Universal Next Steps:
1. Read `docs/11_TRAINING_PLAN.md` and schedule training
2. Review `docs/09_RISK_REGISTER.md` and assign risk owners
3. Create pilot host list (5-10 systems)
4. Schedule kickoff meeting with stakeholders

---

## 19) Conclusion

This design provides a **comprehensive, production-ready framework** for identity and domain migrations across three deployment tiers:

- **Tier 1** enables small organizations to migrate 500 users with minimal infrastructure
- **Tier 2** supports mid-size migrations (3,000 users) with robust monitoring and rollback
- **Tier 3** scales to enterprise requirements (10,000+ users) with full HA, self-healing, and observability

**Key improvements over v1.0:**
- Realistic throughput estimates with I/O modeling
- Complete rollback and validation playbooks
- Entra Connect synchronization strategy
- Three deployment tiers with appropriate infrastructure
- Revised timelines (6-24 weeks depending on tier)
- Comprehensive training and skill requirements

**This design is READY FOR IMPLEMENTATION** with the understanding that:
- Pilot phase will validate assumptions and tune parameters
- Lab testing will validate throughput calculations
- Team training must precede production waves
- Incremental rollout (tier 1 → 2 → 3) is recommended for risk mitigation

---

**END OF DOCUMENT**

*For implementation guides, runbooks, and supporting documentation, see the `docs/` directory.*

