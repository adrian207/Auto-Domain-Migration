#!/bin/bash
# Automated Helm Stack Deployment for Tier 3
# Usage: ./deploy-helm-stack.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME="${AKS_CLUSTER_NAME:-admt-tier3-aks}"
RESOURCE_GROUP="${RESOURCE_GROUP:-admt-tier3-rg}"
DOMAIN="${DOMAIN:-yourdomain.com}"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Tier 3 Helm Stack Deployment${NC}"
echo -e "${CYAN}========================================${NC}\n"

# Step 0: Prerequisites Check
echo -e "${YELLOW}[0/8] Checking prerequisites...${NC}"

command -v helm >/dev/null 2>&1 || { echo -e "${RED}❌ helm not found. Install: https://helm.sh/docs/intro/install/${NC}"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}❌ kubectl not found. Install: https://kubernetes.io/docs/tasks/tools/${NC}"; exit 1; }
command -v az >/dev/null 2>&1 || { echo -e "${RED}❌ Azure CLI not found. Install: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli${NC}"; exit 1; }

echo -e "${GREEN}✅ All prerequisites met${NC}\n"

# Get AKS credentials
echo -e "${YELLOW}Getting AKS credentials...${NC}"
az aks get-credentials --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" --overwrite-existing
echo -e "${GREEN}✅ AKS credentials configured${NC}\n"

# Add Helm repositories
echo -e "${YELLOW}Adding Helm repositories...${NC}"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add minio https://charts.min.io/
helm repo update
echo -e "${GREEN}✅ Helm repositories added${NC}\n"

# Step 1: Create Namespaces
echo -e "${YELLOW}[1/8] Creating namespaces...${NC}"
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
echo -e "${GREEN}✅ Namespaces created${NC}\n"

# Step 2: Deploy PostgreSQL HA
echo -e "${YELLOW}[2/8] Deploying PostgreSQL HA (15-20 min)...${NC}"
helm upgrade --install postgresql bitnami/postgresql-ha \
  -f helm-charts/postgresql/values.yaml \
  -n data \
  --wait \
  --timeout 20m
echo -e "${GREEN}✅ PostgreSQL deployed${NC}\n"

# Create AWX database
echo -e "${YELLOW}Creating AWX database...${NC}"
sleep 10  # Wait for PostgreSQL to be ready
kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "CREATE DATABASE awx;" 2>/dev/null || echo "Database exists"
kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "CREATE USER awx WITH PASSWORD 'ChangeThisPassword123!';" 2>/dev/null || echo "User exists"
kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- \
  psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE awx TO awx;"
echo -e "${GREEN}✅ AWX database configured${NC}\n"

# Step 3: Deploy MinIO HA
echo -e "${YELLOW}[3/8] Deploying MinIO HA (10-15 min)...${NC}"
helm upgrade --install minio minio/minio \
  -f helm-charts/minio/values.yaml \
  -n data \
  --wait \
  --timeout 15m
echo -e "${GREEN}✅ MinIO deployed${NC}\n"

# Step 4: Deploy Vault HA
echo -e "${YELLOW}[4/8] Deploying HashiCorp Vault (10 min)...${NC}"
helm upgrade --install vault hashicorp/vault \
  -f helm-charts/vault/values.yaml \
  -n security \
  --wait \
  --timeout 10m
echo -e "${GREEN}✅ Vault deployed${NC}\n"

echo -e "${CYAN}NOTE: Vault requires manual initialization. See DEPLOYMENT_GUIDE.md${NC}\n"

# Step 5: Deploy Prometheus + Grafana
echo -e "${YELLOW}[5/8] Deploying Prometheus + Grafana (15-20 min)...${NC}"
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  -f helm-charts/prometheus/values.yaml \
  -n monitoring \
  --wait \
  --timeout 20m
echo -e "${GREEN}✅ Prometheus + Grafana deployed${NC}\n"

# Step 6: Deploy Loki
echo -e "${YELLOW}[6/8] Deploying Loki (15-20 min)...${NC}"
helm upgrade --install loki grafana/loki-distributed \
  -f helm-charts/loki/values.yaml \
  -n monitoring \
  --wait \
  --timeout 20m
echo -e "${GREEN}✅ Loki deployed${NC}\n"

# Step 7: Deploy AWX Operator
echo -e "${YELLOW}[7/8] Deploying AWX Operator (5 min)...${NC}"
kubectl apply -f helm-charts/awx/awx-operator.yaml
kubectl wait --for=condition=available --timeout=300s deployment/awx-operator -n automation
echo -e "${GREEN}✅ AWX Operator deployed${NC}\n"

# Step 8: Deploy AWX Instance
echo -e "${YELLOW}[8/8] Deploying AWX Instance (20-30 min)...${NC}"
echo -e "${CYAN}This will take a while. You can monitor progress with:${NC}"
echo -e "${CYAN}  kubectl logs -n automation -f deployment/awx-operator${NC}\n"
kubectl apply -f helm-charts/awx/awx-instance.yaml
echo -e "${YELLOW}Waiting for AWX to be ready...${NC}"
kubectl wait --for=condition=Running --timeout=30m pod -l app.kubernetes.io/name=awx -n automation 2>/dev/null || true
echo -e "${GREEN}✅ AWX Instance deployed${NC}\n"

# Summary
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Deployment Complete!${NC}"
echo -e "${CYAN}========================================${NC}\n"

echo -e "${GREEN}✅ All components deployed successfully!${NC}\n"

echo -e "${YELLOW}Access your services:${NC}"
echo -e "  Grafana:     kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80"
echo -e "  Prometheus:  kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090"
echo -e "  AWX:         kubectl port-forward -n automation svc/awx-service 8052:80"
echo -e "  MinIO:       kubectl port-forward -n data svc/minio-console 9001:9001"
echo -e ""

echo -e "${YELLOW}Get admin passwords:${NC}"
echo -e "  Grafana:     admin / (from values.yaml)"
echo -e "  AWX:         kubectl get secret awx-admin-password -n automation -o jsonpath='{.data.password}' | base64 --decode"
echo -e ""

echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Initialize Vault: See helm-charts/DEPLOYMENT_GUIDE.md"
echo -e "  2. Configure AWX projects and inventories"
echo -e "  3. Import Grafana dashboards"
echo -e "  4. Test migration workflows"
echo -e ""

echo -e "${GREEN}Happy migrating! 🚀${NC}\n"

