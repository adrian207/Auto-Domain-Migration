# Azure Tier 2 (Production) Deployment

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Purpose:** Deploy production-scale AD migration environment on Azure with high availability

---

## Overview

This Terraform configuration deploys a production-grade Active Directory migration environment on Microsoft Azure with enterprise features including high availability, monitoring, backup, and security.

### What Gets Deployed

**High Availability Infrastructure:**
- **Guacamole Bastion Host** (Standard_D2s_v5) - Web-based secure access with NSG auto-update
- **Ansible Controllers** (2-3 instances, Standard_D8s_v5) - Load balanced for HA
- **PostgreSQL Flexible Server** (GP_Standard_D4s_v3) - Zone-redundant HA cluster
- **Monitoring Stack** (Standard_D4s_v5) - Prometheus + Grafana
- **Domain Controllers** (2x Standard_D4s_v5) - Source and target domains
- **Storage Account** (GRS) - Geo-redundant artifact storage

**Enterprise Features:**
- ✅ Availability Zones for VM redundancy
- ✅ PostgreSQL High Availability (zone-redundant)
- ✅ Azure Key Vault for secrets management
- ✅ Azure Backup with 30-day retention
- ✅ Log Analytics workspace
- ✅ Application Insights telemetry
- ✅ NSG Flow Logs
- ✅ Azure Monitor alerts

**Estimated Monthly Cost:** $800-2000 (depending on usage and region)

---

## Prerequisites

1. **Azure Subscription** with sufficient quota
2. **Terraform** >= 1.5.0 installed
3. **Azure CLI** installed and authenticated (`az login`)
4. **SSH Key** for Linux VMs
5. **Production credentials** (strong, unique passwords)

---

## Quick Start

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Critical Configuration:**
- Set strong `admin_password` and `postgres_admin_password`
- Set `guacamole_db_password`
- Add your `ssh_public_key`
- Set `allowed_ip_ranges` to your corporate IP ranges
- Configure `location` and `secondary_location`
- Review VM sizes and adjust for your needs

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the Plan

```bash
terraform plan -out=tfplan
```

### 4. Deploy

```bash
terraform apply tfplan
```

Deployment takes ~30-45 minutes.

---

## Post-Deployment Setup

See the `next_steps` output for detailed instructions. Key steps:

1. **Secure Guacamole** - Change default password immediately
2. **Configure Ansible Controllers** - Set up AWX for centralized management
3. **Initialize PostgreSQL** - Databases are created but need initial schema
4. **Promote Domain Controllers** - Install AD DS and configure domains
5. **Configure Monitoring** - Set up Grafana dashboards
6. **Test Backups** - Verify Azure Backup is working
7. **Review Security** - Check NSG rules, Key Vault access, alerts

---

## High Availability Features

### Ansible Controllers
- Multiple instances (2-3) behind Azure Load Balancer
- Distributed across availability zones
- Shared PostgreSQL state store

### PostgreSQL Database
- Zone-redundant with automatic failover
- Geo-redundant backups (35-day retention)
- Read replicas can be added if needed

### Monitoring
- Prometheus for metrics collection
- Grafana for visualization
- Azure Monitor for platform metrics
- Application Insights for telemetry

---

## Backup and Recovery

- **VM Backups**: Daily backups at 11 PM UTC, 30-day retention
- **Database Backups**: Automated PostgreSQL backups, 35-day retention, geo-redundant
- **Storage**: GRS replication with soft delete (30 days)

**Recovery Vault:** `{project}-{env}-rsv`

---

## Monitoring and Alerts

Access monitoring at: `http://{monitoring-vm-ip}:3000`

**Default Grafana credentials:** admin / admin (change immediately)

**Configured Alerts:**
- PostgreSQL CPU > 80%
- PostgreSQL Memory > 85%
- PostgreSQL Storage > 85%
- Connection failures > 10/minute

---

## Security

- All secrets stored in Azure Key Vault
- NSG rules restrict access to known IPs
- TLS 1.2+ enforced on all services
- Managed identities for Azure resource access
- NSG Flow Logs enabled for audit
- Fail2ban on bastion host

**Review:**
- Update NSG rules to restrict `allowed_ip_ranges`
- Rotate passwords regularly
- Enable Azure Security Center recommendations
- Configure MFA for admin accounts

---

## Scaling

### Scale Ansible Controllers

```bash
# In terraform.tfvars
num_ansible_controllers = 3  # Increase as needed
```

### Scale PostgreSQL

```bash
# In terraform.tfvars
postgres_sku_name = "GP_Standard_D8s_v3"  # Scale up as needed
postgres_storage_mb = 262144  # 256 GB
```

---

## Cost Management

Use Azure Cost Management to monitor spend:

```bash
az consumption usage list --start-date 2025-10-01 --end-date 2025-10-31
```

**Set budget alerts** in Azure Portal to avoid surprises.

---

## Troubleshooting

See `docs/05_RUNBOOK_OPERATIONS.md` for detailed troubleshooting procedures.

Common issues:
- Guacamole not accessible: Check NSG rules and `allowed_ip_ranges`
- PostgreSQL connection timeout: Verify VNet integration and firewall rules
- VM backup fails: Check Recovery Vault permissions

---

## Cleanup

**Warning:** This destroys ALL resources and data!

```bash
terraform destroy
```

---

## Documentation

- [Master Design Document](../../docs/00_MASTER_DESIGN.md)
- [Azure Implementation Guide](../../docs/18_AZURE_FREE_TIER_IMPLEMENTATION.md)
- [Operations Runbook](../../docs/05_RUNBOOK_OPERATIONS.md)
- [Rollback Procedures](../../docs/07_ROLLBACK_PROCEDURES.md)

---

**Author:** Adrian Johnson  
**License:** [To be determined]  
**Last Updated:** October 2025


