#!/bin/bash

set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}Flux CD Cleanup Script${NC}"
echo "======================="

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

CONTEXT=$(kubectl config current-context)
echo -e "${YELLOW}Current context:${NC} $CONTEXT"
echo ""

# Show what will be removed
echo -e "${YELLOW}The following resources will be removed:${NC}"
echo "• All Flux controllers (source, kustomize, helm)"
echo "• All Flux Custom Resource Definitions"
echo "• GitRepository: flux-system"
echo "• Kustomizations: flux-system, apps"
echo "• ConfigMap: repository-config"
echo "• Secrets: flux-system"
echo "• Namespace: flux-system (and all contents)"
echo ""
echo -e "${YELLOW}Resources deployed by Flux (your applications) will NOT be removed.${NC}"
echo -e "${YELLOW}SSH keys in .keys directory will NOT be removed.${NC}"
echo ""

# Confirm cleanup
read -p "Remove Flux from cluster '$CONTEXT'? This will delete all Flux resources. (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Cleanup cancelled.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Starting Flux cleanup...${NC}"

# Stop reconciliation first by deleting Kustomizations
echo -e "${YELLOW}Step 1: Stopping reconciliation...${NC}"
echo "Deleting Kustomizations..."
kubectl delete kustomization -n flux-system --all --ignore-not-found=true --timeout=60s

echo "Deleting GitRepositories..."
kubectl delete gitrepository -n flux-system --all --ignore-not-found=true --timeout=60s

# Delete HelmReleases and HelmRepositories if any exist
echo "Deleting Helm resources..."
kubectl delete helmrelease -n flux-system --all --ignore-not-found=true --timeout=60s
kubectl delete helmrepository -n flux-system --all --ignore-not-found=true --timeout=60s

# Delete Flux controllers
echo -e "${YELLOW}Step 2: Removing Flux controllers...${NC}"
echo "Deleting deployments..."
kubectl delete deployment -n flux-system source-controller kustomize-controller helm-controller --ignore-not-found=true --timeout=120s

echo "Deleting services..."
kubectl delete service -n flux-system source-controller --ignore-not-found=true

echo "Deleting service accounts..."
kubectl delete serviceaccount -n flux-system flux --ignore-not-found=true

# Delete RBAC
echo -e "${YELLOW}Step 3: Removing RBAC resources...${NC}"
echo "Deleting cluster role bindings..."
kubectl delete clusterrolebinding flux --ignore-not-found=true

# Delete our created ConfigMap and Secrets
echo -e "${YELLOW}Step 4: Removing configuration...${NC}"
echo "Deleting repository ConfigMap..."
kubectl delete configmap -n flux-system repository-config --ignore-not-found=true

echo "Deleting Flux secrets..."
kubectl delete secret -n flux-system flux-system --ignore-not-found=true

# Delete Custom Resource Definitions
echo -e "${YELLOW}Step 5: Removing Custom Resource Definitions...${NC}"
echo "Deleting Flux CRDs..."
kubectl delete crd gitrepositories.source.toolkit.fluxcd.io --ignore-not-found=true
kubectl delete crd kustomizations.kustomize.toolkit.fluxcd.io --ignore-not-found=true
kubectl delete crd helmreleases.helm.toolkit.fluxcd.io --ignore-not-found=true
kubectl delete crd helmrepositories.source.toolkit.fluxcd.io --ignore-not-found=true

# Wait a moment for resources to be cleaned up
echo "Waiting for resources to be cleaned up..."
sleep 5

# Delete namespace (this will remove any remaining resources)
echo -e "${YELLOW}Step 6: Removing namespace...${NC}"
echo "Deleting flux-system namespace..."
kubectl delete namespace flux-system --ignore-not-found=true --timeout=120s

# Clean up any temporary files (but NOT the .keys directory)
echo -e "${YELLOW}Step 7: Cleaning up temporary files...${NC}"
TEMP_FILES=("known_hosts" "bitbucket_known_hosts" "manual_known_hosts")

FOUND_TEMP_FILES=()
for file in "${TEMP_FILES[@]}"; do
    if [ -f "$file" ]; then
        FOUND_TEMP_FILES+=("$file")
    fi
done

if [ ${#FOUND_TEMP_FILES[@]} -gt 0 ]; then
    echo -e "${YELLOW}Cleaning up temporary files:${NC}"
    for file in "${FOUND_TEMP_FILES[@]}"; do
        rm -f "$file"
        echo -e "${GREEN}✓ Removed: $file${NC}"
    done
else
    echo "No temporary files found to clean up."
fi

echo ""
echo -e "${GREEN}🎉 Flux CD cleanup complete!${NC}"
echo ""
echo -e "${YELLOW}Summary of what was removed:${NC}"
echo "✓ Flux controllers (source, kustomize, helm)"
echo "✓ Flux Custom Resource Definitions"
echo "✓ GitRepository and Kustomization resources"
echo "✓ Repository ConfigMap and Flux secrets"
echo "✓ flux-system namespace"
echo ""
echo -e "${YELLOW}📋 What was NOT removed:${NC}"
echo "• Applications deployed by Flux (in other namespaces)"
echo "• Repository configuration templates"
echo "• Cluster resources not managed by Flux"
echo "• Your Git repository and its contents"
echo ""
echo -e "${YELLOW}🔍 Verify cleanup:${NC}"
echo "  kubectl get namespaces | grep flux"
echo "  kubectl get crd | grep toolkit.fluxcd.io"
echo ""
echo -e "${GREEN}Your cluster is now clean of Flux CD components.${NC}"
echo -e "${BLUE}To redeploy Flux, run: ./deploy-flux.sh${NC}"
