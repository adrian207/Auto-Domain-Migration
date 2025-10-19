# Tier 3 Helm Deployment Guide

**Complete step-by-step guide for deploying all applications**

---

## 🎯 Prerequisites Checklist

Before starting, ensure you have:

- [ ] AKS cluster deployed (via Terraform)
- [ ] `kubectl` configured with cluster access
- [ ] Helm 3.12+ installed
- [ ] Azure CLI installed and logged in
- [ ] Domain names configured (or using test domains)
- [ ] TLS certificates ready (or Cert-Manager configured)
- [ ] Vault unseal key in Azure Key Vault
- [ ] Azure Storage Account for Loki (create `loki-chunks` container)

---

## 📋 Step-by-Step Deployment

### Step 1: Add Helm Repositories

```bash
# Add all required Helm repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add minio https://charts.min.io/

# Update repositories
helm repo update
```

**Expected output:** `Successfully got an update from the ... chart repository`

---

### Step 2: Create Namespaces

```bash
# Create namespaces for all applications
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: data
  labels:
    name: data
---
apiVersion: v1
kind: Namespace
metadata:
  name: security
  labels:
    name: security
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
---
apiVersion: v1
kind: Namespace
metadata:
  name: automation
  labels:
    name: automation
EOF
```

**Verify:**
```bash
kubectl get namespaces
```

---

### Step 3: Deploy PostgreSQL HA (15-20 minutes)

PostgreSQL is required by AWX, so deploy it first.

```bash
cd terraform/azure-tier3/helm-charts

# Install PostgreSQL HA
helm install postgresql bitnami/postgresql-ha \
  -f postgresql/values.yaml \
  -n data \
  --wait \
  --timeout 20m

# Verify deployment
kubectl get pods -n data
kubectl get pvc -n data
kubectl get svc -n data
```

**Expected pods:**
- `postgresql-postgresql-ha-postgresql-0` (Ready 1/1)
- `postgresql-postgresql-ha-postgresql-1` (Ready 1/1)
- `postgresql-postgresql-ha-postgresql-2` (Ready 1/1)
- `postgresql-postgresql-ha-pgpool-XXX` (2 replicas)

**Test connection:**
```bash
kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "SELECT version();"
```

**Create AWX database:**
```bash
kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "CREATE DATABASE awx;"

kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "CREATE USER awx WITH PASSWORD 'ChangeThisPassword123!';"

kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE awx TO awx;"
```

---

### Step 4: Deploy MinIO HA (10-15 minutes)

Object storage for backups and artifacts.

```bash
# Update minio/values.yaml with your settings first!
# Then install:

helm install minio minio/minio \
  -f minio/values.yaml \
  -n data \
  --wait \
  --timeout 15m

# Verify deployment
kubectl get pods -n data -l app=minio
kubectl get pvc -n data -l app=minio
kubectl get svc -n data -l app=minio
```

**Expected pods:** 6 MinIO pods (minio-0 through minio-5)

**Test MinIO:**
```bash
# Port-forward to access console
kubectl port-forward -n data svc/minio-console 9001:9001

# Visit http://localhost:9001
# Login: admin / ChangeThisPassword123!
```

**Verify erasure coding:**
```bash
kubectl exec -n data minio-0 -- mc admin info local
```

You should see: `6 drives online, 0 drives offline` with `EC:4` (erasure coding 4+2).

---

### Step 5: Deploy HashiCorp Vault (10 minutes)

Secrets management for all services.

```bash
# Update vault/values.yaml with Azure Key Vault details first!

helm install vault hashicorp/vault \
  -f vault/values.yaml \
  -n security \
  --wait \
  --timeout 10m

# Verify deployment
kubectl get pods -n security
kubectl get pvc -n security
```

**Expected pods:** 3 Vault pods (vault-0, vault-1, vault-2)

**Initialize and unseal Vault:**

```bash
# Check status (will show "Not initialized")
kubectl exec -n security vault-0 -- vault status

# Initialize Vault (SAVE THE OUTPUT!)
kubectl exec -n security vault-0 -- vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-init.json

# With Azure Key Vault auto-unseal, Vault should auto-unseal
# Verify:
kubectl exec -n security vault-0 -- vault status
```

**Expected output:** `Sealed: false`, `High Availability Enabled: true`

**Join other nodes:**
```bash
# Nodes should auto-join via Raft, but if needed:
kubectl exec -n security vault-1 -- vault operator raft join https://vault-0.vault-internal:8200
kubectl exec -n security vault-2 -- vault operator raft join https://vault-0.vault-internal:8200
```

**Enable audit logging:**
```bash
# Get root token from vault-init.json
export VAULT_TOKEN="s.XXXXXXXXX"

kubectl exec -n security vault-0 -- vault login $VAULT_TOKEN
kubectl exec -n security vault-0 -- vault audit enable file file_path=/vault/audit/audit.log
```

---

### Step 6: Deploy Prometheus + Grafana (15-20 minutes)

Monitoring and observability stack.

```bash
# Update prometheus/values.yaml with your settings first!

helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -f prometheus/values.yaml \
  -n monitoring \
  --wait \
  --timeout 20m

# Verify deployment
kubectl get pods -n monitoring
kubectl get pvc -n monitoring
kubectl get svc -n monitoring
```

**Expected pods:**
- 2x Prometheus pods
- 3x Alertmanager pods
- 2x Grafana pods
- Node exporter daemonset
- Kube-state-metrics
- Prometheus operator

**Access Grafana:**
```bash
# Port-forward
kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80

# Visit http://localhost:3000
# Login: admin / ChangeThisPassword123!
```

**Access Prometheus:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090
```

---

### Step 7: Deploy Loki (15-20 minutes)

Distributed logging system.

```bash
# IMPORTANT: Create Azure Storage Account and container first!
az storage account create \
  --name <your-storage-account> \
  --resource-group <your-rg> \
  --location eastus \
  --sku Standard_LRS

az storage container create \
  --name loki-chunks \
  --account-name <your-storage-account>

# Update loki/values.yaml with Azure Storage details!

helm install loki grafana/loki-distributed \
  -f loki/values.yaml \
  -n monitoring \
  --wait \
  --timeout 20m

# Verify deployment
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki
kubectl get pvc -n monitoring -l app.kubernetes.io/name=loki
```

**Expected pods:**
- 3x Distributor
- 3x Ingester
- 3x Querier
- 2x Query Frontend
- 2x Gateway
- 1x Compactor
- Promtail daemonset

**Test Loki:**
```bash
# Port-forward gateway
kubectl port-forward -n monitoring svc/loki-gateway 3100:80

# Query logs
curl http://localhost:3100/loki/api/v1/labels
```

**Add Loki to Grafana:**
- Already configured in Grafana datasources!
- Navigate to Grafana → Explore → Select "Loki" datasource
- Query: `{namespace="monitoring"}`

---

### Step 8: Deploy AWX (20-30 minutes)

Ansible automation platform.

```bash
# Step 8.1: Deploy AWX Operator
kubectl apply -f awx/awx-operator.yaml

# Wait for operator to be ready
kubectl wait --for=condition=available --timeout=300s \
  deployment/awx-operator -n automation

# Verify operator
kubectl get pods -n automation

# Step 8.2: Update AWX instance configuration
# Edit awx/awx-instance.yaml:
# - Update hostname
# - Update PostgreSQL credentials (match Step 3)
# - Update admin password

# Step 8.3: Deploy AWX instance
kubectl apply -f awx/awx-instance.yaml

# Wait for AWX to be ready (this takes 10-15 minutes)
kubectl get awx -n automation -w

# Watch progress
kubectl logs -n automation -f deployment/awx-operator
```

**Expected pods:**
- 2x AWX web pods
- 2x AWX task pods
- 1x AWX Redis pod

**Access AWX:**
```bash
# Port-forward
kubectl port-forward -n automation svc/awx-service 8052:80

# Visit http://localhost:8052
# Login: admin / <password from awx-admin-password secret>
```

**Get admin password:**
```bash
kubectl get secret awx-admin-password -n automation -o jsonpath='{.data.password}' | base64 --decode
```

---

## ✅ Post-Deployment Verification

### Health Checks

Run all health checks:

```bash
#!/bin/bash
# health-check.sh

echo "=== PostgreSQL ==="
kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "SELECT version();" && echo "✅ PostgreSQL OK" || echo "❌ PostgreSQL FAILED"

echo "=== MinIO ==="
kubectl exec -n data minio-0 -- mc admin info local && echo "✅ MinIO OK" || echo "❌ MinIO FAILED"

echo "=== Vault ==="
kubectl exec -n security vault-0 -- vault status && echo "✅ Vault OK" || echo "❌ Vault FAILED"

echo "=== Prometheus ==="
kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090 &
PF_PID=$!
sleep 2
curl -s http://localhost:9090/-/healthy && echo "✅ Prometheus OK" || echo "❌ Prometheus FAILED"
kill $PF_PID

echo "=== Loki ==="
kubectl exec -n monitoring loki-gateway-0 -- wget -q -O- http://localhost:3100/ready && echo "✅ Loki OK" || echo "❌ Loki FAILED"

echo "=== AWX ==="
kubectl get awx -n automation && echo "✅ AWX OK" || echo "❌ AWX FAILED"
```

---

## 🔧 Configuration

### Configure AWX

1. **Add Execution Environments:**
   - Navigate to Administration → Execution Environments
   - Add: `quay.io/ansible/awx-ee:latest`
   - Add custom ADMT EE (if built)

2. **Add Credentials:**
   - Navigate to Resources → Credentials
   - Add Domain Admin credentials for source/target
   - Add Azure credentials for infrastructure

3. **Add Projects:**
   - Navigate to Resources → Projects
   - Add Git repository with Ansible playbooks
   - Sync project

4. **Add Inventories:**
   - Navigate to Resources → Inventories
   - Import from migration inventory files

5. **Create Job Templates:**
   - ADMT Discovery
   - ADMT Prerequisites
   - ADMT Migration
   - ADMT Validation
   - ADMT Rollback

---

### Configure Grafana Dashboards

1. **Import pre-built dashboards:**
   - Kubernetes Cluster (ID: 7249)
   - Node Exporter (ID: 1860)
   - PostgreSQL (ID: 9628)

2. **Create custom ADMT dashboards:**
   - Migration progress
   - Error rates
   - File transfer metrics

---

### Configure Vault Secrets

```bash
# Enable KV v2 secrets engine
kubectl exec -n security vault-0 -- vault secrets enable -path=secret kv-v2

# Store ADMT credentials
kubectl exec -n security vault-0 -- vault kv put secret/admt/source \
  username=admin \
  password=SourcePassword123

kubectl exec -n security vault-0 -- vault kv put secret/admt/target \
  username=admin \
  password=TargetPassword123

# Create policy for AWX
kubectl exec -n security vault-0 -- vault policy write awx - <<EOF
path "secret/data/admt/*" {
  capabilities = ["read", "list"]
}
EOF

# Enable Kubernetes auth
kubectl exec -n security vault-0 -- vault auth enable kubernetes

kubectl exec -n security vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create role for AWX
kubectl exec -n security vault-0 -- vault write auth/kubernetes/role/awx \
  bound_service_account_names=awx \
  bound_service_account_namespaces=automation \
  policies=awx \
  ttl=24h
```

---

## 📊 Monitoring

### View Metrics

**Prometheus queries:**
```promql
# Migration job success rate
rate(awx_job_successful_total[5m])

# Database connections
pg_stat_database_numbackends{datname="awx"}

# MinIO throughput
rate(minio_s3_requests_total[5m])

# Vault auth attempts
rate(vault_core_handle_request_count[5m])
```

### View Logs

**Loki queries:**
```logql
# AWX logs
{namespace="automation", app="awx"}

# Error logs across all namespaces
{} |= "error" | json | level="error"

# Migration-specific logs
{namespace="automation"} |= "migration"
```

---

## 🚨 Troubleshooting

### Common Issues

**Pods in Pending state:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Check events for: Insufficient CPU/Memory, PVC not bound, etc.
```

**PVC not binding:**
```bash
kubectl get pvc -A
kubectl describe pvc <pvc-name> -n <namespace>
# Check storage class exists and has provisioner
```

**Service not accessible:**
```bash
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
# Verify pods are running and have correct labels
```

**AWX operator stuck:**
```bash
kubectl logs -n automation deployment/awx-operator
# Check for API errors, permission issues
```

---

## 🔄 Upgrade Procedures

### Upgrade PostgreSQL

```bash
# Check current version
helm list -n data

# Backup database first!
kubectl exec -n data postgresql-postgresql-ha-postgresql-0 -- \
  pg_dumpall -U postgres > backup.sql

# Dry-run upgrade
helm upgrade --dry-run postgresql bitnami/postgresql-ha \
  -f postgresql/values.yaml \
  -n data

# Perform upgrade
helm upgrade postgresql bitnami/postgresql-ha \
  -f postgresql/values.yaml \
  -n data

# Verify
kubectl get pods -n data
```

---

## 💾 Backup & Restore

### Automated Backups

All backups are configured in the Helm values files:
- **PostgreSQL:** Daily backups via pgBackRest
- **MinIO:** Continuous replication to Azure Blob
- **Vault:** Automated Raft snapshots
- **Loki:** Data in Azure Storage (durable)

### Manual Backup

```bash
# PostgreSQL
kubectl exec -n data postgresql-postgresql-ha-postgresql-0 -- \
  pg_dumpall -U postgres | gzip > postgres-backup-$(date +%Y%m%d).sql.gz

# Vault snapshot
kubectl exec -n security vault-0 -- \
  vault operator raft snapshot save /tmp/vault-snapshot.snap

kubectl cp security/vault-0:/tmp/vault-snapshot.snap \
  ./vault-snapshot-$(date +%Y%m%d).snap
```

---

## 📚 Additional Resources

- [AWX Documentation](https://ansible.readthedocs.io/projects/awx/)
- [Vault on Kubernetes](https://developer.hashicorp.com/vault/tutorials/kubernetes)
- [Prometheus Operator Guide](https://prometheus-operator.dev/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)

---

**Deployment complete!** 🎉

Your Tier 3 enterprise platform is now operational with:
- ✅ High-availability databases
- ✅ Distributed object storage
- ✅ Secrets management
- ✅ Complete observability
- ✅ Ansible automation platform

**Next:** Configure your migration workflows in AWX!

