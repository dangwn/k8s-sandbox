#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration (will be loaded from ConfigMap)
REPO_URL=""
BRANCH=""

echo -e "${GREEN}Deploying Flux CD to Kubernetes cluster${NC}"
echo "========================================"

CONTEXT=$(kubectl config current-context)
echo -e "Current context: ${YELLOW}$CONTEXT${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
command -v kubectl >/dev/null 2>&1 || { echo -e "${RED}kubectl is required but not installed. Aborting.${NC}" >&2; exit 1; }

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Cannot connect to Kubernetes cluster. Please check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Kubernetes cluster accessible${NC}"
echo ""
echo -e "${BLUE}Configuration will be loaded from ConfigMap${NC}"
echo ""

# Confirm deployment
read -p "Deploy Flux to cluster '$CONTEXT'? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Deployment cancelled.${NC}"
    exit 1
fi

# Create namespace
echo -e "${YELLOW}Creating flux-system namespace...${NC}"
kubectl apply -f flux-system/namespace.yaml

echo -e "${GREEN}✓ Namespace created${NC}"

# Create repository configuration ConfigMap
echo -e "${YELLOW}Creating repository configuration...${NC}"
kubectl apply -f clusters/local/repository-config.yaml

echo -e "${GREEN}✓ Repository configuration created${NC}"

# Generate Flux resources from ConfigMap
echo -e "${YELLOW}Generating Flux resources from configuration...${NC}"
./generate-flux-config.sh

echo -e "${GREEN}✓ Flux resources generated${NC}"

# Apply Flux components
echo -e "${YELLOW}Installing Flux components...${NC}"
kubectl apply -f flux-system/flux-components.yaml

# Wait for deployments
echo -e "${YELLOW}Waiting for Flux controllers to be ready...${NC}"
kubectl -n flux-system wait --for=condition=available --timeout=300s deployment/source-controller
kubectl -n flux-system wait --for=condition=available --timeout=300s deployment/kustomize-controller

echo -e "${GREEN}✓ All Flux controllers are ready${NC}"

# Apply GitRepository and Kustomizations
echo -e "${YELLOW}Configuring Git repository source...${NC}"
kubectl apply -f clusters/local/flux-system-source.yaml
kubectl apply -f clusters/local/flux-system-kustomization.yaml
kubectl apply -f clusters/local/apps-kustomization.yaml

echo -e "${GREEN}✓ Git repository and kustomizations configured${NC}"

# Load configuration for display
REPO_URL=$(kubectl get configmap repository-config -n flux-system -o jsonpath='{.data.repository_url}' 2>/dev/null || echo "ConfigMap not found")
BRANCH=$(kubectl get configmap repository-config -n flux-system -o jsonpath='{.data.repository_branch}' 2>/dev/null || echo "main")

# Final status check
echo ""
echo -e "${GREEN}🎉 Flux CD deployment complete!${NC}"
echo ""
echo -e "${YELLOW}📋 Resources created:${NC}"
echo "• Namespace: flux-system"
echo "• Deployments: source-controller, kustomize-controller"
echo "• GitRepository: flux-system"
echo "• Kustomizations: flux-system, apps"
echo ""
echo -e "${YELLOW}🔍 Check Flux status:${NC}"
echo "  kubectl -n flux-system get all"
echo "  kubectl -n flux-system get gitrepositories"
echo "  kubectl -n flux-system get kustomizations"
echo ""
echo -e "${YELLOW}📊 View logs:${NC}"
echo "  kubectl -n flux-system logs deployment/source-controller"
echo "  kubectl -n flux-system logs deployment/kustomize-controller"
echo ""
echo -e "${YELLOW}🔄 Force sync (if needed):${NC}"
echo "  kubectl -n flux-system annotate gitrepository/flux-system reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\" --overwrite"
echo ""
echo -e "${GREEN}🚀 Flux will now automatically sync from: $REPO_URL (branch: $BRANCH)${NC}"
echo ""
echo -e "${YELLOW}📝 To modify repository configuration:${NC}"
echo "  1. Edit clusters/local/repository-config.yaml"
echo "  2. Apply: kubectl apply -f clusters/local/repository-config.yaml"
echo "  3. Regenerate: ./generate-flux-config.sh"
echo "  4. Apply updated resources"
echo -e "${BLUE}Add your applications to the 'apps/' directory and they'll be deployed automatically!${NC}"
