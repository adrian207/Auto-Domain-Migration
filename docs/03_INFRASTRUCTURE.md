# Terraform Infrastructure Guide

The server migration platform includes opinionated Terraform modules used to spin up short-lived landing zones for testing
or executing migration waves. The goal is to provide reproducible infrastructure that mirrors the target environment as
closely as possible.

## Repository Layout

```
terraform/
├── modules/
│   ├── network/            # VNet/VPC, subnets, security groups
│   ├── compute/            # Source and target compute templates
│   ├── storage/            # File shares, block storage, snapshot policies
│   └── observability/      # Log Analytics / CloudWatch / Stackdriver hookups
├── azure-hub-lab/          # Example Azure landing zone
├── aws-pilot/              # Example AWS landing zone
└── gcp-sandbox/            # Example GCP landing zone
```

Each example stack provisions:
- Two source servers (Linux & Windows) with sample data sets
- Two target servers in the landing zone
- A bastion host for operators
- Storage accounts or buckets used by replication tasks
- Optional monitoring workspace for validation metrics

## Usage

```bash
cd terraform/aws-pilot
terraform init
terraform apply -var "project=server-migration" -var "region=us-east-2"
```

Variables expose network ranges, instance sizes, storage tiers, and tagging conventions. Sensitive variables (API keys,
passwords) should be supplied via environment variables or `.auto.tfvars` files stored outside version control.

## Remote State & Pipelines

- Remote state backends such as Azure Storage, S3, or Google Cloud Storage are supported out of the box.
- CI/CD pipelines can run `terraform plan` nightly to capture drift or capacity issues.
- Each landing zone outputs connection details consumed by the Ansible inventory generator (`scripts/generate-inventory.py`).

## Hardening Checklist

- Restrict inbound access to the bastion host and WinRM endpoints.
- Rotate credentials and remove environments immediately after migration completion.
- Enable encryption at rest for all storage resources.
- Tag resources with wave identifiers for cost tracking and clean-up automation.

> **Note:** The Terraform definitions ship as secure-by-default examples. Adapt them to your organisation's guard rails and
> compliance policies before running in production.
