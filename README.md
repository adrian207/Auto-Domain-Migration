# Pure Server Migration Automation

![Version](https://img.shields.io/badge/version-1.0-blue)
![Status](https://img.shields.io/badge/status-active-brightgreen)
![Platform](https://img.shields.io/badge/platform-multi_cloud-blue)
![License](https://img.shields.io/badge/license-MIT-blue)

The Auto Domain Migration project has been rebuilt as a **pure server migration solution**. The repository now focuses entirely
on migrating application, database, and infrastructure servers between data centres or clouds with consistent automation.

## Key Features

- **Server Discovery** – Inventory services, storage, and dependencies across Windows and Linux hosts.
- **Prerequisites Automation** – Configure replication tooling, validate credentials, and prepare staging storage.
- **Flexible Replication** – Support Rsync, Robocopy, and database dumps via pluggable handlers.
- **Controlled Cutover** – Coordinate pre-cutover actions, delta sync, DNS/IP updates, and service start-up.
- **Robust Validation** – Capture port, command, and HTTP checks with structured artifacts.
- **Rollback Ready** – Automate restoration of services and snapshots when acceptance fails.
- **Terraform Landing Zones** – Provision pilot environments in AWS, Azure, and GCP for migration rehearsals.

## Repository Layout

```
ansible/           # Ansible automation (playbooks, roles, inventory)
docs/              # Architecture, operations, and infrastructure guides
scripts/           # Utility scripts (inventory generation, backup helpers)
terraform/         # Multi-cloud landing zone examples
tests/             # Lightweight validation suite
```

## Quick Start

1. **Provision Infrastructure** (optional) using Terraform:
   ```bash
   cd terraform/aws-pilot
   terraform init
   terraform apply -var "bastion_ami=ami-xxxxxxxx"
   ```
2. **Generate Inventory** from Terraform outputs (or craft manually):
   ```bash
   ./scripts/generate-inventory.py terraform/aws-pilot --wave wave1
   ```
3. **Install Ansible Collections**:
   ```bash
   ansible-galaxy collection install ansible.windows community.windows ansible.posix
   ```
4. **Run Discovery**:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/00_discovery.yml -e wave_id=wave1
   ```
5. **Execute Full Migration**:
   ```bash
   ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/master_migration.yml -e wave_id=wave1
   ```

## Documentation

Comprehensive documentation is available in [docs/](docs/):
- [00_OVERVIEW.md](docs/00_OVERVIEW.md) – Executive summary of the solution.
- [01_ARCHITECTURE.md](docs/01_ARCHITECTURE.md) – Technical architecture and data flow.
- [02_OPERATIONS.md](docs/02_OPERATIONS.md) – Operational runbook for migration waves.
- [03_INFRASTRUCTURE.md](docs/03_INFRASTRUCTURE.md) – Terraform landing zone reference.

## Testing

- PowerShell Pester tests validate Ansible structure: `cd tests; ./scripts/Invoke-Tests.ps1 -Suite Integration`
- Terraform validation helper ensures IaC syntax correctness: `tests/terraform/validate_terraform.sh terraform/aws-pilot`

## Contributing

1. Fork and clone the repository.
2. Create a branch for your feature or fix.
3. Ensure tests pass and documentation is updated.
4. Submit a pull request describing the change and migration impact.

## License

This project is released under the MIT License. See [LICENSE](LICENSE) for details.
