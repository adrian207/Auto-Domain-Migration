# Ansible ADMT Automation

Automated Active Directory migration using Microsoft ADMT (Active Directory Migration Tool) orchestrated by Ansible.

## Overview

This Ansible project automates domain migration using ADMT with the following capabilities:

- **Discovery**: Automatic inventory of Active Directory objects
- **Prerequisites**: ADMT installation and configuration
- **Trust Management**: Automated domain trust setup
- **User State Backup**: USMT integration for workstation migration
- **Migration Execution**: Wave-based ADMT migration
- **Validation**: Post-migration verification
- **Rollback**: Automated rollback procedures

## Directory Structure

```
ansible/
├── roles/                          # Ansible roles
│   ├── admt_prerequisites/         # ADMT setup and prerequisites
│   ├── admt_migration/             # ADMT migration execution
│   ├── discovery/                  # AD discovery and inventory
│   ├── domain_trust/               # Trust relationship configuration
│   ├── usmt_backup/                # User state migration backup
│   └── post_migration_validation/  # Post-migration validation
├── playbooks/                      # Orchestration playbooks
│   ├── 00_discovery.yml            # Discovery phase
│   ├── 01_prerequisites.yml        # Prerequisites setup
│   ├── 02_trust_configuration.yml  # Trust configuration
│   ├── 03_usmt_backup.yml          # USMT backup
│   ├── 04_migration.yml            # Migration execution
│   ├── 05_validation.yml           # Validation
│   ├── 99_rollback.yml             # Rollback procedures
│   └── master_migration.yml        # Complete workflow
├── inventory/                      # Inventory files
│   └── hosts.ini                   # Host definitions
├── group_vars/                     # Group variables
│   ├── domain_controllers.yml      # DC configuration
│   └── workstations.yml            # Workstation configuration
├── host_vars/                      # Host-specific variables
│   ├── source_dc.yml               # Source DC variables
│   └── target_dc.yml               # Target DC variables
└── files/                          # Supporting files
    └── ADMT-Functions.psm1         # PowerShell module
```

## Prerequisites

### Control Node (Ansible Container)
- Ansible 2.12+
- Python 3.8+
- `ansible.windows` collection
- `community.windows` collection

### Windows Targets
- Windows Server 2019/2022
- WinRM configured and enabled
- PowerShell 5.1+
- Administrator access

### Azure Resources
- PostgreSQL Flexible Server (state database)
- Azure Storage Account (artifacts and backups)
- Azure Key Vault (secrets management)

## Installation

### 1. Install Ansible Collections

```bash
ansible-galaxy collection install ansible.windows
ansible-galaxy collection install community.windows
```

### 2. Configure Environment Variables

Create a `.env` file or export variables:

```bash
# Windows Authentication
export ANSIBLE_WIN_USER="administrator@target.corp.local"
export ANSIBLE_WIN_PASSWORD="SecurePassword123!"

# Domain Configuration
export TRUST_PASSWORD="TrustPassword123!"

# Azure Storage
export AZURE_STORAGE_ACCOUNT="yourstorageaccount"
export AZURE_STORAGE_SAS_TOKEN="?sv=2021-06-08&ss=b&srt=sco..."

# PostgreSQL Database
export POSTGRES_HOST="your-pg-server.postgres.database.azure.com"
export POSTGRES_USER="pgadmin"
export POSTGRES_PASSWORD="PG_Password123!"

# API Authentication
export API_TOKEN="your-api-token-here"
```

### 3. Update Inventory

Edit `inventory/hosts.ini` with your domain controller IPs:

```ini
[domain_controllers]
source_dc ansible_host=10.0.1.10
target_dc ansible_host=10.0.2.10
```

### 4. Verify Connectivity

```bash
ansible -i inventory/hosts.ini domain_controllers -m win_ping
```

## Usage

### Option 1: Run Complete Migration (All Phases)

```bash
ansible-playbook -i inventory/hosts.ini playbooks/master_migration.yml \
  -e "migration_wave=1"
```

### Option 2: Run Individual Phases

#### Phase 0: Discovery

```bash
ansible-playbook -i inventory/hosts.ini playbooks/00_discovery.yml
```

#### Phase 1: Prerequisites

```bash
ansible-playbook -i inventory/hosts.ini playbooks/01_prerequisites.yml
```

#### Phase 2: Trust Configuration

```bash
ansible-playbook -i inventory/hosts.ini playbooks/02_trust_configuration.yml
```

#### Phase 3: USMT Backup (Workstations)

```bash
ansible-playbook -i inventory/hosts.ini playbooks/03_usmt_backup.yml
```

#### Phase 4: Migration

```bash
ansible-playbook -i inventory/hosts.ini playbooks/04_migration.yml \
  -e "migration_wave=1" \
  -e "migration_batch_id=wave1_users"
```

#### Phase 5: Validation

```bash
ansible-playbook -i inventory/hosts.ini playbooks/05_validation.yml \
  -e "migration_batch_id=wave1_users"
```

### Rollback

```bash
ansible-playbook -i inventory/hosts.ini playbooks/99_rollback.yml \
  -e "migration_batch_id=wave1_users"
```

## Migration Workflow

### 1. Discovery Phase

- Inventories all users, computers, and groups
- Analyzes dependencies (GPOs, DNS, FSMO roles)
- Generates JSON reports
- Uploads results to state database

**Output**: `/opt/ansible/data/discovery/<date>/`

### 2. Wave Planning

Based on discovery results, create wave files:

```json
// /opt/ansible/data/waves/wave_1_users.json
[
  "user1",
  "user2",
  "user3"
]

// /opt/ansible/data/waves/wave_1_groups.json
[
  "group1",
  "group2"
]

// /opt/ansible/data/waves/wave_1_computers.json
[
  "computer1",
  "computer2"
]
```

### 3. Execute Migration

Run migration playbook for each wave:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/04_migration.yml -e "migration_wave=1"
ansible-playbook -i inventory/hosts.ini playbooks/04_migration.yml -e "migration_wave=2"
ansible-playbook -i inventory/hosts.ini playbooks/04_migration.yml -e "migration_wave=3"
```

### 4. Validate

After each wave, validate the migration:

```bash
ansible-playbook -i inventory/hosts.ini playbooks/05_validation.yml \
  -e "migration_batch_id=wave_1_<timestamp>"
```

## Configuration

### Domain Trust Types

Edit `group_vars/domain_controllers.yml`:

```yaml
trust_type: "one-way"  # Options: one-way, two-way
```

### ADMT Settings

Edit `host_vars/target_dc.yml`:

```yaml
install_admt: true
install_pes: false  # Password Export Server
target_ou: "OU=Migrated Users,DC=target,DC=corp,DC=local"
```

### USMT Configuration

Edit `group_vars/workstations.yml`:

```yaml
upload_to_azure: true
cleanup_local_backup: false
reboot_after_migration: true
```

## Security Considerations

### 1. Use Ansible Vault for Secrets

```bash
ansible-vault create secrets.yml
```

Add sensitive variables:

```yaml
ansible_password: "SecurePassword123!"
trust_password: "TrustPassword123!"
postgres_password: "PG_Password123!"
```

Use in playbooks:

```bash
ansible-playbook playbooks/04_migration.yml \
  --vault-password-file .vault_pass \
  -e "@secrets.yml"
```

### 2. WinRM Over HTTPS

Configure WinRM to use HTTPS:

```ini
[all:vars]
ansible_connection=winrm
ansible_winrm_transport=ntlm
ansible_winrm_server_cert_validation=validate
ansible_port=5986
```

### 3. Least Privilege

- Use dedicated service accounts for Ansible
- Grant only necessary AD permissions
- Rotate credentials regularly

## Monitoring and Logging

### Logs Location

- **Ansible logs**: `/opt/ansible/data/logs/`
- **ADMT logs**: `C:\ADMT\Logs\` (on target DC)
- **USMT logs**: `C:\USMTBackup\<hostname>\scanstate.log`

### Database Integration

All migration operations are logged to PostgreSQL:

- Discovery results: `discovery` table
- Migration batches: `migration_batches` table
- Validation results: `validation_results` table
- USMT backups: `usmt_backups` table

### Prometheus Monitoring

Metrics are exposed for:

- Migration progress
- Validation success rate
- Backup status
- Error counts

## Troubleshooting

### Common Issues

#### 1. WinRM Connection Failed

```bash
# Test WinRM connectivity
Test-WSMan -ComputerName target_dc -Port 5986

# Configure WinRM
winrm quickconfig
winrm set winrm/config/service/auth '@{Basic="true"}'
```

#### 2. ADMT Installation Failed

- Verify ADMT installer is uploaded to Azure Storage
- Check product GUID in `admt_prerequisites/tasks/install_admt.yml`
- Review logs at `C:\ADMT\Logs\`

#### 3. Trust Creation Failed

- Verify DNS resolution between domains
- Check firewall rules (ports 389, 88, 445, 135, 3268)
- Ensure trust password meets complexity requirements

#### 4. USMT Backup Failed

- Verify sufficient disk space
- Check Azure Storage SAS token permissions
- Review USMT logs for specific errors

## Best Practices

### 1. Test in Non-Production

Always test migration in a demo environment first:

```bash
# Use Tier 1 (vSphere demo environment)
ansible-playbook -i inventory/tier1_hosts.ini playbooks/master_migration.yml
```

### 2. Migrate in Waves

- **Wave 1**: Pilot users (10-20 users)
- **Wave 2**: Department-by-department
- **Wave 3**: Remaining users

### 3. Backup Before Migration

- Take VM snapshots of both DCs
- Backup Active Directory with `wbadmin`
- Ensure USMT backups complete successfully

### 4. Validate After Each Wave

Run validation playbook and review reports before proceeding.

### 5. Communication Plan

- Notify users before migration
- Provide support contact information
- Schedule migrations during off-hours

## Support

For issues or questions:

1. Review logs in `/opt/ansible/data/logs/`
2. Check validation reports
3. Review documentation in `docs/`
4. Consult `docs/26_REVISED_TIER2_WITH_ADMT.md` for architecture details

## License

MIT

## Author

Auto Domain Migration Project

