#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONFIG_MAP_NAME="repository-config"
NAMESPACE="flux-system"
TEMPLATE_DIR="clusters/local"
OUTPUT_DIR="clusters/local"

echo -e "${GREEN}Generating Flux resources from ConfigMap${NC}"
echo "============================================="

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

# Check if ConfigMap exists
if ! kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE &> /dev/null; then
    echo -e "${RED}ConfigMap '$CONFIG_MAP_NAME' not found in namespace '$NAMESPACE'.${NC}"
    echo "Please create it first by running:"
    echo "  kubectl apply -f clusters/local/repository-config.yaml"
    exit 1
fi

echo -e "${YELLOW}Reading configuration from ConfigMap: $CONFIG_MAP_NAME${NC}"

# Extract values from ConfigMap
export REPOSITORY_URL=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.repository_url}')
export REPOSITORY_BRANCH=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.repository_branch}')
export SYNC_INTERVAL=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.sync_interval}')
export KUSTOMIZATION_INTERVAL=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.kustomization_interval}')
export APPS_INTERVAL=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.apps_interval}')
export FLUX_PATH=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.flux_path}')
export APPS_PATH=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.apps_path}')
export PRUNE_ENABLED=$(kubectl get configmap $CONFIG_MAP_NAME -n $NAMESPACE -o jsonpath='{.data.prune_enabled}')

# Validate required values
if [[ -z "$REPOSITORY_URL" || -z "$REPOSITORY_BRANCH" ]]; then
    echo -e "${RED}Missing required configuration values in ConfigMap.${NC}"
    echo "Required: repository_url, repository_branch"
    exit 1
fi

echo -e "${BLUE}Configuration loaded:${NC}"
echo "  Repository URL: $REPOSITORY_URL"
echo "  Branch: $REPOSITORY_BRANCH"
echo "  Sync Interval: $SYNC_INTERVAL"
echo "  Flux Path: $FLUX_PATH"
echo "  Apps Path: $APPS_PATH"
echo ""

# Generate GitRepository resource
echo -e "${YELLOW}Generating GitRepository resource...${NC}"
if [[ -f "$TEMPLATE_DIR/flux-system-source.template.yaml" ]]; then
    envsubst < "$TEMPLATE_DIR/flux-system-source.template.yaml" > "$OUTPUT_DIR/flux-system-source.yaml"
    echo -e "${GREEN}✓ Generated: $OUTPUT_DIR/flux-system-source.yaml${NC}"
else
    echo -e "${RED}✗ Template not found: $TEMPLATE_DIR/flux-system-source.template.yaml${NC}"
fi

# Generate flux-system Kustomization resource  
echo -e "${YELLOW}Generating flux-system Kustomization resource...${NC}"
if [[ -f "$TEMPLATE_DIR/flux-system-kustomization.template.yaml" ]]; then
    envsubst < "$TEMPLATE_DIR/flux-system-kustomization.template.yaml" > "$OUTPUT_DIR/flux-system-kustomization.yaml"
    echo -e "${GREEN}✓ Generated: $OUTPUT_DIR/flux-system-kustomization.yaml${NC}"
else
    echo -e "${RED}✗ Template not found: $TEMPLATE_DIR/flux-system-kustomization.template.yaml${NC}"
fi

# Generate apps Kustomization resource
echo -e "${YELLOW}Generating apps Kustomization resource...${NC}"
if [[ -f "$TEMPLATE_DIR/apps-kustomization.template.yaml" ]]; then
    envsubst < "$TEMPLATE_DIR/apps-kustomization.template.yaml" > "$OUTPUT_DIR/apps-kustomization.yaml"
    echo -e "${GREEN}✓ Generated: $OUTPUT_DIR/apps-kustomization.yaml${NC}"
else
    echo -e "${RED}✗ Template not found: $TEMPLATE_DIR/apps-kustomization.template.yaml${NC}"
fi

echo ""
echo -e "${GREEN}🎉 Flux resources generated successfully!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the generated files in $OUTPUT_DIR/"
echo "2. Apply them to your cluster:"
echo -e "   ${BLUE}kubectl apply -f $OUTPUT_DIR/repository-config.yaml${NC}"
echo -e "   ${BLUE}kubectl apply -f $OUTPUT_DIR/flux-system-source.yaml${NC}"
echo -e "   ${BLUE}kubectl apply -f $OUTPUT_DIR/flux-system-kustomization.yaml${NC}"
echo -e "   ${BLUE}kubectl apply -f $OUTPUT_DIR/apps-kustomization.yaml${NC}"
echo ""
echo -e "${YELLOW}To update configuration:${NC}"
echo "1. Edit $OUTPUT_DIR/repository-config.yaml"
echo "2. Apply the ConfigMap: kubectl apply -f $OUTPUT_DIR/repository-config.yaml"
echo "3. Regenerate resources: ./generate-flux-config.sh"
echo "4. Apply updated resources"