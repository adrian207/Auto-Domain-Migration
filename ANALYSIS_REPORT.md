# Migration Design Analysis Report
**Date:** October 18, 2025  
**Document:** Ansible-Orchestrated Identity & Domain Migration – Detailed Design  
**Analysis Dimensions:** Completeness, Accuracy, Feasibility

---

## EXECUTIVE SUMMARY

**Overall Assessment:** This is an **ambitious, technically sophisticated design** with strong architectural thinking and comprehensive coverage of migration mechanics. The document demonstrates deep understanding of AD/Entra, Windows automation, and enterprise orchestration patterns.

**Readiness Score:** 6.5/10

**Key Strengths:**
- Comprehensive pathway coverage (4 migration scenarios + Linux)
- Strong security architecture (Vault, JIT credentials, encryption)
- Sophisticated observability and self-healing design
- Wave-based execution with safety gates
- Realistic acknowledgment of USMT/reboot overhead

**Critical Gaps:**
- Missing pre-migration validation playbooks (coexistence testing, app dependency mapping)
- No rollback automation or failure recovery procedures beyond conceptual mentions
- Insufficient detail on Entra Connect synchronization conflicts and anchor strategies
- Missing capacity planning for state store I/O and network bandwidth
- Incomplete Linux domain-join migration details (UID/GID collision handling)
- No disaster recovery procedures for the control plane itself

**Feasibility Concerns:**
- Throughput claims are **optimistic** and lack real-world validation data
- Self-healing complexity may introduce operational burden rather than reduce it
- Infrastructure requirements (HA Vault, Patroni, K8s, Grafana) are enterprise-grade but **operationally demanding**
- 6-7 week timeline for production rollout is **aggressive** given system complexity

---

## 1. COMPLETENESS ANALYSIS

### 1.1 Strong Coverage ✓

**Identity & Access Management:**
- [✓] User/group export and provisioning
- [✓] Group membership translation with mapping files
- [✓] ADMT integration for SIDHistory (optional path)
- [✓] Vault-based secret management with rotation
- [✓] Multiple authentication methods (Kerberos, SSH, certificates)

**Device Migration:**
- [✓] USMT capture/restore mechanics
- [✓] Domain disjoin → workgroup → join workflow
- [✓] Server remediation (services, tasks, SPNs, ACLs)
- [✓] Linux local and domain-joined migration paths
- [✓] Reboot handling with state persistence

**Orchestration & Control:**
- [✓] AWX workflow templates with approval gates
- [✓] Wave-based execution with concurrency caps
- [✓] Batch definitions and blackout window awareness
- [✓] Change freeze detection

**Observability:**
- [✓] PostgreSQL data plane for telemetry
- [✓] Grafana dashboards with live metrics
- [✓] Prometheus + Alertmanager integration
- [✓] HTML reports with sortable tables

**Security:**
- [✓] WinRM over Kerberos with HTTPS enforcement
- [✓] Dynamic credentials from Vault (AD, DB, SSH CA)
- [✓] Audit logging to SIEM
- [✓] Least-privilege service accounts

---

### 1.2 Critical Gaps ⚠

#### 1.2.1 Pre-Migration Validation (Missing Entirely)
**Impact:** HIGH  
**Description:** No playbooks or procedures for:
- Application dependency discovery (which apps talk to which DCs/services?)
- Cross-forest coexistence testing (can users from TARGET domain access SOURCE resources during transition?)
- DNS/certificate validation (will apps break when machine FQDNs change?)
- License compliance checks (are USMT licenses sufficient for scale?)

**Recommendation:**  
Add `playbooks/00a_app_dependency_scan.yml` using tools like:
- Sysinternals ProcMon for file/registry access patterns
- Windows Event Log 4648 (explicit credential usage) for service account discovery
- TCP connection enumeration (`Get-NetTCPConnection`) to map service dependencies

Add `playbooks/00b_coexistence_test.yml`:
- Create pilot users in target domain
- Attempt access to source file shares, SQL servers, web apps
- Validate Kerberos delegation paths
- Document required transitional trusts or dual group memberships

---

#### 1.2.2 Rollback & Failure Recovery (Conceptual Only)
**Impact:** CRITICAL  
**Description:** Section 9.3 mentions rollback but provides no automation:
- No playbook to rejoin old domain after failed migration
- No procedure to restore ACLs from `icacls` backups
- No automated SPN cleanup if migration aborts mid-wave
- USMT "store retained for restore back" but no `loadstate` reverse procedure

**Recommendation:**  
Build `playbooks/99_rollback_machine.yml`:
```yaml
- name: Emergency rollback to source domain
  hosts: "{{ failed_hosts }}"
  tasks:
    - name: Check if target domain joined
      win_domain_membership:
        state: domain
        dns_domain_name: "{{ source_domain }}"
      register: domain_check
      failed_when: false
    
    - name: Disjoin target and rejoin source
      when: domain_check.member_of != source_domain
      win_domain_membership:
        dns_domain_name: "{{ source_domain }}"
        domain_admin_user: "{{ source_admin }}"
        domain_admin_password: "{{ vault_source_admin_pass }}"
        state: domain
      register: rejoin
    
    - name: Restore ACLs from backup
      win_shell: icacls C:\Data /restore C:\MigBackup\acls_{{ inventory_hostname }}.txt
    
    - name: Restore service principals from JSON
      # ... restore StartName from backup ...
```

Add state tracking in PostgreSQL:
```sql
CREATE TABLE mig.rollback_state (
  host_id bigint PRIMARY KEY,
  original_domain text,
  acl_backup_path text,
  service_backup_json jsonb,
  can_rollback boolean DEFAULT true
);
```

---

#### 1.2.3 Entra Connect / Azure AD Sync Details (Insufficient)
**Impact:** HIGH (for On-Prem → Cloud pathway)  
**Description:** Section 3.4 mentions "Entra Connect (Cloud Sync or AADConnect v2)" but doesn't address:
- **Anchor attribute conflicts**: What if `employeeId` collides between source and pre-existing target users?
- **Soft-match vs. hard-match**: How to prevent accidental merges of different users with same UPN?
- **Sync cycles**: How long for new users to appear in Entra after AD creation? (15-30 min typical)
- **Filtering rules**: Do you sync all OUs or only migration staging OUs?
- **Licensing assignment**: Who assigns M365 licenses after Entra sync?

**Recommendation:**  
Add `docs/entra_sync_strategy.md`:
- Define **sourceAnchor** strategy (objectGUID? ms-DS-ConsistencyGuid? employeeID?)
- Document sync scope filters (OU paths, group membership)
- Create `playbooks/11_entra_wait_for_sync.yml` that polls Graph API until user appears:
```yaml
- name: Wait for user sync to Entra
  uri:
    url: https://graph.microsoft.com/v1.0/users/{{ upn }}
    method: GET
    headers:
      Authorization: "Bearer {{ graph_token }}"
    status_code: [200, 404]
  register: user_check
  retries: 20
  delay: 60
  until: user_check.status == 200
```

---

#### 1.2.4 State Store I/O & Network Bandwidth (Underspecified)
**Impact:** MEDIUM  
**Description:** Section 5.1 says "regional state stores" and "compress stores" but lacks:
- **Capacity math**: If 300 workstations × 5 GB average profile = 1.5 TB; what's the share's IOPS capacity?
- **Bandwidth model**: 300 parallel scanstate at 5 GB each = 1.5 TB write + 1.5 TB read over ~30 min = **50 Gbps sustained** (unrealistic for most SMB shares)
- **Contention handling**: Do you throttle per-host or per-share? How?

**Recommendation:**  
Add `docs/capacity_model_detailed.xlsx` with:
| Scenario | Hosts | Avg Profile (GB) | Total Data (TB) | Duration (min) | Required Bandwidth (Gbps) | Share Type |
|----------|-------|------------------|-----------------|----------------|---------------------------|------------|
| Wave 1   | 300   | 5                | 1.5             | 30             | 6.8                       | DFS-N + 4× SMB shares |
| Wave 2   | 50 servers | 2             | 0.1             | 45             | 0.3                       | Dedicated SQL state share |

Implement **throttle_scanstate** in role:
```yaml
- name: Apply I/O throttle to scanstate
  set_fact:
    usmt_switches: "{{ usmt_switches }} /localonly /encrypt /key:{{ vault_usmt_key }} /rate:{{ throttle_mbps }}"
```

---

#### 1.2.5 Linux UID/GID Collision Handling (Vague)
**Impact:** MEDIUM  
**Description:** Section 3.5 says "Preserve UID/GID; create mapping file if conflicts" but never explains:
- How to detect collisions?
- Who resolves them (automated vs. manual)?
- How to update 10,000 files with `chown` without breaking running services?

**Recommendation:**  
Add `roles/linux_migrate/tasks/uid_collision_detect.yml`:
```yaml
- name: Enumerate existing UIDs on target
  shell: getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $3}'
  register: target_uids

- name: Check for collisions
  set_fact:
    collisions: "{{ source_users | selectattr('uid', 'in', target_uids.stdout_lines) | list }}"

- name: Fail if unresolved collisions
  fail:
    msg: "UID collisions detected: {{ collisions | map(attribute='name') | join(', ') }}"
  when: collisions | length > 0 and not force_uid_remap
```

For file ownership translation:
```yaml
- name: Remap file ownership
  shell: |
    find {{ data_path }} -uid {{ old_uid }} -exec chown {{ new_uid }} {} +
  async: 3600
  poll: 0  # Background task
```

---

#### 1.2.6 Control Plane DR & Resilience (Partially Addressed)
**Impact:** HIGH  
**Description:** Section 15A describes HA components (Vault raft, Patroni, MinIO erasure) but lacks:
- **Recovery Time Objective (RTO)** if AWX cluster fails mid-wave
- **State persistence**: If K8s node dies, can jobs resume?
- **Backup procedures** for Vault, Postgres, object store
- **Break-glass access** if Vault is sealed and automation stops

**Recommendation:**  
Add `docs/dr_runbook.md`:
- **Vault sealed**: Manual unseal with Shamir shards (documented offline)
- **Postgres primary failure**: Patroni auto-failover (~30s); validate replication lag < 5s before resuming jobs
- **AWX pod eviction**: Job state in Postgres; relaunch from last wave checkpoint
- **Network partition**: Split-brain detection; prefer manual intervention over auto-resume

Add `playbooks/98_backup_control_plane.yml`:
```yaml
- name: Snapshot Vault
  uri:
    url: http://vault:8200/v1/sys/storage/raft/snapshot
    method: GET
    dest: /backup/vault_{{ ansible_date_time.epoch }}.snap
    headers:
      X-Vault-Token: "{{ vault_token }}"

- name: Backup Postgres
  postgresql_db:
    name: mig
    state: dump
    target: /backup/mig_{{ ansible_date_time.epoch }}.sql
```

---

### 1.3 Minor Gaps (Non-Blocking) ℹ

1. **Exchange mailbox migration** mentioned as "out of scope" but many identity migrations require mailbox cutover coordination (timing, autodiscover updates).
2. **Certificate services**: No mention of migrating/reissuing machine certs after domain change (affects IIS, RDP, custom apps).
3. **GPO migration**: Group Policies often have hardcoded domain names or SIDs; how to translate?
4. **Print server**: Queue names, drivers, ACLs need remediation (not mentioned).
5. **DFS namespace**: Root servers and folder targets may need updating post-migration.

**Recommendation:** Add a "Out of Scope / Future Work" appendix explicitly listing these.

---

## 2. ACCURACY ANALYSIS

### 2.1 Technically Sound ✓

**Ansible & Windows:**
- [✓] Correct use of `microsoft.ad.*` modules
- [✓] WinRM over Kerberos with HTTPS (5986) is best practice
- [✓] `win_domain_membership` for joins/disjoins
- [✓] SSH fallback via OpenSSH server (valid alternative)

**USMT:**
- [✓] Switches `/v:13 /o /c` are correct
- [✓] `/uel:n` to exclude old profiles is accurate
- [✓] Compression flag is real (undocumented but works)
- [✓] Two reboots for domain move is correct (disjoin + join)

**Active Directory:**
- [✓] SIDHistory requires two-way trust + PES (accurate)
- [✓] `Test-ComputerSecureChannel -Repair` is valid PowerShell
- [✓] SPN duplicate detection is critical (correct concern)
- [✓] ACL translation via `icacls` backup/restore is standard

**HashiCorp Vault:**
- [✓] AD secrets engine for dynamic service account passwords (real feature)
- [✓] SSH CA for short-lived certs (correct use case)
- [✓] Database engine for Postgres creds (accurate)
- [✓] Raft storage for HA (valid since Vault 1.4)

**PostgreSQL & Grafana:**
- [✓] Patroni for HA is industry standard
- [✓] Streaming replication for read replicas (correct)
- [✓] Grafana provisioning YAML format is accurate
- [✓] Query examples are syntactically valid

**Prometheus:**
- [✓] Pushgateway for batch job metrics (appropriate)
- [✓] Blackbox exporter for TCP probes (correct tool)
- [✓] Alert rule syntax is valid
- [✓] Webhook to AWX job templates (real integration pattern)

---

### 2.2 Technical Concerns ⚠

#### 2.2.1 Vault AD Engine Rotation Timing
**Severity:** MEDIUM  
**Claim:** "TTL 2–8 hours" for AD service accounts via Vault AD engine.

**Issue:** [Inference] Vault AD engine rotates passwords by changing the AD account's password attribute. If a job runs longer than TTL, mid-job rotation will **break active WinRM sessions**. The design doesn't address:
- Session refresh on rotation
- Lease renewal before expiration
- Graceful handling of mid-migration password changes

**Recommendation:**  
Set TTL to **job duration + 2 hours** (not 2-8 hours). For a 4-hour wave, use 6-hour TTL. Add lease renewal:
```yaml
- name: Renew Vault lease mid-job
  uri:
    url: http://vault:8200/v1/sys/leases/renew
    method: PUT
    body_format: json
    body:
      lease_id: "{{ vault_lease_id }}"
      increment: 14400  # +4 hours
  when: ansible_play_batch is defined and (ansible_play_batch | length > 100)
```

---

#### 2.2.2 WinRM Concurrency Limits
**Severity:** HIGH  
**Claim:** "servers ≤ 50 in parallel, workstations ≤ 400 in parallel per runner"

**Issue:** [Unverified] Windows WinRM has default limits:
- `MaxShellsPerUser` = 25
- `MaxConcurrentUsers` = 10
- `MaxProcessesPerShell` = 15

Even with tuning (`winrm set winrm/config/service @{MaxShellsPerUser="100"}`), 400 concurrent WinRM sessions to a **single Ansible runner** (which serializes through Python processes) is [Speculation] likely to cause:
- Memory exhaustion on the runner (400 × 50 MB Python process = 20 GB)
- Network port exhaustion (ephemeral port range)
- Target host WinRM queue saturation

**Recommendation:**  
Test actual limits in lab. More realistic caps [Inference]:
- **Workstations:** 100-200 per runner (not 400)
- **Servers:** 20-30 per runner (not 50)
- **Solution:** Deploy 3-4 runners and shard inventory by site/OU

Add to `group_vars/all.yml`:
```yaml
ansible_winrm_connection_timeout: 60
ansible_winrm_operation_timeout: 300
ansible_winrm_read_timeout: 90
forks: 150  # Not 400; tune based on runner RAM
```

---

#### 2.2.3 Entra Graph API Rate Limits
**Severity:** MEDIUM  
**Claim:** "1,000 users in < 1 hour is straightforward"

**Issue:** [Unverified] Microsoft Graph has throttling:
- User creation: ~20 requests/sec per tenant (burst to 50)
- Group membership adds: ~10 requests/sec

For 1,000 users with avg 5 group memberships = 1,000 user creates + 5,000 membership adds:
- User creation: 1,000 ÷ 20 req/s = **50 seconds**
- Membership: 5,000 ÷ 10 req/s = **500 seconds (~8 min)**
- **Total: ~9 minutes** (optimistic; assumes no throttling)

**Reality:** [Inference] Throttling responses (HTTP 429) will extend this to **20-30 minutes** with exponential backoff.

**Recommendation:**  
Add retry logic in `roles/ad_provision/tasks/entra_user_create.yml`:
```yaml
- name: Create user in Entra
  uri:
    url: https://graph.microsoft.com/v1.0/users
    method: POST
    headers:
      Authorization: "Bearer {{ graph_token }}"
    body_format: json
    body:
      userPrincipalName: "{{ user.upn }}"
      displayName: "{{ user.name }}"
      mailNickname: "{{ user.alias }}"
      accountEnabled: true
      passwordProfile:
        password: "{{ temp_password }}"
    status_code: [201, 429, 503]
  register: create_user
  retries: 10
  delay: "{{ 2 ** (attempt | default(1)) }}"  # Exponential backoff
  until: create_user.status == 201
```

Revise claim: "1,000 users in < 1 hour" → [**30-45 minutes with throttling**].

---

#### 2.2.4 USMT Timing Estimates
**Severity:** LOW  
**Claim:** "15–35 min median" for USMT capture + restore

**Issue:** [Unverified] Timing depends on:
- Profile size (5 GB? 50 GB?)
- State store network speed (1 Gbps? 10 Gbps?)
- Disk I/O (SSD? HDD?)

Example calculation:
- 10 GB profile, 1 Gbps SMB share, SSD laptop
- Scanstate write: 10 GB ÷ 125 MB/s = **80 seconds**
- Domain move + reboots: **10 minutes** (realistic)
- Loadstate read: 10 GB ÷ 125 MB/s = **80 seconds**
- **Total: 13 minutes** (best case)

But if 300 hosts scan simultaneously to same share:
- Aggregate: 300 × 10 GB = 3 TB
- 1 Gbps share = 125 MB/s = **6.8 hours** (worst case, no parallelism)

**Recommendation:**  
Add bandwidth model to `docs/capacity_model.xlsx`. Use **DFS-N** with multiple regional shares:
- US-West: `\\statestore-west\mig$` (10 Gbps)
- US-East: `\\statestore-east\mig$` (10 Gbps)

Assign hosts by geography:
```yaml
usmt_store_path: "\\statestore-{{ hostvars[inventory_hostname].site | default('east') }}\mig$\{{ inventory_hostname }}"
```

Revise claim: "15–35 min" → [**10-45 min depending on profile size, network, and share load**].

---

### 2.3 Minor Inaccuracies ℹ

1. **Alertmanager webhook to AWX** (§15B): The snippet shows `bearer_token_file` but AWX Job Templates expect **POST with survey vars**; token goes in header, survey in body. Correctable.
2. **Grafana rawSql format** (§15C): Should use `$__timeGroup(started_at, 1h)` for Postgres time bucketing, not `date_trunc`. Works but not optimal.
3. **K8s HPA for AWX execution** (§15B heal script): AWX execution nodes don't auto-scale via HPA by default; requires custom metrics adapter. Feasible but not documented.

---

## 3. FEASIBILITY ANALYSIS

### 3.1 Operationally Feasible ✓ (With Caveats)

**Infrastructure Deployment:**
- [✓] AWX on K8s is production-ready (upstream tested)
- [✓] Vault HA with Raft is stable (GA since 1.4)
- [✓] Patroni + Postgres is battle-tested
- [✓] Prometheus stack is industry standard
- [~] MinIO HA is viable but requires careful erasure code tuning (4-node minimum)

**Automation Patterns:**
- [✓] Wave-based execution is standard practice
- [✓] State persistence for resume is feasible (Postgres-backed)
- [✓] Approval gates in AWX workflows are built-in
- [✓] Ansible idempotence for identity ops is achievable

**Timeline Assessment:**
- **Week 1-2 (scaffold + AWX + Vault):** [Feasible] Assumes team has K8s/Ansible expertise
- **Week 3 (pilot 10 WS + 3 servers):** [Feasible] Good risk mitigation
- **Week 4-6 (production waves):** [**Optimistic**] Assumes zero discovery of new blockers in pilot
- **Week 7 (app retargeting):** [**Unrealistic**] App federation changes alone can take weeks per app

**Revised Timeline:** [Inference] **10-14 weeks** for full production rollout (not 7).

---

### 3.2 Throughput Feasibility ⚠

#### 3.2.1 Identity: 1,000 Users / 4 Hours
**Claim:** "1,000 users / 4 hours is reasonable"

**Assessment:** [**FEASIBLE**] with caveats:
- ✓ AD user creation: fast (<15 min for 1,000 users)
- ✓ Group membership: manageable (~30 min for 5,000 memberships)
- ⚠ Entra sync delay: 15-30 min per sync cycle
- ⚠ Graph API throttling: adds 10-20 min
- **Actual time: 1-2 hours** (well within 4-hour window)

---

#### 3.2.2 Workstations: 1,000 / 4 Hours
**Claim:** "300 parallel, expect ~300 every 30–45 min; two to three waves can move 600–900 in ~2 hours"

**Assessment:** [**OPTIMISTIC**]

**Reality check:**
- 300 parallel × 30 min = 300 machines/wave ✓
- 4 waves × 300 = 1,200 machines in 4 hours [Unverified]

**Bottlenecks:**
1. **State store I/O:** 300 × 5 GB profiles = 1.5 TB per wave
   - 10 Gbps share = 1.5 TB ÷ 1.25 GB/s = **20 minutes write + 20 minutes read** (best case)
   - Adds to timeline: 30 min (USMT) + 40 min (I/O) = **70 min/wave** (not 30-45)
2. **WinRM saturation:** 300 parallel to 1 runner is aggressive; expect failures
3. **AD replication:** 300 new computer objects per wave; replication to all DCs takes **5-15 min**

**Revised claim:** [**600-800 workstations / 4 hours with 2-3 runners**] (not 1,000).

**Mitigation:**
- Deploy **3 runners** (100/runner)
- Use **4 regional state stores** (reduce I/O contention)
- Pre-stage computer objects 24 hours ahead (reduces replication lag)

---

#### 3.2.3 Servers: 1,000 / 4 Hours
**Claim:** "1,000 servers / 4 hours is not recommended"

**Assessment:** [**CORRECT**]

**Reality:**
- 50 parallel × 90 min/server = 50 every 1.5 hours
- 4 hours ÷ 1.5 = **~2.5 waves = 125 servers** (not 1,000)

**Revised claim:** [**100-150 servers / 4 hours with 2-3 runners**].

---

### 3.3 Self-Healing Feasibility ⚠

**Concept:** Alertmanager triggers AWX jobs to repair WinRM, secure channel, sssd.

**Concerns:**
1. **Complexity explosion:** Self-healing introduces new failure modes (healing job fails, creates alert, triggers another healing job → loop)
2. **Change freeze conflicts:** Auto-healing during CAB freeze violates governance (design mentions but doesn't solve)
3. **Blast radius:** Bad healing logic could break 100s of hosts before human intervention
4. **Operational burden:** Requires 24/7 monitoring of Alertmanager, AWX queue, Prometheus

**Recommendation:**  
[**Phase 2 feature**]. For initial deployment:
- **Manual triage** of failures via dashboard
- **Assisted remediation** (playbook library, not automated triggers)
- After 6 months of operational data, consider auto-healing for low-risk actions (WinRM service restart only)

---

### 3.4 Infrastructure Feasibility ⚠

**Required Components:**
- K8s cluster (3 control + 2 worker nodes)
- Vault HA (3 nodes)
- Postgres HA (2 nodes + 1 replica)
- MinIO (4 nodes)
- Prometheus + Grafana (2 nodes)
- **Total: ~15 VMs/nodes minimum**

**Resource Estimate:**
| Component | vCPU | RAM (GB) | Storage (GB) | Notes |
|-----------|------|----------|--------------|-------|
| K8s control | 12   | 48       | 300          | 3×4c16g |
| K8s workers | 16   | 64       | 500          | 2×8c32g for AWX exec |
| Vault       | 6    | 12       | 50           | 3×2c4g |
| Postgres    | 12   | 48       | 500          | 3×4c16g (primary+replicas) |
| MinIO       | 16   | 32       | 4000         | 4×4c8g, 1TB each |
| Observability | 8  | 32       | 1000         | Prom+Grafana+Loki |
| **TOTAL**   | **70** | **236** | **6350**     | |

**Assessment:** [**Enterprise-grade infrastructure**]. Feasible for Fortune 500; **overkill for SMB** (<5,000 users).

**Recommendation:**  
Add **tiered deployment options**:
- **Tier 1 (SMB):** Single AWX VM, SQLite for reporting, Ansible Vault (no HashiCorp), static HTML reports
- **Tier 2 (Mid-market):** AWX + Postgres + Vault, basic Prometheus
- **Tier 3 (Enterprise):** Full HA stack as designed

---

### 3.5 Skillset Feasibility ⚠

**Required Expertise:**
- Ansible (advanced: custom modules, callbacks)
- Windows PowerShell + AD/Entra admin
- Linux sysadmin (sssd, Kerberos, PAM)
- Kubernetes operations
- HashiCorp Vault (policies, auth methods, engines)
- PostgreSQL administration
- Prometheus/Grafana query language
- Network engineering (firewalls, routing, DNS)

**Team Size Estimate:** [Inference] **4-6 FTE** for deployment + **2-3 FTE** for operations.

**Concern:** [Unverified] Most organizations lack this breadth in one team.

**Recommendation:**  
Add `docs/training_plan.md`:
- **Week -4 to -1:** Team training on AWX, Vault, Prometheus
- **Week 1-2:** Paired programming for role development
- **Week 3:** Chaos testing (kill Vault, disconnect network, fail DC)

---

## 4. CRITICAL RISKS

### 4.1 Technical Risks

| Risk | Severity | Probability | Mitigation Status |
|------|----------|-------------|-------------------|
| WinRM saturation kills jobs mid-wave | HIGH | MEDIUM | Concurrency caps defined but not validated ⚠ |
| Vault sealed during migration (no access to creds) | CRITICAL | LOW | Manual unseal procedure mentioned but not automated ⚠ |
| State store I/O bottleneck extends 4h window to 8h | HIGH | HIGH | Not adequately modeled ❌ |
| USMT failure leaves user profile corrupted | HIGH | MEDIUM | Backup mentioned but no restore playbook ❌ |
| AD replication lag causes computer join failures | MEDIUM | HIGH | Pre-staging mentioned but not enforced ⚠ |
| Self-healing loop breaks 100s of hosts | HIGH | MEDIUM | Guardrails mentioned but implementation missing ❌ |
| Control plane failure mid-wave (K8s, Postgres) | HIGH | LOW | HA designed but DR procedures incomplete ⚠ |

### 4.2 Operational Risks

| Risk | Severity | Probability | Mitigation Status |
|------|----------|-------------|-------------------|
| Insufficient pre-migration app testing causes outages | CRITICAL | HIGH | No app dependency playbook ❌ |
| Rollback takes >4 hours (misses change window) | HIGH | MEDIUM | No rollback automation ❌ |
| Entra Connect sync conflicts merge wrong users | CRITICAL | LOW | Anchor strategy not documented ❌ |
| Team lacks Vault/K8s skills, can't troubleshoot | HIGH | MEDIUM | No training plan ⚠ |
| 7-week timeline slips to 14+ weeks | MEDIUM | HIGH | Optimistic timeline not risk-adjusted ⚠ |

### 4.3 Security Risks

| Risk | Severity | Probability | Mitigation Status |
|------|----------|-------------|-------------------|
| Vault token leaked in AWX logs | HIGH | LOW | Redaction filters mentioned ✓ |
| WinRM traffic intercepted (MITM) | MEDIUM | LOW | Kerberos + HTTPS enforced ✓ |
| Ansible Vault master password compromise | CRITICAL | LOW | Vault rotation plan missing ⚠ |
| Break-glass account never tested, fails in emergency | HIGH | MEDIUM | Quarterly test mentioned ✓ |

---

## 5. SPECIFIC RECOMMENDATIONS

### 5.1 Immediate (Pre-Implementation)

1. **Build MVP roles first:**
   - `ad_export` → test with 100 users
   - `ad_provision` → dry-run to test AD
   - `machine_move_usmt` → pilot with 5 workstations
   - Skip self-healing, Grafana, MinIO for v1.0

2. **Lab validation of throughput claims:**
   - Benchmark 50/100/200 parallel WinRM sessions to 1 runner
   - Measure USMT I/O to DFS share under load
   - Test Graph API with 1,000 users + throttling

3. **Document rollback procedures:**
   - Build `playbooks/99_rollback_*.yml` for each migration type
   - Test rollback in lab (break, then fix)

4. **Add pre-migration validation:**
   - `00a_app_dependency_scan.yml`
   - `00b_coexistence_test.yml`
   - `00e_bandwidth_preflight.yml` (measure network to state store)

5. **Create tiered deployment guide:**
   - **Tier 1 (minimal):** AWX VM, static reports, Ansible Vault
   - **Tier 3 (full HA):** as-designed

---

### 5.2 Short-Term (During Pilot)

1. **Tune concurrency based on real metrics:**
   - Start with `forks: 50` for workstations, measure runner CPU/memory
   - Increment by 50 until failure, then back off 20%

2. **Implement state store I/O monitoring:**
   - Add Prometheus metrics for SMB latency, throughput, queue depth
   - Alert if P95 latency > 500ms

3. **Build rescue playbooks:**
   - `heal_usmt_corruption.yml` (restore from shadow copy?)
   - `heal_stuck_domain_join.yml` (clear cache, retry)

4. **Validate Entra Connect sync:**
   - Run pilot with 10 users, measure time-to-sync
   - Document conflicts and resolution steps

---

### 5.3 Long-Term (Post-Initial Deployment)

1. **Self-healing phase 2:**
   - Collect 6 months of failure data
   - Implement auto-healing for **top 3 failure modes only**
   - Add kill-switch for auto-healing (emergency disable)

2. **Performance optimization:**
   - Migrate to object storage (S3/Azure Blob) for USMT if I/O is bottleneck
   - Evaluate direct-to-cloud USMT for cloud-bound workstations

3. **Expand Linux support:**
   - Add FreeIPA/SSSD migration playbooks
   - Handle `autofs` and `nsswitch.conf` remediation

---

## 6. SCORING RUBRIC

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| **Completeness** | 7/10 | Strong coverage of happy path; missing validation, rollback, DR |
| **Accuracy** | 8/10 | Technically sound; some unverified throughput claims and tooling assumptions |
| **Feasibility** | 6/10 | Architecturally feasible but operationally demanding; timeline optimistic |
| **Security** | 8/10 | Strong Vault design, Kerberos enforcement; missing rotation SOP |
| **Operability** | 5/10 | High complexity (K8s, Vault, Patroni); steep learning curve; 4-6 FTE |
| **Risk Management** | 5/10 | Good identification of risks; weak mitigation automation |

**Overall: 6.5/10** – Strong design for an **experienced enterprise team** with **budget and time**. Needs simplification for broader adoption.

---

## 7. GO / NO-GO RECOMMENDATION

### 7.1 GO IF:
- ✓ Team has Ansible + K8s + Vault expertise (or 3 months for training)
- ✓ Budget supports 15+ VM infrastructure + object storage
- ✓ Migration scope is >2,000 users + 500 servers (ROI justifies tooling)
- ✓ Timeline extended to **12-14 weeks** (not 6-7)
- ✓ Pilot phase includes **50 workstations + 10 servers** (not 10+3)
- ✓ Rollback playbooks built **before** production waves

### 7.2 NO-GO / SIMPLIFY IF:
- ❌ Team is 1-2 people (insufficient for operational burden)
- ❌ Migration is <500 users (over-engineered; use manual + ADMT)
- ❌ No budget for HA infrastructure ($50k+ in cloud costs/year [Inference])
- ❌ Timeline pressure is <8 weeks (insufficient for safe delivery)
- ❌ No lab environment for validation (production testing is too risky)

---

## 8. FINAL VERDICT

**This is a sophisticated, well-architected design** that demonstrates deep technical expertise in identity management, orchestration, and enterprise automation patterns. The security model (Vault, JIT creds, Kerberos) is **exemplary**. The observability stack (Prometheus, Grafana, Postgres) is **production-grade**.

**However**, the design suffers from **scope creep** and **operational complexity** that may undermine adoption:
- The self-healing system is ambitious but adds significant risk
- The HA infrastructure requires a large team and budget
- Throughput claims are optimistic and need lab validation
- Critical gaps (rollback, app dependencies, Entra sync details) must be closed

**Recommendation:**  
1. **Phase 1 (MVP):** Build core migration roles (export, provision, machine move) with **minimal infrastructure** (single AWX, Ansible Vault, static reports). Target: **200 users, 50 workstations, 10 servers in 8 weeks**.
2. **Phase 2 (Scale):** Add Prometheus, PostgreSQL reporting, wave orchestration. Target: **1,000 users, 300 workstations, 50 servers**.
3. **Phase 3 (Enterprise):** Full HA stack (Vault, K8s, MinIO), self-healing. Target: **Multi-tenant, 10,000+ users**.

**With these adjustments, the design is FEASIBLE and VALUABLE.**

---

## APPENDIX: MISSING ARTIFACTS CHECKLIST

The following documents are **referenced but not included** in the design:

- [ ] `docs/implementation_guide.md` (§10)
- [ ] `docs/runbook.md` (§10)
- [ ] `docs/test_plan.md` (§10)
- [ ] `docs/risk_register.md` (§10)
- [ ] `docs/capacity_model.xlsx` (§10, §5.3)
- [ ] `docs/change_request.md` (§10)
- [ ] `docs/entra_sync_strategy.md` (§1.2.3, added by this analysis)
- [ ] `docs/dr_runbook.md` (§1.2.6, added by this analysis)
- [ ] `docs/training_plan.md` (§3.5, added by this analysis)
- [ ] `playbooks/00a_app_dependency_scan.yml` (§1.2.1, added)
- [ ] `playbooks/00b_coexistence_test.yml` (§1.2.1, added)
- [ ] `playbooks/99_rollback_machine.yml` (§1.2.2, added)
- [ ] `playbooks/98_backup_control_plane.yml` (§1.2.6, added)
- [ ] SQL schema DDL for all tables (partial snippets only)

**Status:** [**Incomplete**]. The repo scaffold (§11) is well-defined, but these critical documents must be authored before pilot.

---

**END OF REPORT**

