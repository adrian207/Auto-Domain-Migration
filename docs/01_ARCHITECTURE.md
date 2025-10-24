# Architecture – Pure Server Migration Platform

## Component Overview

| Component | Responsibility |
| --------- | -------------- |
| **Control Node** | Runs Ansible, stores discovery and replication metadata, and coordinates Terraform deployments. |
| **Source Servers** | Workloads being migrated. They expose services, data, and configuration captured by discovery tasks. |
| **Target Landing Zone** | Destination environment provisioned by Terraform; can be cloud-based or on-premises virtualization. |
| **Replication Staging** | Optional cache where bulk data is staged before the final cutover. |
| **Observability Stack** | Aggregates logs, metrics, and validation reports for audit purposes. |

## Logical Flow

1. **Discovery**
   - Collect host facts, installed applications, running services, open ports, mounted volumes, and database instances.
   - Generate structured reports (YAML/JSON) stored on the control node under `artifacts/discovery/<timestamp>/`.
2. **Prerequisite Enforcement**
   - Validate connectivity from control node to each host.
   - Install required agents (Rsync, Robocopy wrapper, database dump tools) depending on OS.
   - Prepare file system targets on the landing zone with correct permissions and capacity alerts.
3. **Replication**
   - Continuous file replication using Rsync for Linux/Unix workloads.
   - Robocopy / Storage Migration Service wrapper for Windows file servers.
   - Database replicas triggered via pluggable hooks (MySQL dump, SQL Server `sqlpackage`, PostgreSQL `pg_dump`).
   - Replication schedules captured in `group_vars/server_replication.yml` and can be tuned per workload class.
4. **Cutover**
   - Quiesce the source (drain connections, stop services, snapshot volumes).
   - Execute delta replication to capture last-minute changes.
   - Flip DNS, load balancers, or IP assignments if required.
   - Bring up services on the target in the correct dependency order.
5. **Validation**
   - Verify service ports, health endpoints, and process states.
   - Perform checksum validation on critical data sets.
   - Run smoke tests defined in `vars/validation_checks.yml`.
6. **Rollback**
   - If validation fails, revert DNS/IP changes, restart the source, and optionally restore from snapshots.
   - Log incident details for review before a reattempt.

## Data Model

All phases emit records into a simple JSON Lines log that can be ingested into your preferred data store.

```json
{
  "wave": "2025-02-01-wave1",
  "phase": "replication",
  "host": "fileserver01",
  "status": "in-progress",
  "bytes_transferred": 134217728,
  "duration_seconds": 42,
  "timestamp": "2025-02-01T18:22:42Z"
}
```

## Security Model

- SSH keys (Linux) and WinRM certificates (Windows) are managed with Ansible Vault or HashiCorp Vault.
- No domain-level privileges are required; only local admin (or sudo) rights on the servers being migrated.
- Secrets consumed by Terraform (cloud credentials) are stored in environment variables or remote state backends.

## Extensibility

- **Hooks** – Drop scripts into `ansible/hooks/pre_cutover` or `ansible/hooks/post_validation` to integrate with CMDB,
  monitoring, or ticketing systems.
- **Custom Replication Methods** – Extend the `server_replication` role by adding task files under
  `tasks/methods/<method>.yml` and referencing them from inventory variables.
- **API Integration** – Use the `artifacts/status.jsonl` output for pipelines or dashboards.

## Reference Diagrams

```
+----------------+       Ansible SSH/WinRM       +-----------------+
|  Control Node  | ----------------------------> |  Source Servers |
|  (Automation)  | <---------------------------- |  (Wave Scope)   |
+----------------+         Artifact Sync         +-----------------+
        |                                                |
        | Terraform                                      |
        v                                                v
+----------------+                             +------------------+
| Landing Zone   | <------ Replication -------- | Target Servers   |
| (Cloud/On-Prem)|                              | (New Workloads)  |
+----------------+                             +------------------+
```

The architecture is intentionally modular so teams can swap replication technologies without rewriting the control plane.
