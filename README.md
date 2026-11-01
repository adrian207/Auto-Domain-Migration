# Auto-Domain-Migration

Ansible, PowerShell and Terraform for migrating users, groups and computers between Active Directory domains with Microsoft ADMT, plus file-server migration with Storage Migration Service. It includes test environments at three sizes on Azure and two on VMware vSphere, scripts that fill a source domain with realistic test data, and Pester tests.

## How a migration runs

`ansible/playbooks/master_migration.yml` runs the phases in order; each phase is also its own playbook:

| Phase | Playbook | Role | What it does |
|---|---|---|---|
| 0 | `00_discovery.yml` | `discovery` | Inventories users, groups, computers and OUs in the source domain |
| 1 | `01_prerequisites.yml` | `admt_prerequisites` | Installs and prepares ADMT and its prerequisites on the domain controllers |
| 2 | `02_trust_configuration.yml` | `domain_trust` | Creates the trust between source and target domains |
| 3 | `03_usmt_backup.yml` | `usmt_backup` | Captures user state on workstations with USMT `scanstate` |
| 4 | `04_migration.yml` | `admt_migration` | Runs the ADMT migration on the target DC |
| 5 | `05_validation.yml` | `post_migration_validation` | Checks migrated objects |
| | `99_rollback.yml` | | Rollback steps (see `docs/07_ROLLBACK_PROCEDURES.md`) |

The PowerShell functions behind the ADMT steps are in `ansible/files/ADMT-Functions.psm1`, with Pester tests next to them. Other playbooks:

- `sms/01_setup_file_servers.yml`: file shares and Storage Migration Service for file-server moves
- `selfhealing/restart-dc-services.yml`, `selfhealing/cleanup-disk-space.yml`: remediation runbooks
- `dr/automated-failover.yml`: disaster-recovery failover steps
- `awx-templates/job-templates.yml`: job templates for running the playbooks from AWX

## Test environments (Terraform)

| Directory | Platform | Builds |
|---|---|---|
| `terraform/azure-free-tier` | Azure, demo | Source and target DCs, a test workstation, source and target file servers (Windows), a Guacamole jump host and an Ansible controller (Linux), PostgreSQL Flexible Server |
| `terraform/azure-tier2` | Azure, production-sized | The tier 1 roles plus a monitoring VM and an SMS orchestrator, a load balancer for Ansible, PostgreSQL with a read replica, Azure Files shares, Recovery Services backups and metric alerts |
| `terraform/azure-tier3` | Azure, enterprise | AKS with AWX, Vault, MinIO, PostgreSQL, Prometheus and Loki from Helm (`deploy-helm-stack.sh`), plus clustered file servers and an SMS orchestrator; domain controllers are assumed to exist |
| `terraform/vsphere-tier1` | vSphere, demo | Guacamole, Ansible, PostgreSQL, source and target DCs, a test workstation |
| `terraform/vsphere-tier2` | vSphere, production-sized | As tier 1 plus monitoring, with DRS anti-affinity rules |

`terraform/modules/` has shared Azure network and compute modules. All seven Terraform directories pass `terraform validate`. See [docs/01_DEPLOYMENT_TIERS.md](docs/01_DEPLOYMENT_TIERS.md).

## Test data

- `scripts/ad-test-data/Generate-ADTestData.ps1` builds an OU structure, users, groups, computers and group memberships in a lab source domain ([docs/29_AD_TEST_DATA_GENERATION.md](docs/29_AD_TEST_DATA_GENERATION.md))
- `scripts/Generate-TestFileData.ps1` creates files and folders to migrate
- `scripts/azure/`: backup and cost-optimisation helpers; `scripts/zfs/`: ZFS snapshot configuration

## Requirements

- Ansible with the `ansible.windows` collection (`ansible-galaxy collection install ansible.windows`), and WinRM access to the Windows hosts
- Microsoft ADMT and USMT media (not included)
- Terraform 1.5+ with the Azure CLI or vSphere credentials, for the test environments
- PowerShell 5.1 or 7 with Pester 5 for the tests

## Quick start (Azure demo environment)

```bash
git clone https://github.com/adrian207/Auto-Domain-Migration.git
cd Auto-Domain-Migration/terraform/azure-free-tier
cp terraform.tfvars.example terraform.tfvars    # admin credentials, allowed IP, region
terraform init && terraform apply
```

Then, on the Ansible controller, fill in `ansible/inventory/hosts.ini` and the `host_vars` for the source and target DCs, and run:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/00_discovery.yml
ansible-playbook -i inventory/hosts.ini playbooks/master_migration.yml
```

Populate the source domain first with `Generate-ADTestData.ps1` if it is empty.

## Tests and CI

`tests/` holds Pester suites for the ADMT functions, the Azure infrastructure, ADMT and file-server migration, end-to-end migration and DR readiness; `tests/scripts/Invoke-AllTests.ps1` runs them. Most need a deployed environment. `tests/DEMO_OUTPUT.txt` is an illustration of the output, not a recorded run.

GitHub Actions run ansible-lint, `terraform validate`, the PowerShell tests and pull-request checks when the relevant files change. `deploy-tier1.yml` deploys the Azure demo environment and runs only when started by hand.

## Documentation

[docs/README.md](docs/README.md) indexes the design documents, including the [master design](docs/00_MASTER_DESIGN.md), [file-server migration](docs/28_FILE_SERVER_MIGRATION_STRATEGY.md), [rollback](docs/07_ROLLBACK_PROCEDURES.md), [DR runbook](docs/32_DISASTER_RECOVERY_RUNBOOK.md) and [Entra ID sync](docs/08_ENTRA_SYNC_STRATEGY.md) strategies. `docs/training/` has training material.

## Status and limitations

- The playbooks, roles and Terraform pass syntax checks (`ansible-playbook --syntax-check`, `terraform validate`, the PowerShell parser). An end-to-end migration has not been recorded in this repository.
- **Cost:** the "free tier" environment runs seven VMs (five Windows) and a PostgreSQL server. The Azure free account covers 750 B1s hours a month, about one VM, so expect charges and stop VMs when idle. `B1s` (1 GB memory) is also very small for domain controllers.
- Several design documents (wave management UI, container platform, self-healing) describe a larger platform than the playbooks implement.

## License

MIT. See [LICENSE](LICENSE).

## Author

Adrian Johnson · [github.com/adrian207](https://github.com/adrian207)
