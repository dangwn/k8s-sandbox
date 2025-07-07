#!/bin/bash

# FluxCD Deployment Script for k8s-sandbox (kubectl only)
# This script sets up FluxCD to continuously deploy from the 'apps' directory

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
GITHUB_USER="dangwn"
GITHUB_REPO="k8s-sandbox"
BRANCH="main"
FLUX_NAMESPACE="flux-system"
FLUX_VERSION="v2.4.0"
FLUX_INSTALL_URL="https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/install.yaml"

echo -e "${GREEN}🚀 FluxCD Deployment Script (kubectl only)${NC}"
echo "Repository: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo "Branch: ${BRANCH}"
echo "Apps Directory: ./apps"
echo ""

# Check prerequisites
echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

# Check if kubectl is installed and cluster is accessible
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi

echo -e "${GREEN}✅ kubectl is working${NC}"

# Get cluster info
CLUSTER_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")
echo -e "${GREEN}✅ Cluster version: ${CLUSTER_VERSION}${NC}"

# Check Kubernetes version compatibility
echo -e "${YELLOW}🔍 Checking Kubernetes version compatibility...${NC}"
KUBE_MAJOR=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | cut -d'.' -f1 | sed 's/v//' || echo "0")
KUBE_MINOR=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' | cut -d'.' -f2 || echo "0")

if [ "$KUBE_MAJOR" -gt 1 ] || ([ "$KUBE_MAJOR" -eq 1 ] && [ "$KUBE_MINOR" -ge 28 ]); then
    echo -e "${GREEN}✅ Kubernetes version is compatible (v1.28+)${NC}"
else
    echo -e "${YELLOW}⚠️  Kubernetes version may not be fully compatible (requires v1.28+)${NC}"
fi

# Install Flux components
echo -e "${YELLOW}📦 Installing Flux components...${NC}"
echo "Downloading FluxCD ${FLUX_VERSION} components..."

if kubectl apply -f "${FLUX_INSTALL_URL}"; then
    echo -e "${GREEN}✅ FluxCD components installed successfully${NC}"
else
    echo -e "${RED}❌ Failed to install FluxCD components${NC}"
    exit 1
fi

# Wait for Flux to be ready
echo -e "${YELLOW}⏳ Waiting for Flux components to be ready...${NC}"

# Wait for namespace to be created
echo "Waiting for flux-system namespace..."
while ! kubectl get namespace flux-system &> /dev/null; do
    sleep 2
done

# Wait for deployments to be available
COMPONENTS=("source-controller" "kustomize-controller" "helm-controller" "notification-controller")
for component in "${COMPONENTS[@]}"; do
    echo "Waiting for ${component} to be ready..."
    kubectl wait --for=condition=available deployment/${component} -n flux-system --timeout=300s
done

echo -e "${GREEN}✅ All Flux components are ready${NC}"

# Create GitRepository resource
echo -e "${YELLOW}🔗 Creating GitRepository resource...${NC}"
cat <<EOF | kubectl apply -f -
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: ${BRANCH}
  url: https://github.com/${GITHUB_USER}/${GITHUB_REPO}
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ GitRepository created successfully${NC}"
else
    echo -e "${RED}❌ Failed to create GitRepository${NC}"
    exit 1
fi

# Create Kustomization for apps directory
echo -e "${YELLOW}📁 Creating Kustomization for apps directory...${NC}"
cat <<EOF | kubectl apply -f -
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./apps
  prune: true
  wait: true
  timeout: 5m0s
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Kustomization created successfully${NC}"
else
    echo -e "${RED}❌ Failed to create Kustomization${NC}"
    exit 1
fi

# Wait for GitRepository to be ready
echo -e "${YELLOW}⏳ Waiting for GitRepository to sync...${NC}"
timeout=60
counter=0
while [ $counter -lt $timeout ]; do
    GIT_READY=$(kubectl get gitrepository flux-system -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [ "$GIT_READY" = "True" ]; then
        echo -e "${GREEN}✅ GitRepository is ready and synced${NC}"
        break
    fi
    echo "Waiting for GitRepository to sync... ($counter/$timeout)"
    sleep 2
    counter=$((counter + 2))
done

if [ "$GIT_READY" != "True" ]; then
    echo -e "${YELLOW}⚠️  GitRepository may still be syncing${NC}"
fi

# Check status
echo -e "${YELLOW}📊 Checking FluxCD status...${NC}"
echo ""
echo "GitRepository status:"
kubectl get gitrepository -n flux-system -o wide
echo ""
echo "Kustomization status:"
kubectl get kustomization -n flux-system -o wide
echo ""

# Show pod status
echo "FluxCD pod status:"
kubectl get pods -n flux-system
echo ""

# Wait for initial apps sync (optional, may fail if apps directory is empty)
echo -e "${YELLOW}⏳ Checking apps synchronization...${NC}"
timeout=30
counter=0
while [ $counter -lt $timeout ]; do
    KUST_READY=$(kubectl get kustomization apps -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
    if [ "$KUST_READY" = "True" ]; then
        echo -e "${GREEN}✅ Apps Kustomization is ready${NC}"
        break
    elif [ "$KUST_READY" = "False" ]; then
        KUST_MESSAGE=$(kubectl get kustomization apps -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}' 2>/dev/null || echo "unknown")
        echo -e "${YELLOW}⚠️  Apps Kustomization: $KUST_MESSAGE${NC}"
        break
    fi
    echo "Waiting for apps sync... ($counter/$timeout)"
    sleep 2
    counter=$((counter + 2))
done

echo ""
echo -e "${GREEN}🎉 FluxCD has been successfully deployed!${NC}"
echo ""
echo -e "${YELLOW}📝 Configuration Summary:${NC}"
echo "  - Repository: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
echo "  - Branch: ${BRANCH}"
echo "  - Monitored directory: ./apps"
echo "  - Sync interval: 1 minute"
echo "  - Namespace: ${FLUX_NAMESPACE}"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Add your Kubernetes manifests to the 'apps' directory in your repository"
echo "2. Commit and push changes to the '${BRANCH}' branch"
echo "3. FluxCD will automatically detect and deploy your applications"
echo ""
echo -e "${YELLOW}🔍 Useful kubectl commands:${NC}"
echo "  - Check GitRepository: kubectl get gitrepository -n flux-system"
echo "  - Check Kustomizations: kubectl get kustomization -n flux-system"
echo "  - View GitRepository details: kubectl describe gitrepository flux-system -n flux-system"
echo "  - View Kustomization details: kubectl describe kustomization apps -n flux-system"
echo "  - Check FluxCD pods: kubectl get pods -n flux-system"
echo "  - View logs: kubectl logs -n flux-system deployment/source-controller"
echo "  - Force reconciliation: kubectl annotate --overwrite gitrepository/flux-system -n flux-system reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\""
echo ""
echo -e "${YELLOW}🔄 Manual reconciliation commands:${NC}"
echo "  - Sync repository: kubectl annotate --overwrite gitrepository/flux-system -n flux-system reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\""
echo "  - Sync apps: kubectl annotate --overwrite kustomization/apps -n flux-system reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\""
echo ""
echo -e "${GREEN}✨ Happy GitOps-ing with kubectl!${NC}"