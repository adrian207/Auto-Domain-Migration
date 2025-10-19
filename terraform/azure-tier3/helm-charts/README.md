# Helm Charts for Tier 3 Enterprise Deployment

This directory contains Helm configurations for deploying enterprise-grade applications on Azure Kubernetes Service (AKS).

## 📦 Applications

| Application | Purpose | HA Config | Chart Version |
|-------------|---------|-----------|---------------|
| **AWX** | Ansible automation platform | Active-Active | 2.x (Operator) |
| **Vault** | Secrets management | 3-node Raft | 0.27.x |
| **PostgreSQL** | Database with Patroni | 3-node cluster | 14.x |
| **MinIO** | Object storage | 6-node erasure coding | RELEASE.2024 |
| **Prometheus** | Metrics & monitoring | Operator stack | 58.x (kube-prometheus-stack) |
| **Loki** | Log aggregation | Distributed mode | 5.x |

---

## 🚀 Quick Start

### Prerequisites

```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm
helm version

# Add Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add minio https://charts.min.io/
helm repo update

# Get AKS credentials (run from terraform/azure-tier3)
az aks get-credentials --resource-group <rg-name> --name <aks-name>
```

---

## 📋 Deployment Order

Deploy in this order to handle dependencies:

```bash
# 1. Cert-Manager (for TLS certificates)
kubectl apply -f ../k8s-manifests/00-namespaces.yaml
kubectl apply -f ../k8s-manifests/01-cert-manager-issuer.yaml

# 2. PostgreSQL (database for AWX and others)
helm install postgresql -f postgresql/values.yaml bitnami/postgresql-ha -n data

# 3. MinIO (object storage)
helm install minio -f minio/values.yaml minio/minio -n data

# 4. HashiCorp Vault (secrets management)
helm install vault -f vault/values.yaml hashicorp/vault -n security

# 5. Prometheus & Grafana (monitoring)
helm install kube-prometheus -f prometheus/values.yaml prometheus-community/kube-prometheus-stack -n monitoring

# 6. Loki (logging)
helm install loki -f loki/values.yaml grafana/loki-distributed -n monitoring

# 7. AWX (Ansible automation)
kubectl apply -f awx/awx-operator.yaml
kubectl apply -f awx/awx-instance.yaml -n automation
```

---

## 🔧 Configuration

### Storage Classes

AKS provides these storage classes by default:
- `default` - Azure Disk (Standard HDD)
- `managed-premium` - Azure Disk (Premium SSD)
- `azurefile` - Azure Files (Standard)
- `azurefile-premium` - Azure Files (Premium)

Our charts use `managed-premium` for databases and `default` for less critical data.

### Ingress

All services are exposed through Azure Application Gateway (configured in Terraform).

Hostnames (configure in your DNS):
- `awx.yourdomain.com` → AWX UI
- `vault.yourdomain.com` → Vault UI
- `grafana.yourdomain.com` → Grafana dashboards
- `prometheus.yourdomain.com` → Prometheus UI

---

## 📊 Resource Requirements

Minimum cluster capacity for all applications:

```yaml
CPU: 24 cores
Memory: 96 GB
Storage: 500 GB
Node Count: 6+ (for HA and spreading)
```

Per-application requirements:

| Application | CPU | Memory | Storage |
|-------------|-----|--------|---------|
| PostgreSQL HA | 6 cores | 24 GB | 100 GB |
| MinIO HA | 6 cores | 12 GB | 200 GB |
| Vault HA | 3 cores | 6 GB | 10 GB |
| Prometheus Stack | 6 cores | 32 GB | 100 GB |
| Loki | 4 cores | 16 GB | 100 GB |
| AWX | 4 cores | 8 GB | 20 GB |

---

## 🔐 Security

### Secrets Management

1. **Initial Secrets** are created using Kubernetes secrets
2. **Runtime Secrets** are stored in HashiCorp Vault
3. **Database Credentials** are auto-generated and stored in Vault

### TLS Certificates

All services use TLS with certificates from:
- **Cert-Manager** with Let's Encrypt (production)
- Or **Azure Key Vault** for enterprise CAs

### Network Policies

Each namespace has network policies to restrict traffic:
- Default deny all ingress
- Allow specific service-to-service communication
- Allow ingress from Application Gateway only

---

## 📈 Monitoring

### Metrics

Prometheus collects metrics from:
- AKS cluster (nodes, pods, containers)
- PostgreSQL (connections, queries, replication lag)
- MinIO (storage, bandwidth, errors)
- Vault (auth attempts, seal status)
- AWX (job runs, success/failure rates)

### Logs

Loki aggregates logs from:
- All pods (via promtail)
- AKS diagnostic logs
- Application logs (structured JSON)

### Alerts

Pre-configured alerts for:
- Pod crashes or restarts
- High CPU/memory usage
- Database replication lag
- Storage capacity warnings
- Certificate expiration

---

## 🔄 Upgrades

### Safe Upgrade Process

```bash
# 1. Backup current state
kubectl get all -A > backup-$(date +%Y%m%d).yaml

# 2. Check current versions
helm list -A

# 3. Dry-run upgrade
helm upgrade --dry-run postgresql -f postgresql/values.yaml bitnami/postgresql-ha -n data

# 4. Perform upgrade
helm upgrade postgresql -f postgresql/values.yaml bitnami/postgresql-ha -n data

# 5. Verify health
kubectl get pods -n data
kubectl logs -n data -l app=postgresql
```

### Rollback

```bash
# View release history
helm history postgresql -n data

# Rollback to previous version
helm rollback postgresql -n data

# Or rollback to specific revision
helm rollback postgresql 3 -n data
```

---

## 🧪 Testing

### Health Checks

```bash
# PostgreSQL
kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- psql -U postgres -c "SELECT version();"

# MinIO
kubectl exec -n data minio-0 -- mc alias set local http://localhost:9000 admin <password>
kubectl exec -n data minio-0 -- mc admin info local

# Vault
kubectl exec -n security vault-0 -- vault status

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090

# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80
# Visit http://localhost:3000
```

### Load Testing

```bash
# PostgreSQL load test
kubectl run pgbench -n data --rm -it --image=postgres:15 -- \
  pgbench -h postgresql-postgresql-ha-pgpool -U postgres -c 10 -t 100

# MinIO benchmark
kubectl exec -n data minio-0 -- \
  mc admin speedtest local --size 1MB --duration 60s
```

---

## 📚 Documentation Links

- [AWX Operator Documentation](https://ansible.readthedocs.io/projects/awx-operator/)
- [Vault on Kubernetes](https://developer.hashicorp.com/vault/docs/platform/k8s)
- [Bitnami PostgreSQL HA Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql-ha)
- [MinIO Operator](https://min.io/docs/minio/kubernetes/upstream/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)

---

## 🆘 Troubleshooting

### Common Issues

**Pods stuck in Pending**
```bash
# Check events
kubectl describe pod <pod-name> -n <namespace>

# Common causes:
# - Insufficient cluster capacity
# - Storage class not available
# - Network policies blocking
```

**Storage issues**
```bash
# Check PVCs
kubectl get pvc -A

# Check storage classes
kubectl get storageclass

# Resize PVC (if storage class supports it)
kubectl patch pvc <pvc-name> -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'
```

**Service not accessible**
```bash
# Check service
kubectl get svc -n <namespace>

# Check endpoints
kubectl get endpoints -n <namespace>

# Check Application Gateway
az network application-gateway show --resource-group <rg> --name <agw-name>
```

---

## 💾 Backup & Restore

### PostgreSQL Backup

```bash
# Automated backups via pgBackRest (configured in values.yaml)
kubectl exec -n data postgresql-postgresql-ha-postgresql-0 -- \
  pgbackrest backup --stanza=main --type=full

# List backups
kubectl exec -n data postgresql-postgresql-ha-postgresql-0 -- \
  pgbackrest info
```

### MinIO Backup

```bash
# Mirror to secondary site or Azure Blob
kubectl exec -n data minio-0 -- \
  mc mirror local/bucket azureblob/backup-bucket
```

### Vault Backup

```bash
# Automated snapshots (Raft)
kubectl exec -n security vault-0 -- \
  vault operator raft snapshot save /tmp/vault-snapshot.snap

# Copy snapshot
kubectl cp security/vault-0:/tmp/vault-snapshot.snap ./vault-snapshot-$(date +%Y%m%d).snap
```

---

**Ready to deploy?** Start with the deployment order above! 🚀

