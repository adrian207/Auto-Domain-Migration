# vSphere Tier 2 (Production) Deployment

**Author:** Adrian Johnson <adrian207@gmail.com>  
**Purpose:** Deploy production-scale AD migration environment on vSphere with HA and DRS

---

## Overview

Enterprise-grade deployment on VMware vSphere with high availability, DRS anti-affinity, and production-scale resources.

### What Gets Deployed

**High Availability Infrastructure:**
- **Guacamole Bastion** (4 vCPU, 8 GB RAM)
- **Ansible/AWX Controllers** (2-3 instances, 8 vCPU, 32 GB RAM each)
- **PostgreSQL Cluster** (3 nodes with Patroni + etcd, 4 vCPU, 16 GB RAM each)
- **Monitoring Stack** (Prometheus + Grafana, 4 vCPU, 16 GB RAM)
- **Domain Controllers** (2x Windows Server 2022, 4 vCPU, 8 GB RAM)

**Enterprise Features:**
- ✅ DRS anti-affinity rules (VMs on different hosts)
- ✅ vMotion support for zero-downtime maintenance
- ✅ PostgreSQL HA cluster with automatic failover
- ✅ Load-balanced Ansible controllers
- ✅ Resource pools with reservations
- ✅ Comprehensive monitoring

**Resource Requirements:**
- vCPUs: 40-60 (depending on configuration)
- RAM: 128-192 GB
- Storage: 2-3 TB (includes data disks)
- vSphere: HA and DRS enabled cluster

---

## Prerequisites

1. **vSphere 7.0+** or **8.0+**
2. **HA and DRS** enabled on cluster
3. **Multiple ESXi hosts** (for anti-affinity)
4. **VM templates** (Ubuntu 22.04, Windows Server 2022)
5. **Sufficient resources** available

---

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

terraform init
terraform plan
terraform apply
```

---

## Post-Deployment

### 1. Configure PostgreSQL HA Cluster

SSH to each PostgreSQL node and set up Patroni:

```bash
# Install Patroni and etcd on all nodes
# Configure Patroni cluster
# Set up VIP or HAProxy for client connections
```

See: `docs/17_DATABASE_MIGRATION_STRATEGY.md`

### 2. Set Up AWX (Ansible Tower)

Install AWX on Ansible controllers for centralized management:

```bash
# Option 1: Docker Compose
docker-compose up -d awx

# Option 2: K3s (Kubernetes)
k3s-awx-installer
```

### 3. Configure Monitoring

Access Grafana and import dashboards for:
- PostgreSQL cluster metrics
- Ansible job statistics
- VM resource utilization
- Migration progress tracking

---

## High Availability Features

### DRS Anti-Affinity Rules

Ensures HA VMs run on different ESXi hosts:
- Ansible controllers separated
- PostgreSQL nodes separated
- Automatic rebalancing via DRS

### PostgreSQL Cluster (Patroni)

- 3-node cluster with automatic failover
- Leader election via etcd consensus
- Synchronous replication for data safety
- Health checks and automatic recovery

### Load Balancing

Use HAProxy or keepalived for:
- PostgreSQL cluster VIP
- Ansible controller load balancing
- Automatic failover to healthy nodes

---

## Backup Strategy

1. **VM Snapshots** - Pre/post migration
2. **vSphere Backup** - Veeam or similar
3. **PostgreSQL Backups** - pg_basebackup + WAL archiving
4. **Configuration Backups** - Ansible playbooks in Git

---

## Scaling

Increase capacity by adjusting variables:

```hcl
num_ansible_controllers = 3
num_postgres_nodes = 5
ansible_vcpu = 16
ansible_memory_mb = 65536
```

---

## Documentation

- [Master Design](../../docs/00_MASTER_DESIGN.md)
- [vSphere Implementation](../../docs/19_VSPHERE_IMPLEMENTATION.md)
- [Operations Runbook](../../docs/05_RUNBOOK_OPERATIONS.md)
- [Database Strategy](../../docs/17_DATABASE_MIGRATION_STRATEGY.md)

---

**Author:** Adrian Johnson  
**Last Updated:** October 2025


