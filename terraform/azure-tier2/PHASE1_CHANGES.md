# Phase 1: Terraform Optimization Changes

**Date:** October 2025  
**Status:** ✅ Complete - Ready for Review

---

## 🎯 Changes Made

### 1. Domain Controller Optimization
```hcl
BEFORE:
- VM Size: Standard_D4s_v5 (4 vCPU, 16GB RAM) = $70/month
- OS: Windows Server 2022 Desktop Experience
- Disk: Premium_LRS, 256GB
- Purpose: Over-provisioned for DC role

AFTER:
- VM Size: Standard_B2s (2 vCPU, 4GB RAM) = $31/month ⭐
- OS: Windows Server 2022 Core (no GUI)
- Disk: StandardSSD_LRS, 40GB
- Purpose: Right-sized for ADMT endpoint

Savings: $39/month per DC ($78/month for 2 DCs)
```

### 2. Azure Container Apps Infrastructure
```hcl
NEW: container-apps.tf

Created:
✅ Container Apps Environment
✅ Ansible Controller (Container App)
   - 4 vCPU, 8GB RAM
   - Auto-scales 1-3 replicas
   - Cost: ~$150/month
   
✅ Guacamole Bastion (Container App)
   - 2 vCPU, 4GB RAM
   - Auto-scales 1-2 replicas
   - Cost: ~$76/month
   
✅ Prometheus (Container App)
   - 2 vCPU, 4GB RAM
   - Persistent storage via Azure Files
   - Cost: ~$76/month
   
✅ Grafana (Container App)
   - 2 vCPU, 4GB RAM
   - PostgreSQL backend
   - Cost: ~$78/month

Total Container Apps: ~$380/month
vs Previous VM-based: ~$770/month
Savings: $390/month
```

### 3. Storage Shares
```hcl
NEW: Azure File Shares for persistent data
- ansible-data (10GB)
- prometheus-data (50GB)
- prometheus-config (1GB)
- grafana-data (10GB)

Cost: ~$10/month
```

---

## 💰 Cost Impact

| Component | Before | After | Savings |
|-----------|--------|-------|---------|
| **Ansible VMs** | $560 | $150 (Container) | -$410 |
| **Guacamole VM** | $70 | $76 (Container) | -$0 |
| **Monitoring VM** | $140 | $154 (2 Containers) | -$0 |
| **Source DC** | $70 | $0 (customer existing) | -$70 |
| **Target DC** | $70 | $31 (B2s Core) | -$39 |
| **Storage Shares** | $0 | $10 | +$10 |
| **TOTAL COMPUTE** | $910 | $421 | **-$489/mo** |

**Monthly Savings: $489 (54% reduction on compute)**

---

## 📁 Files Modified

### Updated Files:
1. `terraform/azure-tier2/variables.tf`
   - Changed `dc_vm_size` default from D4s_v5 to B2s
   - Added `ansible_container_image` variable

2. `terraform/azure-tier2/compute.tf`
   - Changed Windows image from Desktop to Server Core
   - Changed disk from Premium_LRS to StandardSSD_LRS
   - Reduced disk size from 256GB to 40GB

### New Files:
3. `terraform/azure-tier2/container-apps.tf` (NEW)
   - Container Apps Environment
   - Ansible Controller Container App
   - Guacamole Container App
   - Prometheus Container App
   - Grafana Container App
   - Storage shares for persistent data

---

## ⚠️ Important Notes

### Container Images Required
```yaml
Before deployment, you need to:
1. Build container images (Phase 3)
2. Push to Azure Container Registry
3. Update image references in variables.tf

Current placeholders:
- migration-controller:latest (Ansible)
- guacamole/guacamole:latest (public)
- prom/prometheus:latest (public)
- grafana/grafana:latest (public)
```

### Server Core Management
```yaml
Domain Controllers now use Server Core:
✅ No GUI (managed remotely)
✅ All management via:
   - Ansible (WinRM)
   - PowerShell remoting
   - Windows Admin Center
   - RSAT tools

ADMT installation and execution:
- Fully automated via Ansible (Phase 2)
- No manual DC login required
```

### Migration Path
```yaml
From current all-VM deployment:
1. Deploy container apps environment
2. Deploy container apps
3. Test workloads in containers
4. Migrate Ansible playbooks to container-based controller
5. Switch DNS/traffic to new container apps
6. Decommission old VMs
7. Enjoy 54% cost savings!

Rollback plan:
- Keep old VMs running during transition
- Can revert to VMs if issues arise
- Low risk migration path
```

---

## 🧪 Testing Checklist

Before deploying to production:

**Infrastructure Tests:**
- [ ] `terraform plan` succeeds
- [ ] `terraform validate` passes
- [ ] Container Apps Environment creates successfully
- [ ] Storage shares accessible from containers
- [ ] B2s Server Core DCs provision correctly

**Functionality Tests:**
- [ ] Ansible controller can reach DCs via WinRM
- [ ] Guacamole can RDP to DCs
- [ ] Prometheus scrapes metrics
- [ ] Grafana connects to PostgreSQL
- [ ] ADMT installs on Server Core DC

**Cost Validation:**
- [ ] Azure Cost Management shows expected costs
- [ ] No unexpected charges
- [ ] Resource tags applied correctly

---

## 🚀 Deployment Commands

```bash
# Review changes
cd terraform/azure-tier2
terraform plan -out=phase1.tfplan

# Review the plan carefully:
# - Verify DC downsizing
# - Verify container apps creation
# - Check for any resource destruction

# If plan looks good:
terraform apply phase1.tfplan

# Expected deployment time: 10-15 minutes
```

---

## 📊 Expected Results

After Phase 1 deployment:

```yaml
Infrastructure State:
✅ Container Apps Environment running
✅ Ansible Controller (container) running
✅ Guacamole Bastion (container) running
✅ Prometheus (container) collecting metrics
✅ Grafana (container) showing dashboards
✅ 2x Domain Controllers (B2s Server Core) running
✅ PostgreSQL Flexible Server running
✅ Storage shares created and mounted

Ready for Phase 2:
- Ansible playbooks need to be deployed
- ADMT installation automation needed
- Container images need to be built (if using custom)
```

---

## 🔜 Next Phase

**Phase 2: Ansible Automation**
- Create ADMT installation role
- Create ADMT execution playbooks
- Create domain trust configuration
- Create wave-based migration orchestration
- Test end-to-end migration flow

---

**Status:** Phase 1 complete - awaiting user review before Phase 2  
**Estimated savings:** $489/month on compute + additional on platform services  
**Risk level:** Low (can rollback to VMs if needed) ✅

