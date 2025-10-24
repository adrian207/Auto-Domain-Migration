# Operations Runbook

This runbook standardises how teams execute server migrations using the automation delivered in this repository.

## 1. Planning

1. Build a workload catalogue using the discovery playbook output.
2. Classify servers by criticality, downtime tolerance, and replication method (file, database, VM image).
3. Define wave scope, entry criteria, exit criteria, and rollback owners.
4. Capture credential requirements in Vault or an encrypted variables file.

## 2. Pre-Migration Checklist

- [ ] Inventory validated and signed off.
- [ ] Network connectivity (SSH/WinRM) confirmed.
- [ ] Target storage provisioned with 20% free capacity buffer.
- [ ] Replication method documented and tested on a non-production host.
- [ ] Validation checks defined (port probes, synthetic transactions, API health calls).

## 3. Executing a Wave

1. **Discovery Refresh**
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00_discovery.yml \
     -e wave_id=2025-02-wave1
   ```
2. **Prerequisites**
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/01_prerequisites.yml
   ```
3. **Replication**
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/02_replication.yml \
     -e replication_window=4h
   ```
4. **Cutover**
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/03_cutover.yml \
     -e wave_id=2025-02-wave1
   ```
5. **Validation**
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/04_validation.yml
   ```
6. **Acceptance / Rollback**
   - If validation fails, execute the rollback plan:
     ```bash
     ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/99_rollback.yml \
       -e wave_id=2025-02-wave1
     ```

## 4. Artifacts

All playbooks write status to `artifacts/status.jsonl`. Validation results are additionally exported to
`artifacts/validation/<wave_id>.yaml` for long-term storage.

## 5. Roles & Responsibilities

| Role | Responsibilities |
| ---- | ---------------- |
| Migration Lead | Approves wave scope, signs off entry/exit criteria, coordinates stakeholders. |
| Automation Engineer | Maintains inventory, playbooks, and Terraform definitions. |
| Application Owner | Confirms outage windows, validates functionality, approves cutover. |
| Platform Owner | Ensures compute, storage, and network capacity is available on the target platform. |

## 6. Communication Plan

- Daily standups during active migration windows.
- Cutover bridge opens 1 hour before service outage.
- Slack/Teams channel `#server-migration` for asynchronous updates.
- Post-migration review completed within 48 hours with action tracking.

## 7. Rollback Strategy

1. Invoke `ansible/playbooks/99_rollback.yml`.
2. Restore snapshots or re-enable replication to the original source.
3. Revert DNS, load balancer, or IP changes.
4. Notify stakeholders and document the reason for rollback.
5. Analyse logs to remediate before scheduling a new attempt.

## 8. Continuous Improvement

- Track migration duration, data volumes, and validation findings per wave.
- Feed lessons learned into updated prerequisite or validation tasks.
- Expand the playbooks with application-specific checks as patterns emerge.
