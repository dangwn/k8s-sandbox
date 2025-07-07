#!/bin/bash

# FluxCD Validation Script (kubectl only)
# This script validates that FluxCD is properly configured and working

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLUX_NAMESPACE="flux-system"
TIMEOUT=300

echo -e "${BLUE}🔍 FluxCD Validation Script (kubectl only)${NC}"
echo "========================================"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "pass" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "fail" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "warn" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo -e "${BLUE}ℹ️  $message${NC}"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get condition status from resource
get_condition_status() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local condition_type=${4:-"Ready"}
    
    kubectl get $resource_type $resource_name -n $namespace -o jsonpath="{.status.conditions[?(@.type==\"$condition_type\")].status}" 2>/dev/null || echo "Unknown"
}

# Function to get condition message from resource
get_condition_message() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    local condition_type=${4:-"Ready"}
    
    kubectl get $resource_type $resource_name -n $namespace -o jsonpath="{.status.conditions[?(@.type==\"$condition_type\")].message}" 2>/dev/null || echo "No message available"
}

# Check prerequisites
echo -e "${BLUE}📋 Checking Prerequisites${NC}"
echo "----------------------------------------"

# Check kubectl
if command_exists kubectl; then
    print_status "pass" "kubectl is installed"
    
    # Check cluster connectivity
    if kubectl cluster-info >/dev/null 2>&1; then
        print_status "pass" "Kubernetes cluster is accessible"
        CLUSTER_VERSION=$(kubectl version --short 2>/dev/null | grep Server | awk '{print $3}' || echo "unknown")
        print_status "info" "Cluster version: $CLUSTER_VERSION"
        
        # Check version compatibility
        KUBE_MAJOR=$(echo $CLUSTER_VERSION | cut -d'.' -f1 | sed 's/v//' || echo "0")
        KUBE_MINOR=$(echo $CLUSTER_VERSION | cut -d'.' -f2 || echo "0")
        
        if [ "$KUBE_MAJOR" -gt 1 ] || ([ "$KUBE_MAJOR" -eq 1 ] && [ "$KUBE_MINOR" -ge 28 ]); then
            print_status "pass" "Kubernetes version is compatible (v1.28+)"
        else
            print_status "warn" "Kubernetes version may not be fully compatible (requires v1.28+)"
        fi
    else
        print_status "fail" "Cannot connect to Kubernetes cluster"
        exit 1
    fi
else
    print_status "fail" "kubectl is not installed"
    exit 1
fi

echo ""

# Check FluxCD Installation
echo -e "${BLUE}🏗️  Checking FluxCD Installation${NC}"
echo "----------------------------------------"

# Check namespace
if kubectl get namespace $FLUX_NAMESPACE >/dev/null 2>&1; then
    print_status "pass" "flux-system namespace exists"
else
    print_status "fail" "flux-system namespace not found"
    echo -e "${RED}FluxCD is not installed. Run './deploy-flux.sh' to install.${NC}"
    exit 1
fi

# Check FluxCD components
COMPONENTS=("source-controller" "kustomize-controller" "helm-controller" "notification-controller")
ALL_READY=true

for component in "${COMPONENTS[@]}"; do
    if kubectl get deployment $component -n $FLUX_NAMESPACE >/dev/null 2>&1; then
        READY=$(kubectl get deployment $component -n $FLUX_NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        DESIRED=$(kubectl get deployment $component -n $FLUX_NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [ "$READY" = "$DESIRED" ] && [ "$READY" != "0" ]; then
            print_status "pass" "$component is ready ($READY/$DESIRED)"
            
            # Check if pods are actually running
            RUNNING_PODS=$(kubectl get pods -n $FLUX_NAMESPACE -l app=$component --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
            if [ "$RUNNING_PODS" -gt 0 ]; then
                print_status "pass" "$component pods are running"
            else
                print_status "warn" "$component pods may not be running properly"
            fi
        else
            print_status "fail" "$component is not ready ($READY/$DESIRED)"
            ALL_READY=false
            
            # Show pod status for troubleshooting
            echo "  Pod status for $component:"
            kubectl get pods -n $FLUX_NAMESPACE -l app=$component --no-headers 2>/dev/null | while read -r line; do
                POD_NAME=$(echo $line | awk '{print $1}')
                POD_STATUS=$(echo $line | awk '{print $3}')
                echo "    - $POD_NAME: $POD_STATUS"
            done
        fi
    else
        print_status "fail" "$component deployment not found"
        ALL_READY=false
    fi
done

if [ "$ALL_READY" = "false" ]; then
    print_status "fail" "Some FluxCD components are not ready"
    echo -e "${YELLOW}Troubleshooting commands:${NC}"
    echo "  - Check pods: kubectl get pods -n $FLUX_NAMESPACE"
    echo "  - Check events: kubectl get events -n $FLUX_NAMESPACE --sort-by='.lastTimestamp'"
    echo "  - Check logs: kubectl logs -n $FLUX_NAMESPACE deployment/source-controller"
fi

echo ""

# Check Custom Resource Definitions
echo -e "${BLUE}📦 Checking FluxCD CRDs${NC}"
echo "----------------------------------------"

CRDS=("gitrepositories.source.toolkit.fluxcd.io" "kustomizations.kustomize.toolkit.fluxcd.io" "helmreleases.helm.toolkit.fluxcd.io" "helmrepositories.source.toolkit.fluxcd.io")
CRD_READY=true

for crd in "${CRDS[@]}"; do
    if kubectl get crd $crd >/dev/null 2>&1; then
        print_status "pass" "CRD $crd exists"
    else
        print_status "fail" "CRD $crd not found"
        CRD_READY=false
    fi
done

if [ "$CRD_READY" = "false" ]; then
    print_status "fail" "Some FluxCD CRDs are missing"
    echo -e "${YELLOW}This may indicate an incomplete installation${NC}"
fi

echo ""

# Check GitRepository
echo -e "${BLUE}📦 Checking GitRepository${NC}"
echo "----------------------------------------"

if kubectl get gitrepository flux-system -n $FLUX_NAMESPACE >/dev/null 2>&1; then
    print_status "pass" "GitRepository 'flux-system' exists"
    
    # Check GitRepository status
    GIT_READY=$(get_condition_status "gitrepository" "flux-system" "$FLUX_NAMESPACE")
    GIT_URL=$(kubectl get gitrepository flux-system -n $FLUX_NAMESPACE -o jsonpath='{.spec.url}' 2>/dev/null || echo "unknown")
    GIT_BRANCH=$(kubectl get gitrepository flux-system -n $FLUX_NAMESPACE -o jsonpath='{.spec.ref.branch}' 2>/dev/null || echo "unknown")
    GIT_INTERVAL=$(kubectl get gitrepository flux-system -n $FLUX_NAMESPACE -o jsonpath='{.spec.interval}' 2>/dev/null || echo "unknown")
    GIT_REVISION=$(kubectl get gitrepository flux-system -n $FLUX_NAMESPACE -o jsonpath='{.status.artifact.revision}' 2>/dev/null || echo "unknown")
    
    if [ "$GIT_READY" = "True" ]; then
        print_status "pass" "GitRepository is ready"
        print_status "info" "Repository URL: $GIT_URL"
        print_status "info" "Branch: $GIT_BRANCH"
        print_status "info" "Sync interval: $GIT_INTERVAL"
        print_status "info" "Current revision: $GIT_REVISION"
        
        # Check last sync time
        LAST_UPDATE=$(kubectl get gitrepository flux-system -n $FLUX_NAMESPACE -o jsonpath='{.status.artifact.lastUpdateTime}' 2>/dev/null || echo "unknown")
        if [ "$LAST_UPDATE" != "unknown" ]; then
            print_status "info" "Last sync: $LAST_UPDATE"
        fi
    else
        print_status "fail" "GitRepository is not ready"
        GIT_MESSAGE=$(get_condition_message "gitrepository" "flux-system" "$FLUX_NAMESPACE")
        print_status "fail" "Error: $GIT_MESSAGE"
        
        # Additional troubleshooting info
        echo -e "${YELLOW}GitRepository troubleshooting:${NC}"
        echo "  - Check if repository URL is accessible: $GIT_URL"
        echo "  - Verify branch exists: $GIT_BRANCH"
        echo "  - Check repository details: kubectl describe gitrepository flux-system -n $FLUX_NAMESPACE"
    fi
else
    print_status "fail" "GitRepository 'flux-system' not found"
    echo -e "${YELLOW}Run the deployment script to create the GitRepository${NC}"
fi

echo ""

# Check Kustomizations
echo -e "${BLUE}⚙️  Checking Kustomizations${NC}"
echo "----------------------------------------"

# Get all kustomizations in flux-system namespace
KUSTOMIZATIONS=$(kubectl get kustomization -n $FLUX_NAMESPACE --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "")

if [ -n "$KUSTOMIZATIONS" ]; then
    print_status "info" "Found Kustomizations:"
    
    while IFS= read -r kust_name; do
        if [ -n "$kust_name" ]; then
            KUST_READY=$(get_condition_status "kustomization" "$kust_name" "$FLUX_NAMESPACE")
            KUST_PATH=$(kubectl get kustomization $kust_name -n $FLUX_NAMESPACE -o jsonpath='{.spec.path}' 2>/dev/null || echo "unknown")
            KUST_INTERVAL=$(kubectl get kustomization $kust_name -n $FLUX_NAMESPACE -o jsonpath='{.spec.interval}' 2>/dev/null || echo "unknown")
            
            if [ "$KUST_READY" = "True" ]; then
                print_status "pass" "Kustomization '$kust_name' is ready"
                print_status "info" "  Path: $KUST_PATH"
                print_status "info" "  Interval: $KUST_INTERVAL"
            else
                print_status "fail" "Kustomization '$kust_name' is not ready"
                KUST_MESSAGE=$(get_condition_message "kustomization" "$kust_name" "$FLUX_NAMESPACE")
                print_status "fail" "  Error: $KUST_MESSAGE"
                print_status "info" "  Path: $KUST_PATH"
            fi
        fi
    done <<< "$KUSTOMIZATIONS"
else
    print_status "warn" "No Kustomizations found in flux-system namespace"
    echo -e "${YELLOW}This may be normal if no applications are configured yet${NC}"
fi

echo ""

# Check deployed applications
echo -e "${BLUE}🚀 Checking Deployed Applications${NC}"
echo "----------------------------------------"

# Check for sample nginx app if it exists
if kubectl get deployment sample-nginx >/dev/null 2>&1; then
    print_status "pass" "Sample nginx deployment found"
    
    NGINX_READY=$(kubectl get deployment sample-nginx -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    NGINX_DESIRED=$(kubectl get deployment sample-nginx -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    
    if [ "$NGINX_READY" = "$NGINX_DESIRED" ] && [ "$NGINX_READY" != "0" ]; then
        print_status "pass" "Sample nginx is ready ($NGINX_READY/$NGINX_DESIRED replicas)"
    else
        print_status "warn" "Sample nginx is not fully ready ($NGINX_READY/$NGINX_DESIRED replicas)"
    fi
    
    if kubectl get service sample-nginx >/dev/null 2>&1; then
        print_status "pass" "Sample nginx service found"
    else
        print_status "warn" "Sample nginx service not found"
    fi
else
    print_status "info" "Sample nginx deployment not found (this is normal if you haven't deployed it)"
fi

# List all deployments in default namespace
echo ""
print_status "info" "Deployments in default namespace:"
if kubectl get deployments --no-headers 2>/dev/null | grep -q .; then
    kubectl get deployments --no-headers 2>/dev/null | while read -r line; do
        NAME=$(echo $line | awk '{print $1}')
        READY=$(echo $line | awk '{print $2}')
        UP_TO_DATE=$(echo $line | awk '{print $3}')
        AVAILABLE=$(echo $line | awk '{print $4}')
        echo "  - $NAME: $READY ready, $UP_TO_DATE up-to-date, $AVAILABLE available"
    done
else
    echo "  No deployments found"
fi

# Check for HelmReleases
echo ""
if kubectl get helmrelease --all-namespaces --no-headers 2>/dev/null | grep -q .; then
    print_status "info" "HelmReleases found:"
    kubectl get helmrelease --all-namespaces --no-headers 2>/dev/null | while read -r line; do
        NAMESPACE=$(echo $line | awk '{print $1}')
        NAME=$(echo $line | awk '{print $2}')
        READY=$(echo $line | awk '{print $3}')
        STATUS=$(echo $line | awk '{print $4}')
        echo "  - $NAMESPACE/$NAME: $READY ($STATUS)"
    done
else
    print_status "info" "No HelmReleases found"
fi

echo ""

# Check FluxCD resource status summary
echo -e "${BLUE}📈 Resource Status Summary${NC}"
echo "----------------------------------------"

# GitRepositories
GIT_COUNT=$(kubectl get gitrepository --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
GIT_READY_COUNT=$(kubectl get gitrepository --all-namespaces -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")
print_status "info" "GitRepositories: $GIT_READY_COUNT/$GIT_COUNT ready"

# Kustomizations
KUST_COUNT=$(kubectl get kustomization --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
KUST_READY_COUNT=$(kubectl get kustomization --all-namespaces -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")
print_status "info" "Kustomizations: $KUST_READY_COUNT/$KUST_COUNT ready"

# HelmReleases
HELM_COUNT=$(kubectl get helmrelease --all-namespaces --no-headers 2>/dev/null | wc -l || echo "0")
HELM_READY_COUNT=$(kubectl get helmrelease --all-namespaces -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -c "True" || echo "0")
print_status "info" "HelmReleases: $HELM_READY_COUNT/$HELM_COUNT ready"

echo ""

# Summary
echo -e "${BLUE}📊 Validation Summary${NC}"
echo "========================================"

# Overall status check
OVERALL_STATUS="pass"
ISSUES=()

# Check critical components
if ! kubectl get namespace $FLUX_NAMESPACE >/dev/null 2>&1; then
    OVERALL_STATUS="fail"
    ISSUES+=("flux-system namespace missing")
fi

for component in "${COMPONENTS[@]}"; do
    if ! kubectl get deployment $component -n $FLUX_NAMESPACE >/dev/null 2>&1; then
        OVERALL_STATUS="fail"
        ISSUES+=("$component deployment missing")
        break
    fi
    
    READY=$(kubectl get deployment $component -n $FLUX_NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    DESIRED=$(kubectl get deployment $component -n $FLUX_NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
    
    if [ "$READY" != "$DESIRED" ] || [ "$READY" = "0" ]; then
        OVERALL_STATUS="fail"
        ISSUES+=("$component not ready ($READY/$DESIRED)")
        break
    fi
done

# Check GitRepository
if kubectl get gitrepository flux-system -n $FLUX_NAMESPACE >/dev/null 2>&1; then
    GIT_READY=$(get_condition_status "gitrepository" "flux-system" "$FLUX_NAMESPACE")
    if [ "$GIT_READY" != "True" ]; then
        OVERALL_STATUS="fail"
        ISSUES+=("GitRepository not ready")
    fi
else
    OVERALL_STATUS="fail"
    ISSUES+=("GitRepository missing")
fi

if [ "$OVERALL_STATUS" = "pass" ]; then
    print_status "pass" "FluxCD is properly installed and configured!"
    echo ""
    echo -e "${GREEN}🎉 Your GitOps setup is working correctly!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Add your Kubernetes manifests to the 'apps' directory"
    echo "2. Commit and push changes to trigger deployment"
    echo "3. Monitor deployments with the commands below"
else
    print_status "fail" "FluxCD setup has issues that need attention"
    echo ""
    echo -e "${RED}Issues found:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
    echo ""
    echo -e "${YELLOW}Troubleshooting commands:${NC}"
    echo "- Check pod status: kubectl get pods -n flux-system"
    echo "- Check events: kubectl get events -n flux-system --sort-by='.lastTimestamp'"
    echo "- Check component logs: kubectl logs -n flux-system deployment/source-controller"
    echo "- Re-run deployment: ./deploy-flux.sh"
fi

echo ""
echo -e "${BLUE}📖 Useful kubectl Commands:${NC}"
echo "========================================="
echo "# Check FluxCD status"
echo "kubectl get all -n flux-system"
echo ""
echo "# Check GitRepository status"
echo "kubectl get gitrepository -n flux-system"
echo "kubectl describe gitrepository flux-system -n flux-system"
echo ""
echo "# Check Kustomization status" 
echo "kubectl get kustomization -n flux-system"
echo "kubectl describe kustomization apps -n flux-system"
echo ""
echo "# Check deployed applications"
echo "kubectl get deployments,services"
echo "kubectl get helmrelease --all-namespaces"
echo ""
echo "# View logs"
echo "kubectl logs -n flux-system deployment/source-controller"
echo "kubectl logs -n flux-system deployment/kustomize-controller"
echo "kubectl logs -n flux-system deployment/helm-controller"
echo ""
echo "# Force reconciliation"
echo "kubectl annotate --overwrite gitrepository/flux-system -n flux-system reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\""
echo "kubectl annotate --overwrite kustomization/apps -n flux-system reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\""
echo ""
echo "# Check events for troubleshooting"
echo "kubectl get events -n flux-system --sort-by='.lastTimestamp'"
echo "kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i flux"

exit 0