# Server Migration Test Suite

This directory contains lightweight test scaffolding for the pure server migration solution. The focus is on validating playbook
structure, Terraform syntax, and helper scripts used throughout the workflow.

## Structure

```
tests/
├── integration/
│   └── Test-ServerMigration.Tests.ps1    # Pester tests for Ansible artifacts
├── terraform/
│   └── validate_terraform.sh             # Static Terraform validation helper
└── scripts/
    └── Invoke-Tests.ps1                  # Entry point to run all checks
```

## Running Tests

### PowerShell Pester Tests

```powershell
cd tests
./scripts/Invoke-Tests.ps1 -Suite Integration
```

### Terraform Validation

```bash
cd tests/terraform
./validate_terraform.sh ../../terraform/aws-pilot
```

These scripts are designed for local use and CI pipelines to ensure the automation remains healthy as you extend it.
