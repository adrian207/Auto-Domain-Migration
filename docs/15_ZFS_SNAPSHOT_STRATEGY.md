# ZFS Snapshot Strategy for Migration Backup & Recovery

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Leverage ZFS snapshots to provide rapid, frequent backups with minimal overhead, enabling fast rollback and reducing RPO (Recovery Point Objective) from hours to minutes.

**Benefits:**
- **Instant snapshots** – No I/O penalty, taken in <1 second
- **Space-efficient** – Only changed blocks consume space (copy-on-write)
- **Fast rollback** – Restore entire filesystem in seconds
- **Frequent backups** – Every 5-15 minutes during migration waves
- **Minimal overhead** – Negligible CPU/memory impact

---

## 1) ZFS Architecture Overview

### 1.1 Where to Use ZFS

| Component | ZFS Dataset | Snapshot Frequency | Retention | Priority |
|-----------|-------------|-------------------|-----------|----------|
| **USMT State Store** | `zpool/statestore` | Every 15 min during waves | 7 days | CRITICAL |
| **PostgreSQL Data** | `zpool/postgres/data` | Every 5 min during waves | 3 days | CRITICAL |
| **Control Plane VMs** | `zpool/vms/awx`, `zpool/vms/vault` | Before each wave | 30 days | HIGH |
| **Artifacts & Reports** | `zpool/migration/artifacts` | Hourly | 30 days | MEDIUM |
| **Target AD DCs** | `zpool/vms/target-dc01` | Every 30 min during waves | 7 days | HIGH |
| **Ansible Playbooks** | `zpool/migration/repo` | On git commit | 90 days | LOW (git is primary) |

---

### 1.2 ZFS vs. Traditional Backups

| Feature | ZFS Snapshots | Traditional Backups (tar/rsync) |
|---------|---------------|--------------------------------|
| **Speed** | <1 second | Minutes to hours |
| **Space Efficiency** | Only changed blocks | Full copy each time |
| **I/O Impact** | None | High (reads entire dataset) |
| **Frequency** | Every 1-15 min | Daily/hourly (too expensive otherwise) |
| **Rollback Time** | <10 seconds | Minutes to hours |
| **Granularity** | Filesystem-level | File-level |
| **Consistency** | Atomic (crash-consistent) | Depends on backup method |

---

## 2) ZFS Snapshot Automation

### 2.1 Snapshot Naming Convention

```
<dataset>@<type>-<timestamp>-<wave>

Examples:
zpool/statestore@migration-20251018-143000-wave3
zpool/postgres/data@migration-20251018-140000-wave3
zpool/vms/awx@pre-wave-20251018-120000-wave3
```

**Components:**
- `<type>`: `migration`, `pre-wave`, `post-wave`, `hourly`, `manual`
- `<timestamp>`: `YYYYMMDD-HHMMSS`
- `<wave>`: Current wave ID (e.g., `wave3`, `pilot`)

---

### 2.2 Snapshot Automation via Ansible

**Role:** `roles/zfs_snapshot`

**Defaults:**

```yaml
# roles/zfs_snapshot/defaults/main.yml
zfs_snapshot_enabled: true
zfs_pool: "zpool"
zfs_datasets:
  statestore:
    path: "zpool/statestore"
    frequency: "15min"
    retention: "7d"
  postgres:
    path: "zpool/postgres/data"
    frequency: "5min"
    retention: "3d"
  artifacts:
    path: "zpool/migration/artifacts"
    frequency: "1h"
    retention: "30d"

zfs_snapshot_prefix: "migration"
```

**Tasks:**

```yaml
# roles/zfs_snapshot/tasks/main.yml
---
- name: Check if ZFS is available
  command: zfs version
  register: zfs_check
  failed_when: false
  changed_when: false

- name: Skip if ZFS not available
  meta: end_play
  when: zfs_check.rc != 0

- name: Create snapshot for each dataset
  command: >
    zfs snapshot {{ item.value.path }}@{{ zfs_snapshot_prefix }}-{{ ansible_date_time.epoch }}-{{ wave | default('manual') }}
  loop: "{{ zfs_datasets | dict2items }}"
  when: item.value.path is defined
  register: snapshot_create

- name: List snapshots for verification
  command: zfs list -t snapshot -o name,used,creation {{ item.value.path }}
  loop: "{{ zfs_datasets | dict2items }}"
  register: snapshot_list

- name: Prune old snapshots (retention enforcement)
  shell: |
    retention_seconds=$(({{ item.value.retention | regex_replace('d', '') }} * 86400))
    cutoff_epoch=$(($(date +%s) - $retention_seconds))
    
    zfs list -H -t snapshot -o name,creation -s creation {{ item.value.path }} | while read snapshot creation; do
      snapshot_epoch=$(date -d "$creation" +%s)
      if [ $snapshot_epoch -lt $cutoff_epoch ]; then
        echo "Destroying old snapshot: $snapshot"
        zfs destroy $snapshot
      fi
    done
  loop: "{{ zfs_datasets | dict2items }}"
  when: item.value.retention is defined
  changed_when: false
```

---

### 2.3 Integration with Migration Workflow

**Pre-Wave Snapshot:**

```yaml
# In playbooks/01_pre_wave_snapshot.yml
---
- name: Pre-Wave Snapshot - All Critical Systems
  hosts: zfs_hosts
  gather_facts: yes

  tasks:
    - name: Snapshot state store
      command: zfs snapshot zpool/statestore@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}

    - name: Snapshot PostgreSQL
      command: zfs snapshot zpool/postgres/data@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}
      
    - name: Snapshot AWX VM
      command: zfs snapshot zpool/vms/awx@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}
      
    - name: Snapshot Vault VM
      command: zfs snapshot zpool/vms/vault@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}

    - name: Record snapshot names
      copy:
        content: |
          {
            "wave": "{{ wave }}",
            "timestamp": "{{ ansible_date_time.iso8601 }}",
            "snapshots": {
              "statestore": "zpool/statestore@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}",
              "postgres": "zpool/postgres/data@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}",
              "awx": "zpool/vms/awx@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}",
              "vault": "zpool/vms/vault@pre-wave-{{ ansible_date_time.epoch }}-{{ wave }}"
            }
          }
        dest: "{{ state_dir }}/snapshots/pre-wave-{{ wave }}.json"
      delegate_to: localhost
```

**During-Wave Continuous Snapshots:**

```yaml
# Cron job or systemd timer on ZFS host
*/15 * * * * /usr/local/bin/zfs-migration-snapshot.sh

# /usr/local/bin/zfs-migration-snapshot.sh
#!/bin/bash
WAVE=$(cat /var/lib/migration/current_wave.txt 2>/dev/null || echo "none")
if [ "$WAVE" != "none" ]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  zfs snapshot zpool/statestore@migration-${TIMESTAMP}-${WAVE}
  zfs snapshot zpool/postgres/data@migration-${TIMESTAMP}-${WAVE}
fi
```

**Post-Wave Snapshot:**

```yaml
# In playbooks/41_post_wave_snapshot.yml
---
- name: Post-Wave Snapshot - Cleanup Marker
  hosts: zfs_hosts

  tasks:
    - name: Create post-wave snapshots
      command: zfs snapshot {{ item }}@post-wave-{{ ansible_date_time.epoch }}-{{ wave }}
      loop:
        - zpool/statestore
        - zpool/postgres/data
        - zpool/migration/artifacts

    - name: Tag successful waves
      command: zfs set migration:wave={{ wave }} migration:status=success {{ item }}@post-wave-{{ ansible_date_time.epoch }}-{{ wave }}
      loop:
        - zpool/statestore
        - zpool/postgres/data
```

---

## 3) Rollback Procedures with ZFS

### 3.1 List Available Snapshots

```bash
# List all migration snapshots
zfs list -t snapshot -o name,used,creation | grep migration

# List snapshots for specific wave
zfs list -t snapshot -o name,used,creation | grep wave3

# Get most recent snapshot before failure
zfs list -t snapshot -o name,creation -s creation zpool/statestore | grep wave3 | tail -1
```

---

### 3.2 Rollback State Store (USMT Profiles)

**Scenario:** USMT corruption detected, need to restore profiles from 15 minutes ago

```bash
# Identify latest good snapshot
LATEST_SNAPSHOT=$(zfs list -t snapshot -o name -s creation zpool/statestore | grep "migration-.*-wave3" | tail -1)

# Rollback (WARNING: Destroys snapshots newer than rollback point)
zfs rollback -r $LATEST_SNAPSHOT

# Alternative: Clone snapshot for investigation without destroying data
zfs clone $LATEST_SNAPSHOT zpool/statestore-recovery
# Mount recovery clone and inspect
mount -t zfs zpool/statestore-recovery /mnt/recovery
```

**Playbook:**

```yaml
# playbooks/99_rollback_zfs_statestore.yml
---
- name: Rollback ZFS State Store
  hosts: zfs_statestore_host
  gather_facts: no

  tasks:
    - name: Stop active migrations (prevent new writes)
      command: touch /var/lib/migration/ROLLBACK_IN_PROGRESS

    - name: Find latest snapshot before incident
      shell: |
        zfs list -t snapshot -o name,creation -s creation zpool/statestore | 
        grep "migration-.*-{{ wave }}" | 
        awk -v cutoff="{{ rollback_time }}" '$2 < cutoff {last=$1} END {print last}'
      register: snapshot_to_restore

    - name: Verify snapshot exists
      fail:
        msg: "No snapshot found before {{ rollback_time }} for wave {{ wave }}"
      when: snapshot_to_restore.stdout == ""

    - name: Display snapshot info
      command: zfs list -t snapshot {{ snapshot_to_restore.stdout }}
      register: snapshot_info

    - name: Confirm rollback (require manual approval)
      pause:
        prompt: |
          WARNING: Rolling back to {{ snapshot_to_restore.stdout }}
          This will DESTROY all data written after this snapshot.
          
          Snapshot details:
          {{ snapshot_info.stdout }}
          
          Type 'YES' to confirm rollback
      register: confirm

    - name: Abort if not confirmed
      fail:
        msg: "Rollback aborted by operator"
      when: confirm.user_input != "YES"

    - name: Execute rollback
      command: zfs rollback -r {{ snapshot_to_restore.stdout }}
      register: rollback_result

    - name: Verify rollback success
      command: zfs list zpool/statestore
      register: verify

    - name: Log rollback event
      copy:
        content: |
          {
            "event": "zfs_rollback",
            "wave": "{{ wave }}",
            "dataset": "zpool/statestore",
            "snapshot": "{{ snapshot_to_restore.stdout }}",
            "timestamp": "{{ ansible_date_time.iso8601 }}",
            "operator": "{{ lookup('env', 'USER') }}",
            "reason": "{{ rollback_reason | default('emergency rollback') }}"
          }
        dest: /var/log/migration/rollback_{{ ansible_date_time.epoch }}.json

    - name: Remove rollback flag
      file:
        path: /var/lib/migration/ROLLBACK_IN_PROGRESS
        state: absent
```

---

### 3.3 Rollback PostgreSQL Database

**Scenario:** Bad ETL data written to reporting database, need to restore from 5 minutes ago

```bash
# Stop PostgreSQL
systemctl stop postgresql

# Identify snapshot
LATEST_SNAPSHOT=$(zfs list -t snapshot -o name -s creation zpool/postgres/data | grep "migration-.*-wave3" | tail -1)

# Rollback
zfs rollback -r $LATEST_SNAPSHOT

# Start PostgreSQL
systemctl start postgresql

# Verify data
psql -U postgres -d mig -c "SELECT MAX(recorded_at) FROM mig.check_result;"
```

**Playbook:**

```yaml
# playbooks/99_rollback_zfs_postgres.yml
---
- name: Rollback PostgreSQL via ZFS
  hosts: postgres_primary
  become: yes

  tasks:
    - name: Stop PostgreSQL
      service:
        name: postgresql
        state: stopped

    - name: Find pre-corruption snapshot
      shell: |
        zfs list -t snapshot -o name,creation -s creation zpool/postgres/data | 
        grep "migration-.*-{{ wave }}" | 
        awk -v cutoff="{{ rollback_time }}" '$2 < cutoff {last=$1} END {print last}'
      register: snapshot_to_restore

    - name: Rollback ZFS dataset
      command: zfs rollback -r {{ snapshot_to_restore.stdout }}

    - name: Start PostgreSQL
      service:
        name: postgresql
        state: started

    - name: Wait for PostgreSQL ready
      wait_for:
        port: 5432
        delay: 5
        timeout: 60

    - name: Verify database integrity
      postgresql_query:
        db: mig
        login_host: localhost
        query: "SELECT COUNT(*) FROM mig.host;"
      register: db_check

    - name: Verify replication (if HA)
      postgresql_query:
        db: postgres
        login_host: localhost
        query: "SELECT * FROM pg_stat_replication;"
      register: replication_check
      when: postgres_ha_enabled | default(false)

    - name: Alert if replication broken
      fail:
        msg: "PostgreSQL replication not working after rollback. Manual intervention required."
      when: postgres_ha_enabled and (replication_check.rowcount == 0)
```

---

### 3.4 Rollback Control Plane VMs

**Scenario:** AWX configuration corrupted, need to restore VM to pre-wave state

```bash
# Shutdown VM
virsh shutdown awx-01

# Wait for graceful shutdown
sleep 30

# Rollback VM disk
LATEST_SNAPSHOT=$(zfs list -t snapshot -o name -s creation zpool/vms/awx | grep "pre-wave-.*-wave3" | tail -1)
zfs rollback -r $LATEST_SNAPSHOT

# Start VM
virsh start awx-01

# Verify
virsh list --all
curl https://awx.migration.example.com/api/v2/ping/
```

---

## 4) Advanced ZFS Features for Migration

### 4.1 ZFS Send/Receive (Offsite Replication)

**Use Case:** Replicate snapshots to remote site for disaster recovery

```bash
# Initial full send to remote ZFS host
zfs snapshot zpool/statestore@full-$(date +%s)
zfs send zpool/statestore@full-* | ssh backup-host zfs receive backuppool/migration/statestore

# Incremental sends (every hour)
zfs snapshot zpool/statestore@incr-$(date +%s)
zfs send -i @full-* zpool/statestore@incr-* | ssh backup-host zfs receive backuppool/migration/statestore
```

**Playbook:**

```yaml
# playbooks/98_zfs_offsite_backup.yml
---
- name: ZFS Offsite Backup via Send/Receive
  hosts: zfs_primary
  gather_facts: yes

  tasks:
    - name: Create snapshot for replication
      command: zfs snapshot {{ item }}@offsite-{{ ansible_date_time.epoch }}
      loop:
        - zpool/statestore
        - zpool/postgres/data
        - zpool/migration/artifacts
      register: offsite_snapshots

    - name: Get last replicated snapshot
      shell: |
        ssh {{ backup_host }} zfs list -H -t snapshot -o name {{ item | regex_replace('zpool', 'backuppool/migration') }} | tail -1 | awk -F@ '{print $2}'
      loop:
        - zpool/statestore
        - zpool/postgres/data
        - zpool/migration/artifacts
      register: last_replicated

    - name: Incremental send to backup host
      shell: |
        zfs send -i @{{ item.stdout }} {{ item.item }}@offsite-{{ ansible_date_time.epoch }} | 
        ssh {{ backup_host }} zfs receive {{ item.item | regex_replace('zpool', 'backuppool/migration') }}
      loop: "{{ last_replicated.results }}"
      when: item.stdout != ""
      async: 3600
      poll: 0
      register: send_jobs

    - name: Wait for replication to complete
      async_status:
        jid: "{{ item.ansible_job_id }}"
      loop: "{{ send_jobs.results }}"
      register: job_result
      until: job_result.finished
      retries: 120
      delay: 30
      when: item.ansible_job_id is defined
```

---

### 4.2 ZFS Compression

**Benefit:** Save 50-70% disk space on text-heavy datasets (logs, configs, CSVs)

```bash
# Enable compression on datasets
zfs set compression=lz4 zpool/migration/artifacts
zfs set compression=lz4 zpool/postgres/data

# Verify compression ratio
zfs get compressratio zpool/migration/artifacts
# Example output: compressratio  2.34x
```

**Recommendation:**
- **Use lz4**: Fast, negligible CPU overhead, good compression (1.5-3x typical)
- **Avoid gzip**: Slower, higher CPU, better compression (2-5x) but not worth it for migrations
- **Enable on**: artifacts, logs, Postgres WAL, USMT stores (if text-heavy configs)

---

### 4.3 ZFS Deduplication

**WARNING:** Do NOT enable deduplication for migration workloads.

**Reason:**
- Requires 5 GB RAM per 1 TB of storage (prohibitive)
- Slows writes by 50-80%
- Only beneficial if >80% duplicate data (not typical in migrations)

**Exception:** If you have USMT stores with many identical files (e.g., Windows system files), consider:
```bash
zfs set dedup=verify zpool/statestore  # Only dedup if hash matches
```

But test performance first!

---

## 5) Monitoring & Alerting

### 5.1 ZFS Health Monitoring

**Prometheus Exporter:**

```bash
# Install ZFS exporter
wget https://github.com/pdf/zfs_exporter/releases/download/v2.3.0/zfs_exporter-2.3.0.linux-amd64.tar.gz
tar xvf zfs_exporter-*.tar.gz
sudo mv zfs_exporter /usr/local/bin/

# Systemd service
cat > /etc/systemd/system/zfs_exporter.service <<EOF
[Unit]
Description=ZFS Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/zfs_exporter
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now zfs_exporter
```

**Prometheus Scrape Config:**

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'zfs'
    static_configs:
      - targets:
        - 'zfs-host:9134'
```

**Grafana Dashboard:**

Key metrics to monitor:
- `zfs_pool_free_bytes` – Free space per pool
- `zfs_pool_fragmentation_percent` – Fragmentation (alert if >50%)
- `zfs_dataset_used_bytes` – Dataset growth rate
- `zfs_snapshot_count` – Number of snapshots (alert if >1000 per dataset)
- `zfs_arc_hit_ratio` – Cache hit ratio (should be >90%)

**Alert Rules:**

```yaml
# prometheus-rules.yml
groups:
  - name: zfs_alerts
    rules:
      - alert: ZFSPoolLowSpace
        expr: (zfs_pool_free_bytes / zfs_pool_size_bytes) < 0.15
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "ZFS pool {{ $labels.pool }} has <15% free space"

      - alert: ZFSPoolCriticalSpace
        expr: (zfs_pool_free_bytes / zfs_pool_size_bytes) < 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "ZFS pool {{ $labels.pool }} has <5% free space - CRITICAL"

      - alert: ZFSTooManySnapshots
        expr: count(zfs_snapshot_used_bytes) by (pool, filesystem) > 1000
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.filesystem }} has >1000 snapshots - prune old snapshots"

      - alert: ZFSFragmentationHigh
        expr: zfs_pool_fragmentation_percent > 50
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "ZFS pool {{ $labels.pool }} fragmentation >50% - consider scrub"
```

---

### 5.2 Snapshot Age Monitoring

**Script:**

```bash
# /usr/local/bin/check-snapshot-age.sh
#!/bin/bash
MAX_AGE_MINUTES=30
WAVE=$(cat /var/lib/migration/current_wave.txt)

LATEST_SNAPSHOT=$(zfs list -t snapshot -o name,creation -s creation zpool/statestore | grep "migration-.*-$WAVE" | tail -1)

if [ -z "$LATEST_SNAPSHOT" ]; then
  echo "ERROR: No snapshots found for wave $WAVE"
  exit 1
fi

SNAPSHOT_EPOCH=$(echo "$LATEST_SNAPSHOT" | awk '{print $2}' | xargs date -d +%s)
CURRENT_EPOCH=$(date +%s)
AGE_MINUTES=$(( ($CURRENT_EPOCH - $SNAPSHOT_EPOCH) / 60 ))

if [ $AGE_MINUTES -gt $MAX_AGE_MINUTES ]; then
  echo "WARNING: Latest snapshot is $AGE_MINUTES minutes old (threshold: $MAX_AGE_MINUTES)"
  exit 1
fi

echo "OK: Latest snapshot is $AGE_MINUTES minutes old"
exit 0
```

**Cron:**

```bash
*/5 * * * * /usr/local/bin/check-snapshot-age.sh || logger -p user.warning "ZFS snapshot age check failed"
```

---

## 6) Capacity Planning

### 6.1 Snapshot Space Consumption

**Formula:**
```
Snapshot Space = Changed Data Since Snapshot
```

**Example:**
- Dataset size: 1 TB (USMT state store)
- Change rate: 50 GB/hour during wave (5% churn)
- Snapshots every 15 minutes for 4 hours = 16 snapshots
- Space per snapshot: ~12.5 GB (50 GB / 4)
- **Total snapshot space: ~200 GB** (less with compression)

**Recommendation:**
- Provision **20-30% overhead** for snapshots during active waves
- Use `zfs list -o space` to monitor actual consumption
- Enable compression (lz4) to reduce snapshot space by 30-50%

---

### 6.2 ZFS Pool Sizing

| Dataset | Active Data | Snapshot Overhead (7d retention) | Total | Recommendation |
|---------|-------------|----------------------------------|-------|----------------|
| State Store (1,000 workstations) | 5 TB | 1.5 TB (snapshots) | 6.5 TB | 8 TB pool |
| PostgreSQL | 500 GB | 150 GB | 650 GB | 1 TB pool |
| Artifacts | 200 GB | 50 GB | 250 GB | 500 GB pool |
| Control Plane VMs | 1 TB | 200 GB | 1.2 TB | 2 TB pool |
| **TOTAL** | **6.7 TB** | **1.9 TB** | **8.6 TB** | **12 TB usable** |

**With RAIDZ2 (dual parity):**
- 12 TB usable = 18 TB raw (6 × 4 TB drives in RAIDZ2)

---

## 7) Best Practices

### 7.1 Do's

✅ **Snapshot before each wave** – Pre-wave snapshot is mandatory  
✅ **Frequent snapshots during waves** – Every 5-15 min for critical data  
✅ **Test rollback procedures** – Practice rollback in pilot  
✅ **Monitor snapshot space** – Alert if pool >85% full  
✅ **Use compression (lz4)** – Saves 30-50% space  
✅ **Automate snapshot cleanup** – Prune snapshots >7 days old  
✅ **Replicate to offsite** – ZFS send/receive to backup location  
✅ **Document snapshot names** – Record in state files for rollback reference  

---

### 7.2 Don'ts

❌ **Don't enable deduplication** – Too expensive for migration workloads  
❌ **Don't keep snapshots forever** – Max 30 days, prune aggressively  
❌ **Don't rollback without testing** – Rollback destroys newer data  
❌ **Don't snapshot non-ZFS filesystems** – Use native snapshot tools (LVM, hypervisor)  
❌ **Don't rely only on snapshots** – Still need offsite backups  
❌ **Don't ignore pool health** – Scrub monthly, monitor SMART errors  

---

## 8) Integration with Existing Design

### 8.1 Updated Wave Execution Timeline

| Time | Task | ZFS Snapshot Action |
|------|------|---------------------|
| **T-1 hour** | Pre-wave checklist | Create pre-wave snapshots (state store, Postgres, VMs) |
| **T=0** | Start wave | Enable 15-minute snapshot cron |
| **T+1 hour** | Identity provision | Snapshot Postgres after bulk insert |
| **T+2 hour** | Machine migration starts | Snapshots running automatically |
| **T+4 hour** | Wave completes | Create post-wave snapshot, disable cron |
| **T+1 day** | Validation complete | Prune snapshots >24h old except pre/post-wave |

---

### 8.2 Rollback Decision Matrix

| Failure Type | Rollback Method | RTO | RPO |
|--------------|-----------------|-----|-----|
| USMT corruption | ZFS rollback statestore | <5 min | <15 min |
| Postgres data corruption | ZFS rollback postgres | <10 min | <5 min |
| AWX config broken | ZFS rollback VM disk | <15 min | <1 hour (pre-wave) |
| Full control plane failure | Restore from offsite ZFS send | <2 hours | <1 day |
| Single host failure | Standard playbook rollback | <30 min | N/A (per-host) |

**Comparison to Original Design:**
- **Old RPO:** Daily backups = 24-hour data loss window
- **New RPO:** 5-15 min snapshots = <15 minute data loss window
- **Old RTO:** Restore from tar/rsync = 1-4 hours
- **New RTO:** ZFS rollback = <10 minutes

---

### 8.3 Updated Repository Structure

```
migration-automation/
├── playbooks/
│   ├── 01_pre_wave_snapshot.yml        # NEW - ZFS snapshots before wave
│   ├── 41_post_wave_snapshot.yml       # NEW - ZFS snapshots after wave
│   ├── 98_zfs_offsite_backup.yml       # NEW - Replicate to remote
│   ├── 99_rollback_zfs_statestore.yml  # NEW - Rollback USMT profiles
│   ├── 99_rollback_zfs_postgres.yml    # NEW - Rollback database
│   └── 99_rollback_zfs_vms.yml         # NEW - Rollback VMs
├── roles/
│   └── zfs_snapshot/                    # NEW - Snapshot automation role
│       ├── tasks/
│       ├── defaults/
│       └── templates/
├── scripts/
│   ├── zfs-migration-snapshot.sh        # NEW - Cron script
│   └── check-snapshot-age.sh            # NEW - Monitoring script
```

---

### 8.4 Tier-Specific ZFS Recommendations

**Tier 1 (Demo/POC):**
- **Optional** – ZFS adds complexity for small scale
- Use if already on ZFS (FreeNAS, TrueNAS, Linux with ZFS)
- Alternative: VM snapshots (ESXi, Hyper-V, Proxmox)

**Tier 2 (Medium/Staging):**
- **Recommended** for state store and Postgres
- Snapshots every 15 minutes during waves
- 7-day retention
- Manual rollback procedures

**Tier 3 (Enterprise):**
- **Mandatory** for all critical datasets
- Snapshots every 5-15 minutes during waves
- 30-day retention
- Automated rollback via playbooks
- Offsite replication via ZFS send/receive
- Full monitoring with Grafana dashboards

---

## 9) Implementation Checklist

**Before Pilot:**
- [ ] ZFS pools created with appropriate sizing
- [ ] Datasets created for state store, Postgres, artifacts, VMs
- [ ] Compression enabled (lz4) on all datasets
- [ ] Snapshot automation role tested in lab
- [ ] Rollback procedures tested with dummy data
- [ ] ZFS exporter installed and Prometheus scraping
- [ ] Grafana dashboard configured with ZFS metrics
- [ ] Offsite replication configured (if Tier 3)

**During Pilot:**
- [ ] Pre-wave snapshot created and verified
- [ ] Continuous snapshots running (every 15 min)
- [ ] Snapshot space consumption monitored
- [ ] Test rollback procedure with 1-2 hosts
- [ ] Measure rollback time (should be <10 min)
- [ ] Post-wave snapshot created
- [ ] Old snapshots pruned

**After Each Wave:**
- [ ] Verify post-wave snapshot exists
- [ ] Check snapshot space consumption vs. plan
- [ ] Prune snapshots >retention period
- [ ] Review ZFS pool health (zpool status)
- [ ] Test one rollback scenario

---

## 10) Cost-Benefit Analysis

### Without ZFS Snapshots (Original Design):
- **RPO:** 24 hours (daily backups)
- **RTO:** 2-4 hours (restore from tar/rsync)
- **Risk:** Lose up to 24 hours of work if corruption occurs
- **Cost of 1 hour downtime:** $10k-100k depending on organization

### With ZFS Snapshots:
- **RPO:** 5-15 minutes (continuous snapshots)
- **RTO:** 5-10 minutes (instant rollback)
- **Risk:** Lose max 15 minutes of work
- **Cost:** ~$2k for additional storage (20-30% overhead)

**Break-even:** If ZFS prevents **one single incident** requiring >1 hour recovery, it pays for itself.

---

## 11) Summary

**Key Benefits:**
1. **95% reduction in RPO** – From 24 hours to 15 minutes
2. **90% reduction in RTO** – From 2-4 hours to 5-10 minutes
3. **Zero-overhead snapshots** – Taken in <1 second with no I/O penalty
4. **Space-efficient** – Only changed blocks consume space
5. **Fast rollback** – Entire filesystems restored in seconds
6. **Improved confidence** – Frequent backups enable aggressive migration schedules

**When to Use:**
- **Tier 1:** Optional (use VM snapshots if available)
- **Tier 2:** Highly recommended for state store and Postgres
- **Tier 3:** Mandatory for all critical datasets

**Integration:**
- Pre-wave, during-wave, and post-wave snapshots automated
- Rollback playbooks for each critical component
- Monitoring and alerting via Prometheus/Grafana
- Offsite replication for disaster recovery (Tier 3)

---

**This strategy transforms migration backups from "daily safety net" to "continuous time machine" with near-instant recovery.**

---

**END OF DOCUMENT**

