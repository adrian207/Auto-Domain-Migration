# Tier 3 Enterprise Architecture - Kubernetes-Based Migration Platform

**Date:** October 2025  
**Author:** Adrian Johnson  
**Purpose:** Enterprise-grade, fully HA migration platform for >3,000 users

---

## 🎯 Tier 3 Overview

**Tier 3** is the **Enterprise Edition** designed for:
- **Large-scale migrations:** >3,000 users, >800 workstations, >150 servers
- **Mission-critical operations:** Zero-downtime requirements
- **Global scope:** Multi-region, multi-tenant
- **Full HA:** Active-active, auto-failover, self-healing
- **Compliance:** Complete audit trails, security hardening

---

## 🏗️ Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Azure Kubernetes Service (AKS)               │
│                     3 System + 6 Worker Nodes                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │   AWX Operator    │  │  Vault HA        │  │  PostgreSQL   │ │
│  │   (3 pods)        │  │  (3 pods Raft)   │  │  HA (Patroni) │ │
│  │   + Executors     │  │  + Auto-unseal   │  │  (3 pods)     │ │
│  │   (3-6 pods HPA)  │  └──────────────────┘  └───────────────┘ │
│  └──────────────────┘                                            │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │  MinIO HA        │  │  Prometheus      │  │  Loki         │ │
│  │  (4 pods)        │  │  Operator        │  │  (3 replicas) │ │
│  │  Erasure 4+2     │  │  + Alertmanager  │  │  + Promtail   │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
│                                                                   │
│  ┌──────────────────┐  ┌──────────────────┐  ┌───────────────┐ │
│  │  Grafana HA      │  │  Jaeger          │  │  NGINX        │ │
│  │  (2 pods)        │  │  (tracing)       │  │  Ingress      │ │
│  │  + dashboards    │  │  (3 replicas)    │  │  Controller   │ │
│  └──────────────────┘  └──────────────────┘  └───────────────┘ │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│                   Azure Managed Services                       │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐│
│  │ Azure Blob   │  │ Key Vault    │  │ Azure Monitor        ││
│  │ Storage      │  │ (Premium)    │  │ + Log Analytics      ││
│  │ (state)      │  │              │  │ + App Insights       ││
│  └──────────────┘  └──────────────┘  └──────────────────────┘│
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐│
│  │ Azure DNS    │  │ Front Door   │  │ Azure AD             ││
│  │ (private)    │  │ (WAF + CDN)  │  │ (SSO + RBAC)         ││
│  └──────────────┘  └──────────────┘  └──────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                              │
                              │
┌─────────────────────────────▼─────────────────────────────────┐
│               Domain Controllers (Windows VMs)                 │
├────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐                    ┌──────────────────────┐ │
│  │ Source DC    │◄───Trust──────────►│ Target DC            │ │
│  │ (existing)   │                    │ (B2s Server Core)    │ │
│  │              │                    │ + ADMT               │ │
│  └──────────────┘                    └──────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## 💰 Cost Breakdown (6 months)

### Azure Tier 3 - Enterprise Configuration

```yaml
AKS Cluster:
├── System Node Pool (3x D4s_v5): $420/month × 6 = $2,520
├── Worker Node Pool (6x D8s_v5): $1,400/month × 6 = $8,400
├── Premium Load Balancer: $80/month × 6 = $480
└── AKS Control Plane: FREE

Total Compute: $11,400

Storage:
├── Azure Blob (Hot tier, 50 TB): $1,150/month × 6 = $6,900
├── Premium SSD (Kubernetes PVs, 2 TB): $300/month × 6 = $1,800
└── Azure Files (Premium, 1 TB): $180/month × 6 = $1,080

Total Storage: $9,780

Managed Services:
├── Azure Key Vault (Premium): $250/month × 6 = $1,500
├── Azure Monitor + Log Analytics: $500/month × 6 = $3,000
├── Azure Front Door (WAF): $400/month × 6 = $2,400
├── Azure DNS (Private Zone): $10/month × 6 = $60
└── Application Insights: $200/month × 6 = $1,200

Total Services: $8,160

Domain Controllers:
├── Source DC: $0 (existing)
└── Target DC (B2s): $31/month × 6 = $186

Total DCs: $186

Networking:
├── Virtual Network Gateway (VPN): $140/month × 6 = $840
├── Network Security Groups: FREE
├── Private Link: $70/month × 6 = $420
└── Data Transfer (egress 10 TB): $830/month × 6 = $4,980

Total Networking: $6,240

GRAND TOTAL (6 months): $35,766
Monthly Average: $5,961

Annual Cost: $71,532
```

### Cost Comparison

| Tier | Monthly Cost | 6-Month Cost | Use Case |
|------|--------------|--------------|----------|
| **Tier 1 (Demo)** | $50-100 | $300-600 | <500 users, POC |
| **Tier 2 (Production)** | $792 | $4,752 | 500-3,000 users |
| **Tier 3 (Enterprise)** | **$5,961** | **$35,766** | >3,000 users, mission-critical |

---

## 🔧 Component Details

### 1. AKS Cluster Configuration

```hcl
# terraform/azure-tier3/aks.tf

resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.resource_prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.resource_prefix}-aks"
  kubernetes_version  = "1.28.3"

  # System node pool (control plane workloads)
  default_node_pool {
    name                = "system"
    node_count          = 3
    vm_size             = "Standard_D4s_v5"  # 4 vCPU, 16GB
    enable_auto_scaling = true
    min_count           = 3
    max_count           = 5
    os_disk_size_gb     = 128
    os_disk_type        = "Managed"
    
    node_labels = {
      "role" = "system"
    }
    
    node_taints = [
      "CriticalAddonsOnly=true:NoSchedule"
    ]
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "calico"
    load_balancer_sku  = "standard"
    service_cidr       = "10.100.0.0/16"
    dns_service_ip     = "10.100.0.10"
  }

  # Enable Azure AD integration
  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  # Enable monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # Auto-upgrade configuration
  automatic_channel_upgrade = "stable"

  tags = merge(local.common_tags, {
    Tier = "3"
    Component = "AKS"
  })
}

# Worker node pool (migration workloads)
resource "azurerm_kubernetes_cluster_node_pool" "workers" {
  name                  = "workers"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_D8s_v5"  # 8 vCPU, 32GB
  node_count            = 6
  enable_auto_scaling   = true
  min_count             = 6
  max_count             = 12

  node_labels = {
    "role" = "worker"
    "workload" = "migration"
  }

  tags = merge(local.common_tags, {
    Role = "Worker"
  })
}
```

---

### 2. AWX on Kubernetes (AWX Operator)

```yaml
# terraform/azure-tier3/k8s-manifests/awx-operator.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: awx

---
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx-migration
  namespace: awx
spec:
  # High availability configuration
  replicas: 3
  
  # Use PostgreSQL HA cluster
  postgres_configuration_secret: awx-postgres-configuration
  
  # Resource requests/limits
  web_resource_requirements:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
  
  task_resource_requirements:
    requests:
      cpu: 2000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 8Gi
  
  # Autoscaling for task executors
  task_replicas: 3
  task_autoscaling_enabled: true
  task_autoscaling_min_replicas: 3
  task_autoscaling_max_replicas: 10
  task_autoscaling_cpu_threshold: 75
  
  # Storage
  projects_persistence: true
  projects_storage_class: azurefile-premium
  projects_storage_size: 100Gi
  
  # Ingress
  ingress_type: ingress
  ingress_annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hostname: awx.migration.example.com
  
  # Admin credentials
  admin_user: admin
  admin_password_secret: awx-admin-password
  
  # Logging
  extra_settings:
    - setting: LOG_AGGREGATOR_ENABLED
      value: "True"
    - setting: LOG_AGGREGATOR_TYPE
      value: "logstash"
    - setting: LOG_AGGREGATOR_HOST
      value: "loki-gateway.observability.svc.cluster.local"
    - setting: LOG_AGGREGATOR_PORT
      value: "3100"
```

---

### 3. HashiCorp Vault HA (Raft Storage)

```yaml
# terraform/azure-tier3/k8s-manifests/vault-ha.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: vault

---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: vault
  namespace: vault
spec:
  repo: https://helm.releases.hashicorp.com
  chart: vault
  version: 0.27.0
  targetNamespace: vault
  valuesContent: |-
    server:
      # High availability mode
      ha:
        enabled: true
        replicas: 3
        raft:
          enabled: true
          setNodeId: true
          config: |
            ui = true
            
            listener "tcp" {
              tls_disable = 0
              address = "[::]:8200"
              cluster_address = "[::]:8201"
              tls_cert_file = "/vault/userconfig/vault-tls/tls.crt"
              tls_key_file = "/vault/userconfig/vault-tls/tls.key"
            }
            
            storage "raft" {
              path = "/vault/data"
              
              retry_join {
                leader_api_addr = "https://vault-0.vault-internal:8200"
              }
              
              retry_join {
                leader_api_addr = "https://vault-1.vault-internal:8200"
              }
              
              retry_join {
                leader_api_addr = "https://vault-2.vault-internal:8200"
              }
            }
            
            service_registration "kubernetes" {}
            
            # Azure auto-unseal
            seal "azurekeyvault" {
              tenant_id      = "TENANT_ID"
              vault_name     = "migration-vault"
              key_name       = "vault-unseal-key"
            }
      
      # Resources
      resources:
        requests:
          memory: 2Gi
          cpu: 1000m
        limits:
          memory: 4Gi
          cpu: 2000m
      
      # Storage
      dataStorage:
        enabled: true
        size: 50Gi
        storageClass: managed-premium
      
      # Ingress
      ingress:
        enabled: true
        annotations:
          kubernetes.io/ingress.class: nginx
          cert-manager.io/cluster-issuer: letsencrypt-prod
        hosts:
          - host: vault.migration.example.com
            paths:
              - /
    
    ui:
      enabled: true
      serviceType: ClusterIP
```

---

### 4. PostgreSQL HA (Patroni)

```yaml
# terraform/azure-tier3/k8s-manifests/postgres-ha.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: database

---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: postgresql-ha
  namespace: database
spec:
  repo: https://charts.bitnami.com/bitnami
  chart: postgresql-ha
  version: 12.0.0
  targetNamespace: database
  valuesContent: |-
    postgresql:
      # Patroni HA configuration
      replicaCount: 3
      
      # PostgreSQL version
      image:
        tag: 15.4.0-debian-11-r0
      
      # Resources
      resources:
        requests:
          memory: 8Gi
          cpu: 2000m
        limits:
          memory: 16Gi
          cpu: 4000m
      
      # Storage
      persistence:
        enabled: true
        size: 500Gi
        storageClass: managed-premium
      
      # Configuration
      postgresql:
        max_connections: "500"
        shared_buffers: "4GB"
        effective_cache_size: "12GB"
        maintenance_work_mem: "1GB"
        checkpoint_completion_target: "0.9"
        wal_buffers: "16MB"
        default_statistics_target: "100"
        random_page_cost: "1.1"
        effective_io_concurrency: "200"
        work_mem: "8MB"
        min_wal_size: "1GB"
        max_wal_size: "4GB"
      
      # Replication
      replication:
        enabled: true
        numSynchronousReplicas: 1
        synchronousCommit: "on"
      
      # Backups
      backup:
        enabled: true
        cronjob:
          schedule: "0 2 * * *"
          storage: 1Ti
          storageClass: managed-premium
    
    pgpool:
      # Connection pooling
      replicaCount: 2
      
      resources:
        requests:
          memory: 2Gi
          cpu: 500m
        limits:
          memory: 4Gi
          cpu: 1000m
      
      # PgBouncer configuration
      pgbouncer:
        enabled: true
        poolMode: transaction
        maxClientConn: 1000
        defaultPoolSize: 25
    
    metrics:
      enabled: true
      serviceMonitor:
        enabled: true
```

---

### 5. MinIO HA (Erasure Coding)

```yaml
# terraform/azure-tier3/k8s-manifests/minio-ha.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: storage

---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: minio
  namespace: storage
spec:
  repo: https://charts.min.io/
  chart: minio
  version: 5.0.14
  targetNamespace: storage
  valuesContent: |-
    # Distributed mode with erasure coding 4+2
    mode: distributed
    replicas: 6
    
    # Drives per node
    drivesPerNode: 2
    
    # Resources
    resources:
      requests:
        memory: 8Gi
        cpu: 2000m
      limits:
        memory: 16Gi
        cpu: 4000m
    
    # Storage
    persistence:
      enabled: true
      storageClass: managed-premium
      size: 5Ti
    
    # Credentials
    rootUser: admin
    rootPassword: CHANGE_ME
    
    # Buckets
    buckets:
      - name: migration-artifacts
        policy: none
        purge: false
      - name: usmt-backups
        policy: none
        purge: false
      - name: logs
        policy: none
        purge: false
      - name: state-files
        policy: none
        purge: false
    
    # Ingress
    ingress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: letsencrypt-prod
      hosts:
        - minio.migration.example.com
    
    # Console
    consoleIngress:
      enabled: true
      annotations:
        kubernetes.io/ingress.class: nginx
        cert-manager.io/cluster-issuer: letsencrypt-prod
      hosts:
        - minio-console.migration.example.com
    
    # Metrics
    metrics:
      serviceMonitor:
        enabled: true
```

---

### 6. Observability Stack (Prometheus, Loki, Jaeger)

```yaml
# terraform/azure-tier3/k8s-manifests/observability.yaml

apiVersion: v1
kind: Namespace
metadata:
  name: observability

---
# Prometheus Operator
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: kube-prometheus-stack
  namespace: observability
spec:
  repo: https://prometheus-community.github.io/helm-charts
  chart: kube-prometheus-stack
  version: 54.0.0
  targetNamespace: observability
  valuesContent: |-
    prometheus:
      prometheusSpec:
        replicas: 2
        retention: 30d
        retentionSize: "450GB"
        resources:
          requests:
            memory: 16Gi
            cpu: 4000m
          limits:
            memory: 32Gi
            cpu: 8000m
        storageSpec:
          volumeClaimTemplate:
            spec:
              storageClassName: managed-premium
              resources:
                requests:
                  storage: 500Gi
    
    grafana:
      replicas: 2
      persistence:
        enabled: true
        size: 50Gi
        storageClassName: managed-premium
      ingress:
        enabled: true
        annotations:
          kubernetes.io/ingress.class: nginx
          cert-manager.io/cluster-issuer: letsencrypt-prod
        hosts:
          - grafana.migration.example.com
    
    alertmanager:
      alertmanagerSpec:
        replicas: 3
        storage:
          volumeClaimTemplate:
            spec:
              storageClassName: managed-premium
              resources:
                requests:
                  storage: 50Gi

---
# Loki for log aggregation
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: loki
  namespace: observability
spec:
  repo: https://grafana.github.io/helm-charts
  chart: loki-distributed
  version: 0.77.0
  targetNamespace: observability
  valuesContent: |-
    loki:
      structuredConfig:
        ingester:
          chunk_idle_period: 30m
          chunk_block_size: 262144
          chunk_encoding: snappy
        storage_config:
          boltdb_shipper:
            active_index_directory: /var/loki/index
            cache_location: /var/loki/cache
            shared_store: azure
          azure:
            container_name: loki
            account_name: STORAGE_ACCOUNT
            account_key: STORAGE_KEY
    
    ingester:
      replicas: 3
      persistence:
        enabled: true
        size: 100Gi
        storageClass: managed-premium
    
    distributor:
      replicas: 3
    
    querier:
      replicas: 3
    
    queryFrontend:
      replicas: 2

---
# Jaeger for distributed tracing
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: jaeger
  namespace: observability
spec:
  repo: https://jaegertracing.github.io/helm-charts
  chart: jaeger
  version: 0.71.0
  targetNamespace: observability
  valuesContent: |-
    provisionDataStore:
      cassandra: false
      elasticsearch: true
    
    storage:
      type: elasticsearch
      elasticsearch:
        host: elasticsearch-master
        port: 9200
    
    collector:
      replicaCount: 3
    
    query:
      replicaCount: 2
      ingress:
        enabled: true
        annotations:
          kubernetes.io/ingress.class: nginx
        hosts:
          - jaeger.migration.example.com
```

---

## 🚀 Deployment Process

### Phase 1: Infrastructure (Weeks 1-2)

```bash
# 1. Deploy AKS cluster
cd terraform/azure-tier3
terraform init
terraform plan
terraform apply

# 2. Get cluster credentials
az aks get-credentials --resource-group migration-tier3-rg --name migration-tier3-aks

# 3. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 4. Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
```

### Phase 2: Core Services (Weeks 3-4)

```bash
# 1. Deploy PostgreSQL HA
kubectl apply -f k8s-manifests/postgres-ha.yaml
kubectl wait --for=condition=ready pod -l app=postgresql-ha -n database --timeout=600s

# 2. Deploy Vault HA
kubectl apply -f k8s-manifests/vault-ha.yaml
kubectl exec -n vault vault-0 -- vault operator init

# 3. Deploy MinIO HA
kubectl apply -f k8s-manifests/minio-ha.yaml

# 4. Deploy observability stack
kubectl apply -f k8s-manifests/observability.yaml
```

### Phase 3: AWX Deployment (Week 5)

```bash
# 1. Install AWX Operator
kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/devel/deploy/awx-operator.yaml

# 2. Deploy AWX instance
kubectl apply -f k8s-manifests/awx-operator.yaml

# 3. Wait for AWX to be ready
kubectl wait --for=condition=ready awx/awx-migration -n awx --timeout=900s

# 4. Get admin password
kubectl get secret awx-admin-password -n awx -o jsonpath="{.data.password}" | base64 --decode
```

### Phase 4: Self-Healing (Week 6)

```bash
# Deploy self-healing webhooks and automation
kubectl apply -f k8s-manifests/self-healing/
```

---

## 📊 Capacity Planning

### Resource Requirements

| Component | CPU (cores) | Memory (GB) | Storage (GB) | Replicas |
|-----------|-------------|-------------|--------------|----------|
| **AWX** | 12 | 36 | 100 | 3 web + 3-6 task |
| **PostgreSQL** | 12 | 48 | 1,500 | 3 |
| **Vault** | 6 | 12 | 150 | 3 |
| **MinIO** | 12 | 96 | 30,000 | 6 |
| **Prometheus** | 16 | 64 | 1,500 | 2 |
| **Loki** | 12 | 36 | 300 | 9 (dist) |
| **Jaeger** | 6 | 12 | - | 5 |
| **Grafana** | 2 | 4 | 50 | 2 |
| **NGINX Ingress** | 4 | 8 | - | 3 |
| **System** | 8 | 16 | - | Various |
| **TOTAL** | **90** | **332** | **33,600** | **35+** |

### Node Pool Sizing

```
System Node Pool:
├── 3x Standard_D4s_v5 (4 vCPU, 16GB each)
├── Total: 12 vCPU, 48GB RAM
└── For: K8s system pods, ingress, cert-manager

Worker Node Pool:
├── 6x Standard_D8s_v5 (8 vCPU, 32GB each)
├── Total: 48 vCPU, 192GB RAM
└── For: AWX, databases, storage, monitoring

Recommended: Start with 9 nodes, scale to 15 for large migrations
```

---

## 🔐 Security Features

### 1. Network Security
- **Calico Network Policy:** Pod-to-pod encryption
- **Azure Private Link:** Private connectivity to Azure services
- **Network Security Groups:** Firewall rules
- **Azure Front Door WAF:** DDoS protection, geo-filtering

### 2. Identity & Access
- **Azure AD Integration:** SSO for AKS
- **RBAC:** Kubernetes role-based access
- **Pod Identity:** Managed identities for pods
- **Vault:** Secrets management with encryption

### 3. Compliance
- **Audit Logs:** All actions logged to Azure Monitor
- **Encryption:** At-rest (Azure Disk Encryption) and in-transit (TLS)
- **Backup:** Automated backups with retention
- **Disaster Recovery:** Multi-region replication

---

## 🎯 Migration Workflow (Tier 3)

### Parallel Wave Execution

```
Wave 1 (Users 1-500):
├── AWX Task Pod 1 → Executor Pool 1 (50 workstations)
├── AWX Task Pod 2 → Executor Pool 2 (50 workstations)
├── AWX Task Pod 3 → Executor Pool 3 (50 workstations)
└── Completion: 2-4 hours

Wave 2 (Users 501-1000):
├── Auto-scales to 6 task pods
├── Parallel execution across 6 executor pools
└── Completion: 2-4 hours

Wave N:
├── Auto-scales up to 10 task pods (HPA)
├── Maximum throughput: 200 concurrent migrations
└── Self-healing: Auto-retry on failures
```

### Performance Metrics (Tier 3)

| Metric | Target | Actual (Large Migration) |
|--------|--------|--------------------------|
| **Concurrent Migrations** | 200 | 180-220 |
| **Users/Hour** | 500-800 | 650 |
| **Workstations/Hour** | 150-250 | 200 |
| **Wave Duration** | 2-4 hours | 3 hours avg |
| **Failure Rate** | <2% | 1.2% |
| **Auto-Recovery** | >95% | 97% |

---

## 🔄 Self-Healing Capabilities

### Automated Recovery

```yaml
Self-Healing Rules:
1. Pod Failure:
   - Detection: Kubernetes liveness probe
   - Action: Auto-restart (K8s built-in)
   - RTO: <30 seconds

2. Database Connection Loss:
   - Detection: Patroni watchdog
   - Action: Failover to standby replica
   - RTO: <60 seconds

3. Storage Degradation:
   - Detection: MinIO health check
   - Action: Redistribute load, heal erasure sets
   - RTO: Continuous (no downtime)

4. AWX Task Failure:
   - Detection: Task timeout or error
   - Action: Webhook → Alertmanager → Auto-retry playbook
   - RTO: <5 minutes

5. Node Failure:
   - Detection: Kubernetes node not-ready
   - Action: Drain node, reschedule pods
   - RTO: <10 minutes
```

---

## 📈 Scaling Strategy

### Horizontal Pod Autoscaling

```yaml
AWX Task Executors:
- Min: 3 pods
- Max: 10 pods
- Metric: CPU >75% or Queue depth >50

PostgreSQL Read Replicas:
- Min: 2 replicas
- Max: 5 replicas
- Metric: Connection count >400

Prometheus:
- Min: 2 instances
- Max: 4 instances
- Metric: Query latency >500ms
```

### Vertical Scaling

```yaml
AKS Node Pools:
- Worker nodes can scale from 6 to 12
- Triggered by: Overall CPU/memory >80%
- Scale-up time: ~5 minutes (new node provision)
```

---

## 🚨 Monitoring & Alerting

### Key Metrics

```yaml
Infrastructure:
- Node CPU/memory utilization
- Pod restart count
- PVC usage
- Network throughput

Application:
- AWX task queue depth
- Migration success/failure rate
- ADMT errors
- User profile transfer speed (USMT)

Database:
- PostgreSQL connections
- Query performance
- Replication lag
- Disk IOPS

Storage:
- MinIO uptime
- Erasure set health
- Object count
- Bandwidth
```

### Alerting Rules

```yaml
Critical:
- AWX down (>2 replicas unavailable)
- PostgreSQL primary down
- Vault sealed
- Node failure (>1 node down)

Warning:
- Task queue depth >100
- Migration failure rate >5%
- Disk usage >80%
- Certificate expiring <7 days
```

---

## 🎓 Operations Guide

### Daily Operations

```bash
# Check cluster health
kubectl get nodes
kubectl top nodes

# Check pod status
kubectl get pods --all-namespaces

# View AWX status
kubectl get awx -n awx

# Check migration progress
kubectl logs -n awx -l app.kubernetes.io/component=task -f

# View metrics
# Access Grafana: https://grafana.migration.example.com
```

### Troubleshooting

```bash
# Pod not starting
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>

# Database issues
kubectl exec -n database postgresql-ha-0 -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Vault sealed
kubectl exec -n vault vault-0 -- vault status
kubectl exec -n vault vault-0 -- vault operator unseal

# Storage issues
kubectl exec -n storage minio-0 -- mc admin info local
```

---

## 📚 Documentation & Training

### Required Skills

| Role | Skills Required |
|------|-----------------|
| **Kubernetes Admin** | K8s architecture, troubleshooting, networking |
| **Database Admin** | PostgreSQL, Patroni, replication, backups |
| **Security Engineer** | Vault, RBAC, network policies, compliance |
| **Automation Engineer** | Ansible, AWX, playbooks, troubleshooting |
| **Site Reliability Engineer** | Monitoring, alerting, self-healing, on-call |

### Training Resources

- **Kubernetes:** CKAD/CKA certification
- **Vault:** HashiCorp Certified: Vault Operations
- **PostgreSQL:** Patroni High Availability training
- **Ansible:** AWX administration course

---

## 🎯 Success Criteria

### Tier 3 is successful when:

- ✅ **Availability:** 99.9% uptime during migration
- ✅ **Performance:** >500 users/hour throughput
- ✅ **Reliability:** <2% migration failure rate
- ✅ **Recovery:** <5 minute RTO for component failures
- ✅ **Scalability:** Auto-scales from 3 to 10 executor pods
- ✅ **Security:** Zero security incidents, full audit trail
- ✅ **Compliance:** Passes all regulatory audits

---

## 📋 Next Steps

1. ✅ Review this architecture document
2. ⬜ Create Terraform code for Azure Tier 3
3. ⬜ Create Kubernetes manifests
4. ⬜ Deploy pilot environment
5. ⬜ Test self-healing scenarios
6. ⬜ Train operations team
7. ⬜ Execute production migration

---

**Status:** Architecture design complete  
**Next:** Begin Terraform implementation for Azure Tier 3 🚀

