#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Repository Configuration Updater${NC}"
echo "=================================="

# Check if parameters provided
if [ $# -lt 2 ]; then
    echo -e "${YELLOW}Usage: $0 <repository-url> <branch> [sync-interval]${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 https://github.com/user/repo.git main"
    echo "  $0 https://github.com/user/repo.git main 30s"
    echo "  $0 git@github.com:user/repo.git main 2m"
    echo ""
    echo -e "${YELLOW}Current configuration:${NC}"
    if kubectl get configmap repository-config -n flux-system &> /dev/null; then
        kubectl get configmap repository-config -n flux-system -o jsonpath='{.data}' | jq -r 'to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || {
            echo "  repository_url: $(kubectl get configmap repository-config -n flux-system -o jsonpath='{.data.repository_url}')"
            echo "  repository_branch: $(kubectl get configmap repository-config -n flux-system -o jsonpath='{.data.repository_branch}')"
            echo "  sync_interval: $(kubectl get configmap repository-config -n flux-system -o jsonpath='{.data.sync_interval}')"
        }
    else
        echo "  ConfigMap not found - run ./deploy-flux.sh first"
    fi
    echo ""
    exit 1
fi

REPO_URL="$1"
BRANCH="$2"
SYNC_INTERVAL="${3:-1m0s}"

echo -e "${BLUE}New configuration:${NC}"
echo "  Repository URL: $REPO_URL"
echo "  Branch: $BRANCH"
echo "  Sync Interval: $SYNC_INTERVAL"
echo ""

# Confirm update
read -p "Update repository configuration? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Update cancelled.${NC}"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${YELLOW}Updating ConfigMap...${NC}"

# Update the ConfigMap file
cat > clusters/local/repository-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: repository-config
  namespace: flux-system
data:
  # Repository Configuration
  repository_url: "$REPO_URL"
  repository_branch: "$BRANCH"
  repository_path: "."
  
  # Sync Configuration
  sync_interval: "$SYNC_INTERVAL"
  kustomization_interval: "10m"
  apps_interval: "1m"
  
  # Paths
  flux_path: "./clusters/local"
  apps_path: "./apps"
  
  # Git Implementation
  git_implementation: "go-git"
  
  # Verification
  verify_mode: "none"
  
  # Prune Configuration
  prune_enabled: "true"
EOF

echo -e "${GREEN}✓ Updated repository-config.yaml${NC}"

# Apply the ConfigMap to cluster
echo -e "${YELLOW}Applying ConfigMap to cluster...${NC}"
kubectl apply -f clusters/local/repository-config.yaml

echo -e "${GREEN}✓ ConfigMap applied to cluster${NC}"

# Regenerate Flux resources
echo -e "${YELLOW}Regenerating Flux resources...${NC}"
./generate-flux-config.sh

echo -e "${GREEN}✓ Flux resources regenerated${NC}"

# Apply updated resources
echo -e "${YELLOW}Applying updated Flux resources...${NC}"
kubectl apply -f clusters/local/flux-system-source.yaml
kubectl apply -f clusters/local/flux-system-kustomization.yaml
kubectl apply -f clusters/local/apps-kustomization.yaml

echo -e "${GREEN}✓ Flux resources updated${NC}"

# Force reconciliation to pick up changes immediately
echo -e "${YELLOW}Forcing immediate reconciliation...${NC}"
kubectl -n flux-system annotate gitrepository/flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

echo ""
echo -e "${GREEN}🎉 Repository configuration updated successfully!${NC}"
echo ""
echo -e "${YELLOW}📋 Summary:${NC}"
echo "• Repository URL: $REPO_URL"
echo "• Branch: $BRANCH"
echo "• Sync Interval: $SYNC_INTERVAL"
echo ""
echo -e "${YELLOW}🔍 Check status:${NC}"
echo "  kubectl -n flux-system get gitrepositories"
echo "  kubectl -n flux-system get kustomizations"
echo ""
echo -e "${BLUE}Flux will now monitor the new repository configuration!${NC}"