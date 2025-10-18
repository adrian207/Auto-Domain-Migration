# Operations Runbook – Wave Execution

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Date:** October 2025

**Purpose:** Quick reference guide for migration team during wave execution

**Audience:** Migration engineers, on-call operators

---

## Pre-Wave Checklist (T-24 hours)

**Infrastructure Health:**
- [ ] All AWX/Ansible runners responsive (`ansible all -m ping`)
- [ ] Vault unsealed and accessible (`vault status`)
- [ ] PostgreSQL replication lag <5 seconds (`SELECT * FROM pg_stat_replication;`)
- [ ] State stores accessible with >20% free space
- [ ] Grafana dashboards loading (http://reports:8080/dashboard/)
- [ ] Prometheus alerts green (no firing alerts)

**Active Directory:**
- [ ] All DCs reachable (ping + WinRM test)
- [ ] DC replication healthy (`repadmin /showrepl`)
- [ ] Time sync across DCs (`w32tm /query /status`)
- [ ] Target OUs created and delegated

**Entra Connect (if applicable):**
- [ ] Entra Connect service running
- [ ] Last sync successful (<30 min ago)
- [ ] No sync errors (`Get-ADSyncCSObject` errors = 0)

**Approvals:**
- [ ] CAB approval obtained (ticket number: _______)
- [ ] Stakeholders notified (email sent: _______)
- [ ] Blackout windows checked (no conflicts)

**Backups:**
- [ ] DC system state backup completed (<24h old)
- [ ] Control plane backup completed (Vault, Postgres, AWX)
- [ ] USMT state stores have 30+ days retention

**Team:**
- [ ] Migration lead on-call (phone: _______)
- [ ] 2-3 engineers available (names: _______)
- [ ] Break-glass credentials tested and accessible
- [ ] Incident bridge number ready (Zoom/Teams link: _______)

---

## Wave Execution Timeline (4-Hour Window)

### Hour 0:00-0:30 – Discovery & Validation

**Step 1: Load Wave Configuration**
```bash
cd ~/migration-automation
export WAVE=wave1
export WAVE_FILE=batches/${WAVE}.yml
cat $WAVE_FILE  # Review scope, concurrency, hosts
```

**Step 2: Run Discovery**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/00_discovery_health.yml \
  --extra-vars "@${WAVE_FILE}" \
  --extra-vars "run_id=$(uuidgen)" \
  -vv | tee logs/discovery_${WAVE}_$(date +%Y%m%d_%H%M%S).log
```

**Expected Output:**
```
PLAY RECAP *************************************************
host1.example.com : ok=8    changed=0    unreachable=0    failed=0
host2.example.com : ok=8    changed=0    unreachable=0    failed=0
...
```

**Step 3: Review Discovery Report**
```bash
# Generate HTML report
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/09_render_report.yml \
  --extra-vars "report_type=discovery wave=${WAVE}"

# Open in browser
firefox http://reports.migration.example.com/reports/discovery_${WAVE}.html
```

**Step 4: Gate Check**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/02_gate_on_health.yml \
  --extra-vars "@${WAVE_FILE}" \
  --extra-vars "failure_threshold_percent=5"
```

**If gate fails (>5% hosts unhealthy):**
- Review failed hosts in discovery report
- Run remediation: `playbooks/50_heal_winrm.yml` or `playbooks/51_heal_secure_channel.yml`
- Re-run discovery after 10 minutes
- **DO NOT PROCEED** until gate passes or get approval from Migration Lead

---

### Hour 0:30-1:00 – Identity Provisioning

**Step 5: Provision Users and Groups**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/10_provision.yml \
  --extra-vars "@${WAVE_FILE}" \
  --extra-vars "run_id=${RUN_ID}" \
  -vv | tee logs/provision_${WAVE}_$(date +%Y%m%d_%H%M%S).log
```

**Monitor Progress:**
- Watch Grafana: http://grafana.migration.example.com/d/migration-overview
- Expected: "Users Provisioned" counter incrementing
- Alert if errors >5%

**Step 6: Trigger Entra Connect Sync (if hybrid)**
```powershell
# On Entra Connect server
Start-ADSyncSyncCycle -PolicyType Delta

# Wait for sync (5-10 min)
Start-Sleep 300

# Check sync status
Get-ADSyncScheduler | Select-Object LastSyncTime,LastSyncResult
```

**Step 7: Validate Sync**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/10b_validate_sync.yml \
  --extra-vars "@${WAVE_FILE}"
```

**Expected:** All users present in Entra (<5% missing acceptable; investigate outliers)

---

### Hour 1:00-3:00 – Machine Migration (Workstations)

**Step 8: Launch Workstation Migration**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/20_machine_move.yml \
  --limit "wave${WAVE}_workstations" \
  --forks 50 \
  --extra-vars "@${WAVE_FILE}" \
  --extra-vars "run_id=${RUN_ID}" \
  -vv | tee logs/machine_move_ws_${WAVE}_$(date +%Y%m%d_%H%M%S).log
```

**Timeline per Workstation:**
- Pre-flight: 2-3 min
- USMT scanstate: 10-30 min (profile size dependent)
- Domain disjoin + reboot: 6 min
- Domain join + reboot: 6 min
- USMT loadstate: 10-25 min
- **Total: 35-70 minutes**

**Monitoring:**
- Grafana: "Machine Migration Progress" panel (should show hosts moving through phases)
- State store I/O: Check Prometheus `node_disk_io_now` < 90% saturation
- Runner CPU/Memory: Should stay <80%

**Common Issues:**
| Issue | Symptom | Quick Fix |
|-------|---------|-----------|
| USMT timeout | Host stuck in "capturing" phase >45 min | Check state store network, increase timeout in role |
| Domain join failure | "Computer account not found" | Check AD replication, pre-stage computer objects |
| WinRM timeout | Host unreachable after reboot | Check firewall, WinRM service, wait 5 min and retry |

**Auto-Pause Conditions:**
- Failure rate >5% (configurable in `gate_on_health` role)
- State store full (>95% capacity)
- Runner CPU >90% for >5 minutes

**If paused:**
1. Review failed hosts: `grep "failed=1" logs/machine_move_ws_${WAVE}_*.log`
2. Check Grafana for error distribution
3. Fix common issues (e.g., WinRM, space)
4. Re-run for failed hosts only: `--limit @/tmp/retry_hosts.txt`

---

### Hour 2:00-4:00 – Server Migration & Rebind

**Step 9: Launch Server Migration**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/20_machine_move.yml \
  --limit "wave${WAVE}_servers" \
  --forks 10 \
  --extra-vars "@${WAVE_FILE}" \
  --extra-vars "run_id=${RUN_ID}" \
  -vv | tee logs/machine_move_srv_${WAVE}_$(date +%Y%m%d_%H%M%S).log
```

**Step 10: Server Rebind (Services/SPNs/ACLs)**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/30_server_rebind.yml \
  --limit "wave${WAVE}_servers" \
  --forks 10 \
  --extra-vars "@${WAVE_FILE}" \
  -vv | tee logs/server_rebind_${WAVE}_$(date +%Y%m%d_%H%M%S).log
```

**Critical Validations After Rebind:**
- [ ] All automatic services running (`Get-Service | Where StartType -eq Automatic`)
- [ ] SPNs registered (`setspn -L <ServiceAccount>`)
- [ ] Scheduled tasks updated (`Get-ScheduledTask | Where Principal -like "TARGET\*"`)
- [ ] ACLs updated (spot-check sensitive paths)

**App Smoke Tests:**
- [ ] Web apps: HTTP 200 response
- [ ] SQL Server: Connection test (`sqlcmd -S server -Q "SELECT @@VERSION"`)
- [ ] File shares: Access test (`Test-Path \\server\share`)

---

### Hour 3:30-4:00 – Validation & Reporting

**Step 11: Post-Migration Validation**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/40_validate.yml \
  --limit "wave${WAVE}_*" \
  --extra-vars "@${WAVE_FILE}" \
  -vv | tee logs/validate_${WAVE}_$(date +%Y%m%d_%H%M%S).log
```

**Validation Checks:**
- User login test (RDP to pilot workstation)
- Domain membership (`(Get-WmiObject Win32_ComputerSystem).Domain`)
- Time sync (`w32tm /query /status`)
- Group memberships (`whoami /groups`)
- App access (open browser, test intranet portal)

**Step 12: Generate Wave Report**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/09_render_report.yml \
  --extra-vars "report_type=wave wave=${WAVE} run_id=${RUN_ID}"

# View report
firefox http://reports.migration.example.com/reports/wave_${WAVE}.html
```

**Step 13: Update PostgreSQL**
```bash
ansible-playbook -i inventories/tier2_medium/hosts.ini \
  playbooks/reporting_etl.yml \
  --extra-vars "run_id=${RUN_ID} wave=${WAVE} status=completed"
```

---

## Post-Wave Actions

**Hour 4:00-4:30 – Wrap-Up**

**1. Notify Stakeholders**
```bash
# Email template
cat <<EOF | mail -s "Migration Wave ${WAVE} Complete" migration-team@example.com
Wave ${WAVE} migration completed successfully.

Summary:
- Users provisioned: $(grep "ok=" logs/provision_${WAVE}_*.log | wc -l)
- Workstations migrated: $(grep "ok=" logs/machine_move_ws_${WAVE}_*.log | wc -l)
- Servers migrated: $(grep "ok=" logs/machine_move_srv_${WAVE}_*.log | wc -l)
- Failures: $(grep "failed=" logs/*_${WAVE}_*.log | wc -l)

Detailed report: http://reports.migration.example.com/reports/wave_${WAVE}.html

Next wave scheduled: [DATE]
EOF
```

**2. Slack Notification**
```bash
curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK/URL \
  -H 'Content-Type: application/json' \
  -d '{
    "text": "✅ Migration Wave '"${WAVE}"' Complete",
    "blocks": [
      {"type": "section", "text": {"type": "mrkdwn", "text": "*Wave Status:* Success\n*Duration:* 4 hours\n*Report:* http://reports.migration.example.com/reports/wave_'"${WAVE}"'.html"}}
    ]
  }'
```

**3. Archive Logs**
```bash
tar -czf wave_${WAVE}_logs_$(date +%Y%m%d).tar.gz logs/*_${WAVE}_*.log
aws s3 cp wave_${WAVE}_logs_*.tar.gz s3://migration-archive/waves/
```

**4. Schedule Retrospective**
- Review metrics (success rate, timing, top failures)
- Identify improvements for next wave
- Update playbooks/roles based on learnings

---

## Emergency Procedures

### EMERGENCY: Critical App Down

**Decision:** ROLLBACK immediately if critical business app unavailable >30 minutes

**Steps:**
1. Notify Migration Lead and CAB Chair (phone call, not email)
2. Convene incident bridge (Zoom/Teams link: _______)
3. Identify affected hosts:
   ```bash
   grep "APP.*failed" logs/machine_move_srv_${WAVE}_*.log
   ```
4. Execute rollback:
   ```bash
   ansible-playbook -i inventories/tier2_medium/hosts.ini \
     playbooks/99_rollback_machine.yml \
     --limit "affected_servers" \
     --forks 5 \
     -vv
   ```
5. Validate app restored:
   ```bash
   curl -I http://criticalapp.example.com  # Expect HTTP 200
   ```
6. Document incident in `docs/incidents/wave_${WAVE}_rollback_$(date +%Y%m%d).md`

---

### EMERGENCY: Vault Sealed

**Symptom:** Playbooks fail with `503 Service Unavailable` from Vault

**Steps:**
1. Check Vault status:
   ```bash
   vault status
   # Sealed: true
   ```
2. Unseal with 3 of 5 keys (stored in password manager):
   ```bash
   vault operator unseal <key1>
   vault operator unseal <key2>
   vault operator unseal <key3>
   ```
3. Validate:
   ```bash
   vault status
   # Sealed: false
   ```
4. Resume wave (playbooks will auto-retry Vault lookups)

---

### EMERGENCY: State Store Full

**Symptom:** USMT scanstate fails with "insufficient disk space"

**Steps:**
1. Check state store capacity:
   ```bash
   df -h /mnt/statestore  # Linux
   Get-PSDrive C  # Windows
   ```
2. **Immediate fix:** Delete old USMT stores (>30 days):
   ```powershell
   Get-ChildItem \\statestore\* -Directory | 
     Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | 
     Remove-Item -Recurse -Force
   ```
3. **Long-term fix:** Add capacity or enable compression

---

### EMERGENCY: Runner CPU >90%

**Symptom:** Playbooks slow, SSH/WinRM timeouts increasing

**Steps:**
1. Check runner load:
   ```bash
   top  # Linux
   # Look for ansible-playbook processes
   ```
2. Reduce concurrency:
   ```bash
   # Edit wave file
   vim batches/${WAVE}.yml
   # Change: concurrency.workstations: 50 -> 25
   ```
3. Restart playbook with lower forks:
   ```bash
   ansible-playbook ... --forks 25
   ```
4. **Long-term:** Deploy additional runners

---

## Monitoring Quick Reference

### Grafana Dashboards

**URL:** http://grafana.migration.example.com/

**Key Panels:**
- **Wave Progress:** Bar chart of hosts by phase (captured, joined, restored)
- **Success Rate:** Gauge showing % successful (target: >95%)
- **Failure Rate:** Line graph over time (alert if >5%)
- **WinRM Health:** Blackbox probe success rate per site
- **State Store I/O:** Disk throughput (alert if >90% saturation)
- **Runner Resources:** CPU, Memory, Network (alert if CPU >80%)

### Prometheus Alerts (Critical)

| Alert | Threshold | Action |
|-------|-----------|--------|
| `MigrationWaveFailureHigh` | >5% failed in 15 min | Auto-pause wave, investigate |
| `WinRMReachabilityLow` | <90% success rate | Run `heal_winrm.yml` |
| `VaultSealed` | sealed==1 | Manual unseal (see EMERGENCY above) |
| `PostgresReplicationLag` | >30 seconds | Check Postgres replica health |
| `StateStoreFull` | >95% capacity | Delete old USMT stores, expand capacity |
| `RunnerCPUHigh` | >90% for 5 min | Reduce concurrency or scale runners |

### PostgreSQL Queries

**Wave summary:**
```sql
SELECT wave, status, total_hosts, successful_hosts, failed_hosts, 
       ROUND(100.0 * successful_hosts / NULLIF(total_hosts,0), 2) AS success_rate_pct
FROM mig.run
WHERE wave = 'wave1'
ORDER BY started_at DESC;
```

**Top failure reasons:**
```sql
SELECT check_name, pass, COUNT(*) AS count
FROM mig.check_result
WHERE run_id = 'UUID_FROM_WAVE'
GROUP BY check_name, pass
HAVING pass = false
ORDER BY count DESC
LIMIT 10;
```

**Host migration timeline:**
```sql
SELECT host_id, phase, status, timestamp
FROM mig.migration_event
WHERE run_id = 'UUID_FROM_WAVE' AND host_id = (SELECT id FROM mig.host WHERE name = 'hostname')
ORDER BY timestamp;
```

---

## Playbook Quick Reference

| Playbook | Purpose | Runtime | Concurrency | Idempotent? |
|----------|---------|---------|-------------|-------------|
| `00_discovery_health.yml` | Check WinRM, secure channel, time sync | 5-10 min | 100+ | ✓ |
| `00a_preflight_validation.yml` | App dependencies, capacity checks | 10-20 min | 50 | ✓ |
| `02_gate_on_health.yml` | Abort if failure rate >threshold | <1 min | N/A | ✓ |
| `10_provision.yml` | Create users/groups in target | 10-30 min | 100+ | ✓ |
| `20_machine_move.yml` | USMT + domain move | 45-90 min/host | 50 (WS), 10 (servers) | ⚠️ Partial |
| `30_server_rebind.yml` | Fix services/SPNs/ACLs | 20-60 min/host | 10 | ⚠️ Partial |
| `40_validate.yml` | Post-migration checks | 5-10 min | 100+ | ✓ |
| `50_heal_winrm.yml` | Restart WinRM, fix firewall | 2-5 min | 50 | ✓ |
| `51_heal_secure_channel.yml` | Reset computer account trust | 2-5 min | 50 | ✓ |
| `99_rollback_machine.yml` | Emergency rollback to source | 30-45 min/host | 25 | ⚠️ |

**Legend:**
- ✓ Fully idempotent (safe to re-run)
- ⚠️ Partially idempotent (some tasks may fail if already done, but overall safe)

---

## Contacts & Escalation

| Role | Name | Phone | Email | Hours |
|------|------|-------|-------|-------|
| **Migration Lead** | ___________ | ___________ | ___________ | 24/7 |
| **CAB Chair** | ___________ | ___________ | ___________ | Business hours |
| **AD Team Lead** | ___________ | ___________ | ___________ | On-call |
| **Network Team** | ___________ | ___________ | ___________ | On-call |
| **CIO (escalation)** | ___________ | ___________ | ___________ | Emergency only |

**Incident Bridge:** [Zoom/Teams URL] _______________________________

**Slack Channel:** #migration-ops

**Ticketing:** [Link to ServiceNow/Jira] _______________________________

---

## Appendix: Common Commands

**Check Ansible inventory:**
```bash
ansible-inventory -i inventories/tier2_medium/hosts.ini --graph
ansible-inventory -i inventories/tier2_medium/hosts.ini --list
```

**Test connectivity:**
```bash
ansible -i inventories/tier2_medium/hosts.ini all -m ping --limit wave1_workstations
ansible -i inventories/tier2_medium/hosts.ini all -m win_ping --limit wave1_workstations
```

**Run single task on hosts:**
```bash
ansible -i inventories/tier2_medium/hosts.ini windows -m win_shell -a "Get-WmiObject Win32_ComputerSystem | Select Domain"
ansible -i inventories/tier2_medium/hosts.ini linux -m shell -a "realm list"
```

**View host facts:**
```bash
ansible -i inventories/tier2_medium/hosts.ini HOST01 -m setup
```

**Check Vault token expiry:**
```bash
vault token lookup
# Check ttl field
```

**Renew Vault token:**
```bash
vault token renew
```

**PostgreSQL connection test:**
```bash
psql -h postgres.migration.example.com -U vault -d mig -c "SELECT COUNT(*) FROM mig.host;"
```

**Grafana API test:**
```bash
curl -H "Authorization: Bearer YOUR_API_KEY" http://grafana.migration.example.com/api/health
```

---

**For detailed troubleshooting, see `docs/06_RUNBOOK_TROUBLESHOOTING.md`.**

**For rollback procedures, see `docs/07_ROLLBACK_PROCEDURES.md`.**

**For Entra Connect sync issues, see `docs/08_ENTRA_SYNC_STRATEGY.md`.**

---

**END OF RUNBOOK**

