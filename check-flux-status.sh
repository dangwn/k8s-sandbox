#!/bin/bash

# FluxCD Status and Log Checker
# This script helps monitor FluxCD deployment status and view logs

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_section() {
    echo -e "\n${CYAN}--- $1 ---${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster"
    exit 1
fi

print_header "FluxCD Status Check"

# Check if FluxCD namespace exists
print_section "Checking FluxCD Installation"
if kubectl get namespace flux-system &> /dev/null; then
    print_success "flux-system namespace exists"
else
    print_error "flux-system namespace not found - FluxCD not installed"
    exit 1
fi

# Check FluxCD controllers
print_section "FluxCD Controllers Status"
echo "Deployments in flux-system:"
kubectl get deployments -n flux-system -o wide 2>/dev/null || print_warning "No deployments found in flux-system"

echo -e "\nPods in flux-system:"
kubectl get pods -n flux-system -o wide 2>/dev/null || print_warning "No pods found in flux-system"

# Check Git repositories
print_section "Git Repository Sources"
if kubectl get gitrepositories -n flux-system &> /dev/null; then
    kubectl get gitrepositories -n flux-system -o custom-columns="NAME:.metadata.name,URL:.spec.url,READY:.status.conditions[?(@.type=='Ready')].status,STATUS:.status.conditions[?(@.type=='Ready')].message" 2>/dev/null || kubectl get gitrepositories -n flux-system
else
    print_warning "No GitRepository resources found"
fi

# Check Kustomizations
print_section "Kustomizations Status"
if kubectl get kustomizations -n flux-system &> /dev/null; then
    kubectl get kustomizations -n flux-system -o custom-columns="NAME:.metadata.name,READY:.status.conditions[?(@.type=='Ready')].status,STATUS:.status.conditions[?(@.type=='Ready')].message,AGE:.metadata.creationTimestamp" 2>/dev/null || kubectl get kustomizations -n flux-system
else
    print_warning "No Kustomization resources found"
fi

# Check healthy-app-demo specific resources
print_section "Healthy App Demo Status"
echo "Deployment status:"
kubectl get deployment healthy-app-demo -o wide 2>/dev/null || print_warning "healthy-app-demo deployment not found"

echo -e "\nPod status:"
kubectl get pods -l app=healthy-app-demo -o wide 2>/dev/null || print_warning "No healthy-app-demo pods found"

echo -e "\nService status:"
kubectl get service healthy-app-demo 2>/dev/null || print_warning "healthy-app-demo service not found"

# Check recent events
print_section "Recent Events"
echo "FluxCD namespace events (last 10):"
kubectl get events -n flux-system --sort-by='.metadata.creationTimestamp' --field-selector type!=Normal | tail -10 2>/dev/null || echo "No recent events"

echo -e "\nDefault namespace events (last 5):"
kubectl get events -n default --sort-by='.metadata.creationTimestamp' --field-selector involvedObject.name=healthy-app-demo | tail -5 2>/dev/null || echo "No healthy-app-demo events"

# Function to show logs
show_logs() {
    local component=$1
    local lines=${2:-20}
    
    print_section "$component Logs (last $lines lines)"
    
    case $component in
        "source")
            kubectl logs -n flux-system deployment/source-controller --tail=$lines 2>/dev/null || print_warning "Cannot get source-controller logs"
            ;;
        "kustomize")
            kubectl logs -n flux-system deployment/kustomize-controller --tail=$lines 2>/dev/null || print_warning "Cannot get kustomize-controller logs"
            ;;
        "all")
            echo "Source Controller:"
            kubectl logs -n flux-system deployment/source-controller --tail=$lines 2>/dev/null || print_warning "Cannot get source-controller logs"
            echo -e "\nKustomize Controller:"
            kubectl logs -n flux-system deployment/kustomize-controller --tail=$lines 2>/dev/null || print_warning "Cannot get kustomize-controller logs"
            ;;
    esac
}

# Main execution
case "${1:-status}" in
    "status")
        # Already shown above
        ;;
    "logs")
        show_logs "all" "${2:-20}"
        ;;
    "source-logs")
        show_logs "source" "${2:-20}"
        ;;
    "kustomize-logs")
        show_logs "kustomize" "${2:-20}"
        ;;
    "watch")
        print_section "Watching Kustomizations (Ctrl+C to stop)"
        kubectl get kustomizations -n flux-system -w
        ;;
    "force-sync")
        print_section "Forcing Git Repository Sync"
        kubectl annotate gitrepository flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite
        print_success "Sync requested - check logs in a few seconds"
        ;;
    "describe")
        resource=${2:-"healthy-app-demo"}
        print_section "Describing Kustomization: $resource"
        kubectl describe kustomization "$resource" -n flux-system
        ;;
    "help")
        print_header "FluxCD Status Checker Help"
        echo "Usage: $0 [command] [options]"
        echo ""
        echo "Commands:"
        echo "  status              - Show overall FluxCD status (default)"
        echo "  logs [lines]        - Show both controller logs (default: 20 lines)"
        echo "  source-logs [lines] - Show source-controller logs only"
        echo "  kustomize-logs [lines] - Show kustomize-controller logs only"
        echo "  watch               - Watch kustomizations in real-time"
        echo "  force-sync          - Force git repository sync"
        echo "  describe [name]     - Describe a kustomization (default: healthy-app-demo)"
        echo "  help                - Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0                  # Show status"
        echo "  $0 logs 50          # Show last 50 log lines"
        echo "  $0 force-sync       # Force sync and check logs"
        echo "  $0 describe flux-system"
        ;;
    *)
        print_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac

print_section "Quick Commands"
echo "Monitor logs in real-time:"
echo "  kubectl logs -n flux-system deployment/source-controller -f"
echo "  kubectl logs -n flux-system deployment/kustomize-controller -f"
echo ""
echo "Force reconciliation:"
echo "  kubectl annotate gitrepository flux-system -n flux-system reconcile.fluxcd.io/requestedAt=\"\$(date +%s)\" --overwrite"
echo ""
echo "Check specific resource:"
echo "  kubectl describe kustomization healthy-app-demo -n flux-system"