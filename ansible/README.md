# Ansible Server Migration Automation

This Ansible project implements the pure server migration workflow introduced in this repository. It replaces the legacy
Active Directory tooling with host-centric automation that runs consistently across Windows and Linux workloads.

## Capabilities

- **Discovery** – Capture host facts, disks, services, and database instances.
- **Prerequisites** – Prepare replication tooling (Rsync, Robocopy, DB export utilities) and validate connectivity.
- **Replication** – Execute continuous sync jobs tailored per workload.
- **Cutover** – Quiesce the source, perform delta sync, update DNS/IPs, and start services on the target.
- **Validation** – Run port, process, and checksum validations to confirm success.
- **Rollback** – Restore services or snapshots if acceptance criteria are not met.

## Directory Layout

```
ansible/
├── inventory/
│   ├── hosts.ini                   # Static inventory template
│   └── generated.json              # Optional inventory generated from Terraform outputs
├── playbooks/
│   ├── 00_discovery.yml            # Collect workload information
│   ├── 01_prerequisites.yml        # Prepare tooling and credentials
│   ├── 02_replication.yml          # Start replication jobs
│   ├── 03_cutover.yml              # Perform wave cutover
│   ├── 04_validation.yml           # Validate workloads post-cutover
│   ├── 99_rollback.yml             # Rollback workflow
│   └── master_migration.yml        # Orchestrates all phases
├── roles/
│   ├── server_discovery/
│   ├── server_prerequisites/
│   ├── server_replication/
│   ├── server_cutover/
│   ├── server_validation/
│   └── server_rollback/
├── group_vars/
│   ├── source_servers.yml
│   └── target_servers.yml
├── host_vars/                      # Host-specific overrides
├── files/
│   └── robocopy-wrapper.ps1        # Helper for Windows replication
├── awx-templates/
│   └── job-templates.yml           # Tower/AWX template definitions
└── PHASE2_SUMMARY.md               # Summary of Ansible build-out
```

## Getting Started

1. **Install collections**
   ```bash
   ansible-galaxy collection install ansible.windows community.windows ansible.posix
   ```
2. **Configure credentials** via Ansible Vault or environment variables referenced in `inventory/hosts.ini`.
3. **Populate inventory** with `source_servers` and `target_servers`. Optionally run `scripts/generate-inventory.py` after
   Terraform deployments.
4. **Run discovery** to capture the current state:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00_discovery.yml
   ```
5. **Execute migration waves** using `ansible/playbooks/master_migration.yml`.

## Inventory Overview

### `source_servers`
Systems currently hosting workloads. Provide `replication_method`, service stop commands, and snapshot hooks.

### `target_servers`
Destination hosts where workloads will be cut over. Provide mount points, service start commands, and validation endpoints.

## Artifact Storage

All playbooks emit structured logs under `artifacts/` on the control node:
- `artifacts/discovery/<wave>/` – Discovery reports per host
- `artifacts/replication/<wave>/` – Replication status and metrics
- `artifacts/validation/<wave>.yml` – Validation results for dashboards

## Running Individual Phases

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/02_replication.yml -e wave_id=wave1
```

Each playbook accepts `wave_id` and optional tuning variables defined in `group_vars`.

## Rollback

If validation fails, execute:
```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/99_rollback.yml -e wave_id=wave1
```
This stops target services, restores snapshots, re-enables source services, and records the incident.
