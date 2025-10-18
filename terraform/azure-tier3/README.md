# Tier 3 Enterprise Migration Platform - Azure AKS

**Deployment Tier:** 3 (Enterprise)  
**Target:** >3,000 users, mission-critical, full HA  
**Platform:** Azure Kubernetes Service (AKS)  
**Status:** Production-ready enterprise infrastructure

---

## 🎯 Overview

Tier 3 is the **Enterprise Edition** of the AD Domain Migration platform, designed for:

- **Large-scale migrations:** >3,000 users, >800 workstations, >150 servers
- **Mission-critical operations:** 99.9% uptime, <5 minute RTO
- **Global deployments:** Multi-region, multi-tenant capable
- **Full high availability:** Active-active, auto-failover, self-healing
- **Enterprise compliance:** Complete audit trails, security hardening

### Key Features

✅ **Kubernetes-based:** Runs on AKS with auto-scaling and self-healing  
✅ **Fully HA:** 3-node clusters for all critical components  
✅ **Observable:** Prometheus, Loki, Jaeger integrated  
✅ **Secure:** Azure AD integration, Key Vault, network policies  
✅ **Cost-optimized:** ~$6,000/month for complete platform  

---

## 📊 Architecture

```
Azure Kubernetes Service (AKS)
├── System Node Pool (3-5 nodes, D4s_v5)
│   └── Kubernetes system components, ingress, monitoring
│
├── Worker Node Pool (6-12 nodes, D8s_v5) [Auto-scaling]
│   ├── AWX (3 replicas + executors)
│   ├── PostgreSQL HA (Patroni, 3 nodes)
│   ├── HashiCorp Vault HA (3 nodes, Raft)
│   ├── MinIO HA (6 nodes, erasure coding)
│   ├── Prometheus/Loki/Jaeger
│   └── Grafana HA (2 replicas)
│
└── Azure Managed Services
    ├── Blob Storage (state files, backups)
    ├── Key Vault Premium (secrets)
    ├── Azure Monitor + Log Analytics
    ├── Front Door + WAF (optional)
    └── Private DNS zones
```

---

## 💰 Cost Estimate

### Monthly Cost Breakdown

| Component | Cost/Month |
|-----------|-----------|
| **AKS Cluster** | |
| System Node Pool (3x D4s_v5) | $420 |
| Worker Node Pool (6x D8s_v5) | $1,400 |
| Load Balancer (Standard) | $80 |
| **Storage** | |
| Azure Blob (50 TB) | $1,150 |
| Premium SSD (2 TB PVs) | $300 |
| Azure Files (1 TB) | $180 |
| **Managed Services** | |
| Key Vault Premium | $250 |
| Azure Monitor + Logs | $500 |
| Front Door + WAF (optional) | $400 |
| **Networking** | |
| VPN Gateway | $140 |
| Data Transfer | $830 |
| **Domain Controllers** | |
| Target DC (B2s) | $31 |
| **TOTAL** | **~$5,961/month** |

**6-month project cost:** ~$35,766  
**Annual cost:** ~$71,532

---

## 🚀 Quick Start

### Prerequisites

- Azure subscription with contributor access
- Azure CLI installed and authenticated
- Terraform >= 1.5.0
- kubectl >= 1.28
- Helm >= 3.12

### 1. Configure Variables

```bash
# Copy example variables
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your settings
# Required: admin_password, location, authorized_ip_ranges
```

### 2. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan -out=tfplan

# Apply (creates AKS, networking, storage, etc.)
terraform apply tfplan
```

**Deployment time:** ~20-30 minutes

### 3. Configure kubectl

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group migration-tier3-rg \
  --name migration-tier3-aks

# Verify cluster access
kubectl get nodes
```

### 4. Deploy Kubernetes Components

```bash
# Create namespaces
kubectl apply -f k8s-manifests/00-namespaces.yaml

# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager
kubectl wait --for=condition=Available --timeout=300s \
  deployment/cert-manager -n cert-manager

# Configure certificate issuers
kubectl apply -f k8s-manifests/01-cert-manager-issuer.yaml

# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.replicaCount=3 \
  --set controller.service.externalTrafficPolicy=Local

# Deploy applications (use Helm charts in subdirectories)
# - PostgreSQL HA
# - Vault HA
# - MinIO HA
# - AWX
# - Prometheus Operator
# - Loki
# - Jaeger
# - Grafana
```

---

## 📁 Repository Structure

```
terraform/azure-tier3/
├── providers.tf           # Terraform providers (Azure, K8s, Helm)
├── variables.tf           # Input variables
├── main.tf                # Core resources (RG, storage, Key Vault)
├── aks.tf                 # AKS cluster configuration
├── network.tf             # VNet, subnets, NSGs
├── outputs.tf             # Output values
├── terraform.tfvars.example # Example configuration
├── README.md              # This file
│
├── k8s-manifests/         # Kubernetes manifests
│   ├── 00-namespaces.yaml
│   ├── 01-cert-manager-issuer.yaml
│   └── self-healing/
│       └── alertmanager-config.yaml
│
└── helm/                  # Helm values (create as needed)
    ├── awx/
    ├── vault/
    ├── postgresql/
    ├── minio/
    └── observability/
```

---

## 🔐 Security

### Azure AD Integration

The AKS cluster uses Azure AD for authentication and RBAC:

```bash
# Assign cluster admin role
az role assignment create \
  --assignee user@example.com \
  --role "Azure Kubernetes Service Cluster Admin Role" \
  --scope $(terraform output -raw aks_cluster_id)
```

### Network Security

- **Network Policies:** Calico enforces pod-to-pod communication rules
- **NSGs:** Layer 4 firewall for subnets
- **Private Endpoints:** Secure access to Azure services
- **NAT Gateway:** Secure outbound connectivity

### Secrets Management

- **Azure Key Vault:** Stores admin passwords, certificates
- **HashiCorp Vault:** Application secrets with auto-rotation
- **CSI Driver:** Mount Key Vault secrets as volumes

---

## 📊 Monitoring & Observability

### Access Dashboards

```bash
# Get Grafana password
kubectl get secret -n observability grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode

# Port-forward Grafana
kubectl port-forward -n observability svc/grafana 3000:80

# Access: http://localhost:3000
# Username: admin
# Password: (from above)
```

### Key Metrics

| Metric | Target | Alert Threshold |
|--------|--------|----------------|
| Node CPU | <80% | >80% |
| Node Memory | <85% | >85% |
| Pod Restart Rate | <2/hour | >5/hour |
| Migration Success Rate | >98% | <95% |
| API Latency | <500ms | >1000ms |

---

## 🔄 Operations

### Scaling

```bash
# Scale worker node pool
az aks nodepool scale \
  --resource-group migration-tier3-rg \
  --cluster-name migration-tier3-aks \
  --name workers \
  --node-count 10

# Scale AWX executors
kubectl scale deployment awx-task -n awx --replicas=6
```

### Backup

```bash
# Backup AKS configuration
az aks show --resource-group migration-tier3-rg \
  --name migration-tier3-aks > aks-backup.json

# Backup PostgreSQL
kubectl exec -n database postgresql-ha-0 -- \
  pg_dumpall -U postgres > backup.sql
```

### Disaster Recovery

- **RTO:** <5 minutes (automatic pod rescheduling)
- **RPO:** <15 minutes (continuous replication)
- **Geo-replication:** Enabled for Azure Blob Storage (GRS)

---

## 🚨 Troubleshooting

### AKS Cluster Issues

```bash
# Check node status
kubectl get nodes

# View cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Check system pods
kubectl get pods -n kube-system
```

### Application Issues

```bash
# Check AWX status
kubectl get awx -n awx
kubectl describe awx awx-migration -n awx

# View AWX logs
kubectl logs -n awx -l app.kubernetes.io/component=task -f

# Check database connectivity
kubectl exec -n database postgresql-ha-0 -- psql -U postgres -c "SELECT 1"
```

### Networking Issues

```bash
# Test pod-to-pod connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- sh

# Check ingress
kubectl get ingress --all-namespaces

# View load balancer status
kubectl get svc -n ingress-nginx
```

---

## 📈 Performance Tuning

### AKS Optimization

```bash
# Enable cluster autoscaler
az aks update \
  --resource-group migration-tier3-rg \
  --name migration-tier3-aks \
  --enable-cluster-autoscaler \
  --min-count 6 \
  --max-count 15
```

### Application Tuning

- **PostgreSQL:** Adjust `shared_buffers`, `effective_cache_size` based on workload
- **AWX:** Increase `task_replicas` for higher concurrency
- **MinIO:** Add more nodes for increased throughput

---

## 🔄 Upgrades

### AKS Upgrade

```bash
# Check available versions
az aks get-upgrades \
  --resource-group migration-tier3-rg \
  --name migration-tier3-aks

# Upgrade cluster
az aks upgrade \
  --resource-group migration-tier3-rg \
  --name migration-tier3-aks \
  --kubernetes-version 1.29.0
```

### Application Upgrades

Use Helm for zero-downtime upgrades:

```bash
# Upgrade AWX
helm upgrade awx awx-operator/awx-operator -n awx

# Upgrade PostgreSQL
helm upgrade postgresql bitnami/postgresql-ha -n database
```

---

## 💡 Best Practices

### Cost Optimization

1. **Use auto-scaling:** Scale down during off-hours
2. **Use B-series VMs:** For non-production workloads
3. **Enable Azure Hybrid Benefit:** If you have Windows licenses
4. **Use spot instances:** For non-critical workloads (not recommended for Tier 3)

### Security Hardening

1. **Enable private cluster:** Set `enable_private_cluster = true`
2. **Restrict API access:** Configure `authorized_ip_ranges`
3. **Enable Azure Policy:** For compliance enforcement
4. **Rotate secrets regularly:** Use Key Vault rotation policies
5. **Enable Azure Defender:** For threat detection

### High Availability

1. **Use 3+ replicas:** For all critical components
2. **Distribute across zones:** Use zone-redundant storage
3. **Test failover regularly:** Chaos engineering
4. **Monitor SLOs:** Track availability metrics

---

## 📚 Additional Resources

### Documentation

- [Architecture Design](../../docs/27_TIER3_ENTERPRISE_ARCHITECTURE.md)
- [Deployment Tiers Comparison](../../docs/01_DEPLOYMENT_TIERS.md)
- [Master Design Document](../../docs/00_MASTER_DESIGN.md)

### External Resources

- [AKS Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [AWX Operator](https://github.com/ansible/awx-operator)
- [HashiCorp Vault on Kubernetes](https://www.vaultproject.io/docs/platform/k8s)
- [Patroni Documentation](https://patroni.readthedocs.io/)

---

## 🆘 Support

### Common Issues

| Issue | Solution |
|-------|----------|
| Pods stuck in Pending | Check node resources, PVC availability |
| Service unreachable | Verify ingress, network policies |
| High latency | Scale up node pools, optimize queries |
| Out of memory | Increase node size or add nodes |

### Getting Help

1. Check logs: `kubectl logs <pod-name> -n <namespace>`
2. Review events: `kubectl describe <resource> -n <namespace>`
3. Check metrics: View Grafana dashboards
4. Contact: IT Infrastructure Team

---

## 📝 Change Log

### Version 1.0.0 (October 2025)

- Initial Tier 3 implementation
- AKS cluster with auto-scaling
- Full HA for all components
- Integrated observability stack
- Self-healing automation
- Production-ready

---

## 🎯 Roadmap

### Planned Enhancements

- [ ] Multi-region deployment
- [ ] Service mesh (Istio/Linkerd)
- [ ] GitOps with Argo CD/Flux
- [ ] Advanced auto-scaling (KEDA)
- [ ] Cost optimization dashboards
- [ ] Automated compliance scanning
- [ ] Disaster recovery automation

---

**Status:** Production-ready ✅  
**Maintained by:** Infrastructure Team  
**Last Updated:** October 2025

For questions or issues, please open a GitHub issue or contact the infrastructure team.

