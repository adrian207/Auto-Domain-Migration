# Container-Based Migration Architecture

**Date:** October 2025  
**Author:** Adrian Johnson  
**Status:** Design Document

## Executive Summary

This document outlines the **container-first architecture** for the Active Directory domain migration solution, eliminating the need for binary acquisition and ISO management by leveraging:

1. **Azure Marketplace VMs** (for Azure deployments)
2. **Container-based tools** (for all deployments)
3. **Docker/Podman** for migration tool execution

---

## 🎯 Core Principle

**Everything runs in containers** - no binary downloads, no ISO management, no manual installations.

```
Traditional Approach ❌          Container Approach ✅
├─ Download ISOs                ├─ Pull container images
├─ Mount ISOs                   ├─ Run containers
├─ Install software             ├─ Auto-configured
├─ Configure manually           ├─ Orchestrated by Ansible
└─ Version conflicts            └─ Isolated environments
```

---

## 🏗️ Architecture Overview

### Azure Deployment (Tier 2 / Free Tier)

```
Azure Resource Group
├── Rocky Linux VMs (Marketplace)
│   ├── Guacamole Bastion
│   │   └── Docker: guacamole/guacamole:latest
│   ├── Ansible Controller
│   │   └── Docker: migration-controller:latest
│   └── Monitoring
│       ├── Docker: prom/prometheus:latest
│       └── Docker: grafana/grafana:latest
│
├── Windows Server VMs (Marketplace)
│   ├── Source DC (marketplace image)
│   │   └── Docker Desktop: admt-container:latest
│   └── Target DC (marketplace image)
│       └── Docker Desktop: admt-container:latest
│
└── Windows Desktop VMs (Marketplace)
    └── Test Workstation (marketplace image)
        └── Docker Desktop: usmt-container:latest
```

**Key Benefits:**
- ✅ No ISOs required - Azure Marketplace handles images
- ✅ Licensing included or use Azure Hybrid Benefit
- ✅ Instant provisioning via Terraform
- ✅ All tools run in containers

---

### vSphere Deployment (Tier 1 / Tier 2)

```
vSphere Cluster
├── Container Runtime Options:
│   Option A: VM + Docker (Simple)
│   ├── Rocky Linux VM template
│   └── Docker CE installed via cloud-init
│
│   Option B: vSphere with Tanzu (Advanced)
│   ├── Kubernetes on vSphere
│   ├── vSphere Pods
│   └── Container VMs
│
│   Option C: Photon OS (VMware Native)
│   ├── Photon OS VM template
│   └── Docker/containerd built-in
│
└── For Windows workloads:
    ├── Windows Server Core VMs (minimal)
    └── Docker Desktop for Windows
```

**Recommendation for vSphere:**
- **Tier 1 (Demo):** Rocky Linux VMs + Docker (simple, works everywhere)
- **Tier 3 (Enterprise):** vSphere with Tanzu + Kubernetes (full orchestration)

---

## 📦 Container Images

### Migration Tool Containers

#### 1. Migration Controller (Linux)
```dockerfile
# Dockerfile: migration-controller
FROM rockylinux:9

# Install Python and Ansible
RUN dnf install -y python3 python3-pip ansible-core \
    && pip3 install pywinrm psycopg2-binary azure-storage-blob

# Copy Ansible playbooks and roles
COPY ansible/ /opt/ansible/
COPY scripts/ /opt/scripts/

WORKDIR /opt/ansible
ENTRYPOINT ["ansible-playbook"]
```

**Usage:**
```bash
docker run -v /opt/migration:/data \
  migration-controller:latest \
  playbooks/migrate_wave1.yml
```

---

#### 2. ADMT Container (Windows Server Core)
```dockerfile
# Dockerfile: admt-container
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Download and install ADMT
ADD https://download.microsoft.com/download/.../admtsetup32.exe C:/Temp/
RUN C:\Temp\admtsetup32.exe /quiet /norestart

# PowerShell wrapper scripts
COPY scripts/admt-wrapper.ps1 C:/Scripts/

ENTRYPOINT ["powershell.exe", "C:/Scripts/admt-wrapper.ps1"]
```

**Usage:**
```bash
docker run -v C:\Migration:C:\Data \
  admt-container:latest \
  -Action MigrateUsers -Wave 1
```

---

#### 3. USMT Container (Windows)
```dockerfile
# Dockerfile: usmt-container
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Download Windows ADK and install USMT
ADD https://go.microsoft.com/fwlink/?linkid=2243390 C:/Temp/adksetup.exe
RUN C:\Temp\adksetup.exe /quiet /features OptionId.UserStateMigrationTool

# USMT wrapper scripts
COPY scripts/usmt-wrapper.ps1 C:/Scripts/

ENTRYPOINT ["powershell.exe", "C:/Scripts/usmt-wrapper.ps1"]
```

**Usage:**
```bash
# Capture user state
docker run -v C:\MigrationStore:C:\Store \
  usmt-container:latest \
  -Action Capture -User jdoe

# Restore user state
docker run -v C:\MigrationStore:C:\Store \
  usmt-container:latest \
  -Action Restore -User jdoe
```

---

#### 4. Monitoring Stack (Linux)
```yaml
# docker-compose.yml for monitoring
version: '3'
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana-data:/var/lib/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"

volumes:
  prometheus-data:
  grafana-data:
```

---

## 🔄 Container Orchestration

### Ansible Integration

```yaml
# playbooks/10_migrate_users.yml
---
- name: Migrate User Accounts (Containerized)
  hosts: source_dc
  tasks:
    - name: Run ADMT container for user migration
      community.docker.docker_container:
        name: admt-migrate-wave{{ wave_number }}
        image: admt-container:latest
        state: started
        volumes:
          - /mnt/migration:/data
        env:
          SOURCE_DOMAIN: "{{ source_domain }}"
          TARGET_DOMAIN: "{{ target_domain }}"
          WAVE_NUMBER: "{{ wave_number }}"
        command: >
          -Action MigrateUsers
          -Wave {{ wave_number }}
          -DatabaseConnection "{{ postgres_connection }}"
      register: admt_result

    - name: Wait for ADMT container to complete
      community.docker.docker_container_info:
        name: admt-migrate-wave{{ wave_number }}
      register: container_info
      until: container_info.container.State.Status == "exited"
      retries: 60
      delay: 10

    - name: Check ADMT exit code
      fail:
        msg: "ADMT migration failed"
      when: container_info.container.State.ExitCode != 0
```

---

## 🎨 Container Build Pipeline

### Automated Image Building

```yaml
# .github/workflows/build-containers.yml
name: Build Migration Containers

on:
  push:
    branches: [main]
    paths:
      - 'containers/**'

jobs:
  build-linux:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build migration-controller
        run: |
          cd containers/migration-controller
          docker build -t migration-controller:${{ github.sha }} .
          docker tag migration-controller:${{ github.sha }} migration-controller:latest
      
      - name: Push to registry
        run: |
          docker push migration-controller:latest

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build ADMT container
        run: |
          cd containers/admt
          docker build -t admt-container:${{ github.sha }} .
          docker tag admt-container:${{ github.sha }} admt-container:latest
      
      - name: Build USMT container
        run: |
          cd containers/usmt
          docker build -t usmt-container:${{ github.sha }} .
          docker tag usmt-container:${{ github.sha }} usmt-container:latest
```

---

## 💾 Container Registry Strategy

### Option 1: Azure Container Registry (Recommended for Azure)
```hcl
# terraform/azure-tier2/registry.tf
resource "azurerm_container_registry" "main" {
  name                = "${var.project_name}acr${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"  # $5/month, 10GB storage
  admin_enabled       = true
  
  tags = local.common_tags
}
```

### Option 2: Harbor (Self-hosted for vSphere)
```yaml
# docker-compose.yml for Harbor
version: '3'
services:
  harbor:
    image: goharbor/harbor-core:latest
    volumes:
      - harbor-data:/data
    ports:
      - "80:8080"
      - "443:8443"
```

### Option 3: Docker Hub (Public/Development)
```bash
# Push to Docker Hub
docker login
docker tag migration-controller:latest yourusername/migration-controller:latest
docker push yourusername/migration-controller:latest
```

---

## 🚀 Deployment Workflow

### Phase 1: Infrastructure Provisioning
```bash
# Deploy Azure infrastructure with marketplace VMs
cd terraform/azure-tier2
terraform init
terraform apply

# Result: Rocky Linux VMs with Docker pre-installed via cloud-init
```

### Phase 2: Container Preparation
```bash
# Build and push containers (one-time or CI/CD)
cd containers
./build-all.sh
./push-to-registry.sh
```

### Phase 3: Migration Execution
```bash
# Run migration - everything in containers
ansible-playbook playbooks/migrate_full.yml \
  --extra-vars "wave_number=1"

# Behind the scenes:
# - Pulls migration-controller container
# - Pulls ADMT container on Windows DCs
# - Pulls USMT container on workstations
# - Executes migration orchestration
# - All state tracked in PostgreSQL
```

---

## 📊 Benefits Summary

### Azure Deployment
| Aspect | Traditional | Container-Based |
|--------|-------------|-----------------|
| **VM Provisioning** | Manual ISO upload | Marketplace (instant) |
| **Licensing** | Manual KMS/MAK | Included or Hybrid Benefit |
| **Tool Installation** | Manual downloads | Container pull |
| **Version Control** | Manual updates | Container tags |
| **Deployment Time** | Hours | Minutes |
| **Reproducibility** | Difficult | Perfect (immutable) |

### vSphere Deployment
| Aspect | Traditional | Container-Based |
|--------|-------------|-----------------|
| **ISO Management** | Upload & mount | Rocky template only |
| **Software Install** | Manual scripting | Container pull |
| **Portability** | Tied to vSphere | Runs anywhere |
| **Scaling** | Clone VMs | Scale containers |
| **Resource Usage** | Heavy VMs | Lightweight containers |

---

## 🔧 Implementation Checklist

### For Azure Deployments
- [x] Terraform uses marketplace images (no ISOs)
- [ ] Cloud-init installs Docker on Linux VMs
- [ ] Docker Desktop on Windows VMs (optional)
- [ ] Azure Container Registry configured
- [ ] Container images built and pushed
- [ ] Ansible playbooks use docker modules

### For vSphere Deployments
- [ ] Create Rocky Linux VM template
- [ ] Install Docker/containerd in template
- [ ] Set up Harbor or use external registry
- [ ] Build Windows Server Core template
- [ ] Test container execution
- [ ] Ansible playbooks adapted for vSphere

---

## 🎯 Next Steps

1. ✅ **Azure confirmed** - Already using marketplace VMs
2. 🔄 **Create Dockerfiles** - For all migration tools
3. 🔄 **Build container images** - Automate with CI/CD
4. 🔄 **Update Ansible playbooks** - Use docker modules
5. 🔄 **Test end-to-end** - Full migration in containers
6. 📝 **Document operations** - Container troubleshooting guide

---

## 🆘 Troubleshooting

### Container Issues
```bash
# Check container logs
docker logs admt-migrate-wave1

# Enter container for debugging
docker exec -it admt-migrate-wave1 powershell

# Check container resource usage
docker stats

# Remove failed containers
docker rm -f $(docker ps -aq --filter "status=exited")
```

### Registry Issues
```bash
# Login to Azure Container Registry
az acr login --name ${ACR_NAME}

# Test image pull
docker pull ${ACR_NAME}.azurecr.io/migration-controller:latest
```

---

## 📚 References

- **Azure Marketplace:** https://azuremarketplace.microsoft.com/
- **Docker Windows Containers:** https://docs.microsoft.com/virtualization/windowscontainers/
- **vSphere with Tanzu:** https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-with-tanzu/
- **Ansible Docker Module:** https://docs.ansible.com/ansible/latest/collections/community/docker/

---

**Status:** Architecture designed, ready for implementation  
**No binary acquisition needed** - everything runs in containers! 🎉

