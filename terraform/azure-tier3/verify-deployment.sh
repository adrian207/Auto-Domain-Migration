#!/bin/bash
# Verify Tier 3 Helm Stack Deployment
# Usage: ./verify-deployment.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Tier 3 Deployment Verification${NC}"
echo -e "${CYAN}========================================${NC}\n"

FAILED=0

# Function to check component
check_component() {
    local name=$1
    local namespace=$2
    local selector=$3
    
    echo -e "${YELLOW}Checking $name...${NC}"
    
    if kubectl get pods -n "$namespace" -l "$selector" | grep -q Running; then
        echo -e "${GREEN}  ✅ $name is running${NC}"
        return 0
    else
        echo -e "${RED}  ❌ $name is NOT running${NC}"
        kubectl get pods -n "$namespace" -l "$selector"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Check namespaces
echo -e "${YELLOW}Checking namespaces...${NC}"
for ns in data security monitoring automation; do
    if kubectl get namespace "$ns" &>/dev/null; then
        echo -e "${GREEN}  ✅ Namespace $ns exists${NC}"
    else
        echo -e "${RED}  ❌ Namespace $ns missing${NC}"
        FAILED=$((FAILED + 1))
    fi
done
echo ""

# Check PostgreSQL
check_component "PostgreSQL" "data" "app.kubernetes.io/name=postgresql-ha"
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}  Testing PostgreSQL connection...${NC}"
    if kubectl exec -n data postgresql-postgresql-ha-pgpool-0 -- psql -U postgres -c "SELECT version();" &>/dev/null; then
        echo -e "${GREEN}  ✅ PostgreSQL connection successful${NC}"
    else
        echo -e "${RED}  ❌ PostgreSQL connection failed${NC}"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# Check MinIO
check_component "MinIO" "data" "app=minio"
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}  Checking MinIO status...${NC}"
    MINIO_PODS=$(kubectl get pods -n data -l app=minio --no-headers | wc -l)
    if [ "$MINIO_PODS" -eq 6 ]; then
        echo -e "${GREEN}  ✅ All 6 MinIO nodes running${NC}"
    else
        echo -e "${RED}  ❌ Expected 6 MinIO nodes, found $MINIO_PODS${NC}"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# Check Vault
check_component "Vault" "security" "app.kubernetes.io/name=vault"
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}  Checking Vault status...${NC}"
    if kubectl exec -n security vault-0 -- vault status &>/dev/null; then
        SEALED=$(kubectl exec -n security vault-0 -- vault status -format=json 2>/dev/null | grep -o '"sealed":[^,]*' | cut -d: -f2)
        if [ "$SEALED" = "false" ]; then
            echo -e "${GREEN}  ✅ Vault is unsealed${NC}"
        else
            echo -e "${YELLOW}  ⚠️  Vault is sealed (expected if not initialized)${NC}"
        fi
    else
        echo -e "${RED}  ❌ Vault status check failed${NC}"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# Check Prometheus
check_component "Prometheus" "monitoring" "app.kubernetes.io/name=prometheus"
echo ""

# Check Grafana
check_component "Grafana" "monitoring" "app.kubernetes.io/name=grafana"
echo ""

# Check Alertmanager
check_component "Alertmanager" "monitoring" "app.kubernetes.io/name=alertmanager"
echo ""

# Check Loki
check_component "Loki Gateway" "monitoring" "app.kubernetes.io/component=gateway,app.kubernetes.io/instance=loki"
echo ""

# Check AWX Operator
check_component "AWX Operator" "automation" "name=awx-operator"
echo ""

# Check AWX
check_component "AWX" "automation" "app.kubernetes.io/name=awx"
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}  Checking AWX status...${NC}"
    AWX_STATUS=$(kubectl get awx -n automation -o jsonpath='{.items[0].status.conditions[?(@.type=="Running")].status}' 2>/dev/null)
    if [ "$AWX_STATUS" = "True" ]; then
        echo -e "${GREEN}  ✅ AWX is fully operational${NC}"
    else
        echo -e "${YELLOW}  ⚠️  AWX may still be initializing${NC}"
    fi
fi
echo ""

# Check PVCs
echo -e "${YELLOW}Checking Persistent Volume Claims...${NC}"
PVC_COUNT=$(kubectl get pvc -A --no-headers | wc -l)
PVC_BOUND=$(kubectl get pvc -A --no-headers | grep Bound | wc -l)
echo -e "${GREEN}  Total PVCs: $PVC_COUNT${NC}"
echo -e "${GREEN}  Bound PVCs: $PVC_BOUND${NC}"
if [ "$PVC_COUNT" -ne "$PVC_BOUND" ]; then
    echo -e "${RED}  ❌ Some PVCs are not bound:${NC}"
    kubectl get pvc -A | grep -v Bound
    FAILED=$((FAILED + 1))
fi
echo ""

# Check Services
echo -e "${YELLOW}Checking Services...${NC}"
SERVICES=(
    "data:postgresql-postgresql-ha-pgpool"
    "data:minio"
    "security:vault"
    "monitoring:kube-prometheus-prometheus"
    "monitoring:kube-prometheus-grafana"
    "monitoring:loki-gateway"
    "automation:awx-service"
)

for svc in "${SERVICES[@]}"; do
    IFS=':' read -r ns name <<< "$svc"
    if kubectl get svc -n "$ns" "$name" &>/dev/null; then
        echo -e "${GREEN}  ✅ Service $name found in $ns${NC}"
    else
        echo -e "${RED}  ❌ Service $name missing in $ns${NC}"
        FAILED=$((FAILED + 1))
    fi
done
echo ""

# Resource Usage
echo -e "${YELLOW}Cluster Resource Usage:${NC}"
kubectl top nodes 2>/dev/null || echo -e "${YELLOW}  (metrics-server not available)${NC}"
echo ""

# Summary
echo -e "${CYAN}========================================${NC}"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}  ✅ All checks passed!${NC}"
    echo -e "${CYAN}========================================${NC}\n"
    
    echo -e "${YELLOW}Access URLs (after port-forward):${NC}"
    echo -e "  Grafana:     http://localhost:3000"
    echo -e "  Prometheus:  http://localhost:9090"
    echo -e "  AWX:         http://localhost:8052"
    echo -e "  MinIO:       http://localhost:9001"
    echo -e ""
    
    exit 0
else
    echo -e "${RED}  ❌ $FAILED checks failed${NC}"
    echo -e "${CYAN}========================================${NC}\n"
    
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  1. Check pod logs: kubectl logs -n <namespace> <pod-name>"
    echo -e "  2. Describe pods: kubectl describe pod -n <namespace> <pod-name>"
    echo -e "  3. Check events: kubectl get events -n <namespace> --sort-by='.lastTimestamp'"
    echo -e "  4. See DEPLOYMENT_GUIDE.md for detailed troubleshooting"
    echo -e ""
    
    exit 1
fi

