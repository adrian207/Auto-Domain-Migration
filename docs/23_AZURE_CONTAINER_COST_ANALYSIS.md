# Azure Container Services Cost Analysis

**Date:** October 2025  
**Author:** Adrian Johnson  
**Purpose:** Cost comparison - VMs vs Container Services

---

## 🎯 Executive Summary

**Current Azure Tier 2 (VMs):** ~$1,270/month compute + $730/month services = **$2,000/month**

**Proposed Azure Tier 2 (Containers):** ~$140/month compute + $730/month services = **$870/month**

**Savings: ~$1,130/month (56% reduction)** ✅

---

## 💰 Current Cost Breakdown (VM-Based)

### Compute Costs (East US, Pay-as-you-go)

| Component | VM Size | Specs | Monthly Cost | Count | Total |
|-----------|---------|-------|--------------|-------|-------|
| **Guacamole Bastion** | Standard_D2s_v5 | 2 vCPU, 8GB RAM | $70 | 1 | $70 |
| **Ansible Controllers** | Standard_D8s_v5 | 8 vCPU, 32GB RAM | $280 | 2 | $560 |
| **Monitoring** | Standard_D4s_v5 | 4 vCPU, 16GB RAM | $140 | 1 | $140 |
| **Source DC** | Standard_D4s_v5 | 4 vCPU, 16GB RAM | $140 | 1 | $140 |
| **Target DC** | Standard_D4s_v5 | 4 vCPU, 16GB RAM | $140 | 1 | $140 |
| **Test Workstation** | Standard_D4s_v5 | 4 vCPU, 16GB RAM | $140 | 1 | $140 |
| **Subtotal Compute** | | | | | **$1,270** |

### Platform Services

| Service | SKU | Monthly Cost |
|---------|-----|--------------|
| **PostgreSQL Flexible Server** | GP_Standard_D4s_v3 (HA) | $220 |
| **Azure Storage** | Standard GRS | $30 |
| **Key Vault** | Standard | $0 (free tier) |
| **Log Analytics** | Pay-as-you-go | $50 |
| **Azure Monitor** | Alerts + metrics | $30 |
| **Backup** | VM backups | $100 |
| **Networking** | VNet, NSG, Load Balancer | $100 |
| **Bandwidth** | Data transfer | $200 |
| **Subtotal Services** | | **$730** |

### **TOTAL CURRENT: ~$2,000/month**

---

## 🚀 Proposed Architecture (Container-Based)

### Key Changes

```
What CAN'T Be Containerized:
├── Domain Controllers (Windows) → MUST stay as VMs
└── Test Workstations (Windows) → MUST stay as VMs

What CAN Be Containerized:
├── Guacamole → Azure Container Apps
├── Ansible Controllers → Azure Container Apps
├── Monitoring (Prometheus/Grafana) → Azure Container Apps
└── PostgreSQL → Already managed service (no change)
```

---

## 💡 Container Service Options

### Option 1: Azure Container Instances (ACI)
**Best for:** Simple, stateless containers

**Pricing:**
- Linux: $0.0000125/vCPU-second + $0.0000014/GB-second
- Windows: 3x Linux prices

**Example (Linux, 2 vCPU, 4GB, 24/7):**
- vCPU: 2 × $0.0000125 × 2,592,000 sec/month = $64.80
- Memory: 4 × $0.0000014 × 2,592,000 sec/month = $14.51
- **Total: ~$79/month per container**

**Pros:**
- ✅ Pay per second
- ✅ No cluster management
- ✅ Fast startup (<60 sec)

**Cons:**
- ❌ No built-in load balancing
- ❌ No auto-scaling
- ❌ Manual networking setup

---

### Option 2: Azure Container Apps (ACA) ⭐ RECOMMENDED
**Best for:** Web apps, APIs, microservices with scaling

**Pricing:**
- Consumption tier: Pay per vCPU-second + GB-second + requests
- Dedicated tier: Pay for compute pool (cheaper for 24/7)

**Consumption Pricing:**
- vCPU: $0.000012/vCPU-second
- Memory: $0.0000013/GB-second
- Requests: FREE (first 2M/month)

**Example (2 vCPU, 4GB, 24/7 on Consumption):**
- vCPU: 2 × $0.000012 × 2,592,000 = $62.21
- Memory: 4 × $0.0000013 × 2,592,000 = $13.48
- Requests: $0 (under 2M)
- **Total: ~$76/month per app**

**Dedicated Tier Pricing (for 24/7 workloads):**
- Workload profile: 4 vCPU, 8GB = $122/month
- Can run multiple apps on same pool

**Pros:**
- ✅ Built-in ingress/load balancer
- ✅ Auto-scaling (0-30 replicas)
- ✅ Managed certificates
- ✅ Integrated with vNets
- ✅ Dapr integration
- ✅ Scale to zero for cost savings

**Cons:**
- ❌ Newer service (less mature than AKS)
- ❌ Some limitations vs full Kubernetes

---

### Option 3: Azure Kubernetes Service (AKS) - Tier 3
**Best for:** Complex orchestration, Tier 3 deployments

**Pricing:**
- Control plane: FREE (Standard tier) or $73/month (Premium)
- Nodes: Pay for VMs in node pool
- System node pool: 2-3 VMs minimum

**Example (Minimal AKS cluster):**
- 3x Standard_D2s_v5 nodes = 3 × $70 = $210/month
- Control plane: FREE (Standard tier)
- **Total: ~$210/month + workloads**

**Pros:**
- ✅ Full Kubernetes features
- ✅ Mature, production-ready
- ✅ Massive ecosystem
- ✅ Multi-tenancy support

**Cons:**
- ❌ Higher complexity
- ❌ Requires Kubernetes expertise
- ❌ Minimum 2-3 nodes

---

## 🎨 Proposed Tier 2 Architecture (Container Apps)

### New Infrastructure

```
Azure Container Apps Environment
├── Consumption Workload Profile (small workloads)
│   ├── Guacamole (2 vCPU, 4GB) → $76/month
│   ├── Ansible Controller (4 vCPU, 8GB) → $152/month (auto-scales)
│   ├── Prometheus (2 vCPU, 4GB) → $76/month
│   └── Grafana (2 vCPU, 4GB) → $76/month
│
├── Virtual Machines (can't containerize)
│   ├── Source DC (Standard_D2s_v5) → $70/month
│   └── Target DC (Standard_D2s_v5) → $70/month
│
├── Managed Services
│   ├── PostgreSQL Flexible Server → $220/month
│   ├── Azure Storage → $30/month
│   ├── Key Vault → FREE
│   └── Networking → $50/month (reduced)
│
└── Total: ~$870/month
```

**Cost Breakdown:**
- Container Apps: $380/month (vs $770 for VMs)
- Domain Controller VMs: $140/month (can't avoid)
- Platform Services: $350/month
- **Total: $870/month (56% savings)**

---

## 📊 Cost Comparison Matrix

| Component | Current (VMs) | Proposed (Containers) | Savings |
|-----------|---------------|----------------------|---------|
| **Guacamole** | $70/mo (VM) | $76/mo (Container App) | -$6 |
| **Ansible** | $560/mo (2 VMs) | $152/mo (1 Container App, scales) | +$408 |
| **Monitoring** | $140/mo (VM) | $152/mo (2 Container Apps) | -$12 |
| **Domain Controllers** | $280/mo (2 VMs) | $140/mo (2 VMs, downsized) | +$140 |
| **Platform Services** | $730/mo | $350/mo (reduced networking) | +$380 |
| **TOTAL** | **$2,000/mo** | **$870/mo** | **+$1,130/mo (56%)** |

---

## 🏗️ Recommended Architecture by Tier

### Tier 1 (Free/Demo): $0-50/month
```
Azure Free Tier
├── 1x B1s VM (Ansible + Guacamole combined) - FREE 750 hrs/month
├── 1x B1s VM (Source DC) - FREE 750 hrs/month
├── 1x B1s VM (Target DC) - FREE 750 hrs/month
├── PostgreSQL (Burstable B1ms) - $12/month
├── Storage (5GB free + overages) - $5/month
└── Total: ~$17/month (or FREE if under limits)
```

### Tier 2 (Production): $870/month ⭐
```
Azure Container Apps + Minimal VMs
├── Container Apps Environment
│   ├── All migration tools as containers
│   └── Auto-scaling, high availability
├── 2x Domain Controller VMs (minimal size)
├── PostgreSQL Flexible Server (managed)
└── Total: ~$870/month (vs $2,000 with all VMs)
```

### Tier 3 (Enterprise): $1,500-2,500/month
```
Azure Kubernetes Service + Premium Features
├── AKS Cluster (3-5 nodes)
│   ├── All migration tools in Kubernetes
│   ├── Full HA and auto-scaling
│   └── Multi-region support
├── Premium PostgreSQL with HA
├── Azure Front Door for global access
└── Total: ~$1,500-2,500/month (vs $4,000+ all VMs)
```

---

## ⚠️ Important Considerations

### 1. Domain Controllers Cannot Be Containerized
**Why:**
- Active Directory requires persistent state
- FSMO roles need stable servers
- Sysvol replication needs stable endpoints
- Group Policy requires server OS

**Solution:**
- Keep DCs as VMs (smallest size possible)
- Downsize from D4s_v5 (4 vCPU) to D2s_v5 (2 vCPU) → saves $140/month
- Use B-series burstable VMs for dev/test → saves even more

---

### 2. Windows Containers Limitations
**Azure Container Instances/Apps:**
- Windows containers are 3x more expensive
- Larger image sizes
- Slower startup times

**Recommendation:**
- Use Linux containers wherever possible
- Run Windows-specific tools (ADMT, USMT) via:
  - PowerShell remoting from Linux containers
  - Windows Server Core VMs (minimal)
  - Pre-built Windows containers (only when needed)

---

### 3. Migration Tool Container Strategy

#### Ansible Controller (Container App)
```yaml
Container: ansible-controller:latest
Base: Rocky Linux 9 (Linux container)
Capabilities:
  - Execute Ansible playbooks
  - PowerShell remoting to Windows DCs
  - WinRM connectivity
  - PostgreSQL access
Scaling: 1-3 replicas
Cost: ~$150/month (vs $560 for 2 VMs)
```

#### Guacamole (Container App)
```yaml
Container: guacamole/guacamole:latest
Base: Debian (Linux container)
Capabilities:
  - Web-based RDP/SSH gateway
  - PostgreSQL backend
  - HTTPS ingress
Scaling: 1-2 replicas
Cost: ~$76/month (vs $70 VM, but better HA)
```

#### Monitoring (Container Apps)
```yaml
Containers:
  - prometheus:latest
  - grafana:latest
Scaling: 1 replica each (stateful)
Cost: ~$152/month (vs $140 VM)
```

---

## 🎯 Migration Path

### Phase 1: Move Monitoring to Containers (Low Risk)
**Timeline:** 1 week
**Savings:** ~$0 (similar cost, better features)
**Risk:** Low - monitoring can fail without breaking migration

### Phase 2: Move Guacamole to Container Apps (Medium Risk)
**Timeline:** 1 week
**Savings:** ~$0 (similar cost, better HA)
**Risk:** Medium - affects user access

### Phase 3: Move Ansible to Container Apps (High Value)
**Timeline:** 2 weeks
**Savings:** ~$400/month
**Risk:** Medium - requires testing all playbooks

### Phase 4: Downsize Domain Controllers (Quick Win)
**Timeline:** 1 day (VM resize)
**Savings:** ~$140/month
**Risk:** Low - DCs don't need 4 vCPUs

### **Total Migration Time:** 4-5 weeks
### **Total Savings:** ~$1,130/month (56%)

---

## 💡 Additional Optimizations

### 1. Auto-Scaling with Container Apps
```yaml
Scale rules:
  - HTTP requests > 100/sec: scale up
  - CPU > 70%: scale up
  - After hours (6pm-6am): scale to zero
  - Weekends: scale to zero

Savings: Additional 30-40% on container costs
```

### 2. Reserved Capacity (1-year commit)
```yaml
Container Apps Dedicated:
  - 1-year reserved: 20% discount
  - 3-year reserved: 38% discount

VM Reserved Instances:
  - 1-year: 40% discount
  - 3-year: 60% discount
```

### 3. Azure Hybrid Benefit
```yaml
For Domain Controller VMs:
  - Use existing Windows Server licenses
  - Savings: 40-50% on Windows VMs
  - DC costs drop to: ~$40/month each
```

---

## 📋 Decision Matrix

| Criteria | All VMs | Container Apps | AKS (Tier 3) |
|----------|---------|----------------|--------------|
| **Cost (Tier 2)** | $2,000/mo | $870/mo ⭐ | $1,500/mo |
| **Complexity** | Low | Medium | High |
| **Maintenance** | High | Low ⭐ | Medium |
| **Scaling** | Manual | Automatic ⭐ | Automatic |
| **HA** | Manual failover | Built-in ⭐ | Built-in |
| **Startup Time** | 3-5 min | 30-60 sec ⭐ | 30-60 sec |
| **Required Expertise** | VMs, Networking | Containers | Kubernetes |
| **Best For** | Simple, stable | Tier 2 Production ⭐ | Tier 3 Enterprise |

---

## 🚀 Final Recommendation

### For Tier 2 (Production): Azure Container Apps ⭐

**Why:**
1. ✅ **56% cost savings** ($2,000 → $870/month)
2. ✅ **Better scalability** (auto-scale 0-30 replicas)
3. ✅ **Faster deployments** (seconds vs minutes)
4. ✅ **Built-in HA** (multi-zone by default)
5. ✅ **Lower maintenance** (managed platform)
6. ✅ **Pay-per-use** (scale to zero when idle)

**What Changes:**
- Ansible, Guacamole, Monitoring → Container Apps
- Domain Controllers → Remain as VMs (downsized)
- PostgreSQL → Managed service (no change)

**Implementation:**
- 4-5 weeks to migrate
- Low-medium risk
- Full rollback capability

---

## 📞 Next Steps

1. **Review architecture** with stakeholders
2. **Proof of concept** - Deploy one component to Container Apps
3. **Test migration playbooks** in container environment
4. **Create Terraform** for Container Apps deployment
5. **Execute phased migration** (monitoring → guacamole → ansible)
6. **Monitor and optimize** costs

---

**Status:** Recommendation ready for approval  
**Estimated Annual Savings:** ~$13,560/year (Tier 2)  
**Implementation Effort:** 4-5 weeks 🎉

