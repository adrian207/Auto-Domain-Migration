# Pure Server Migration Solution – Overview

The Auto Domain Migration project has been re-imagined as a **pure server migration solution** that focuses on moving
application, database, and infrastructure servers between environments with minimal downtime. The platform now targets
four repeatable migration phases and strips out all identity and Active Directory specific logic.

## Guiding Principles

1. **Server-Centric** – Every workflow centers on server workloads, their data, and their dependencies.
2. **Automation First** – Discovery, replication, cutover, and validation are fully automated through Ansible playbooks and
   Terraform-based infrastructure as code.
3. **Repeatable Waves** – Migrations are executed in waves that share common runbooks, metrics, and approval checkpoints.
4. **Observability Everywhere** – Each phase emits structured facts that can be forwarded to CMDB, CM tools, or SIEM
   systems for auditing and trend analysis.

## Supported Scenarios

- **Data center consolidation** between on-premises sites
- **Cloud migrations** from on-premises or alternative clouds into Azure, AWS, or GCP
- **Platform refresh** where workloads are rebuilt on newer operating systems or hardware
- **Disaster recovery rehearsal** leveraging the same replication and cutover mechanics for DR validation

## Phases at a Glance

| Phase | Goal | Key Automation |
| ----- | ---- | --------------- |
| Discovery | Enumerate workloads, services, storage, and dependencies. | Ansible role `server_discovery` | 
| Prerequisites | Prepare source and target endpoints with agents, credentials, and storage. | Ansible role `server_prerequisites` |
| Replication | Continuously copy file systems, databases, and configuration to the target landing zone. | Ansible role `server_replication` |
| Cutover & Validation | Quiesce the source, perform delta sync, bring up the target, and validate health. | Ansible roles `server_cutover` & `server_validation` |
| Rollback | Reverse or retry changes if validation fails or acceptance is withheld. | Ansible role `server_rollback` |

## Key Technologies

- **Ansible** orchestrates every migration phase across Windows and Linux servers.
- **Terraform** provisions transient landing zones used for staging, testing, or disaster recovery.
- **PowerShell & Bash helpers** provide OS-specific functionality for replication or snapshot orchestration.
- **HashiCorp Vault (optional)** centralises secrets required by the automation.

## What Changed

- All Active Directory tooling, trust automation, and identity data generation have been removed.
- Documentation was rewritten to focus exclusively on server workloads.
- New roles and playbooks drive host-centric discovery, replication, and validation.
- Testing scripts now validate server migration paths rather than AD constructs.

Continue to [01_ARCHITECTURE.md](01_ARCHITECTURE.md) for a deeper technical dive.
