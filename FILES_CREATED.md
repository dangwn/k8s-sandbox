# FluxCD GitOps Setup - Generated Files (kubectl only)

This document lists all the files that have been generated for your FluxCD GitOps setup using kubectl only (no flux CLI required).

## Directory Structure

```
k8s-sandbox/
├── apps/                           # Applications to be deployed
│   ├── sample-nginx/              # Sample nginx application
│   │   ├── deployment.yaml        # Nginx deployment manifest
│   │   ├── service.yaml           # Nginx service manifest
│   │   └── kustomization.yaml     # Kustomize configuration
│   └── redis-example/             # Sample Helm deployment
│       ├── helm-repository.yaml   # Bitnami Helm repository
│       └── helm-release.yaml      # Redis Helm release
├── clusters/                      # Cluster-specific configurations
│   └── production/
│       ├── apps.yaml              # Kustomization for apps directory
│       └── kustomization.yaml     # Cluster kustomization config
├── flux-system/                   # FluxCD system configuration
│   ├── gotk-components.yaml       # FluxCD components reference
│   └── gotk-sync.yaml            # GitRepository and sync config
├── deploy-flux.sh                 # Automated deployment script (kubectl only)
├── validate-flux.sh               # Validation and health check script (kubectl only)
├── kubectl-commands.md            # kubectl commands reference card
├── README.md                      # Comprehensive documentation
└── FILES_CREATED.md              # This file
```

## File Descriptions

### Core FluxCD Configuration

- **`flux-system/gotk-sync.yaml`**: Defines the GitRepository resource that tells FluxCD to monitor this repository and the main Kustomization resource that handles the cluster configuration.

- **`flux-system/gotk-components.yaml`**: Reference file for FluxCD component installation. Contains instructions to use official installation methods.

- **`clusters/production/apps.yaml`**: Kustomization resource that tells FluxCD to deploy everything from the `./apps` directory.

- **`clusters/production/kustomization.yaml`**: Main cluster configuration that references the flux-system components and apps configuration.

### Sample Applications

- **`apps/sample-nginx/`**: Complete example of a simple nginx deployment including:
  - `deployment.yaml`: Kubernetes Deployment with resource limits and health checks
  - `service.yaml`: Kubernetes Service to expose the nginx pods
  - `kustomization.yaml`: Kustomize configuration with common labels and annotations

- **`apps/redis-example/`**: Example of deploying applications using Helm charts:
  - `helm-repository.yaml`: Defines the Bitnami Helm repository
  - `helm-release.yaml`: Redis deployment using Helm with custom values

### Automation Scripts

- **`deploy-flux.sh`**: Fully automated deployment script that:
  - Checks prerequisites (kubectl only, no flux CLI needed)
  - Downloads and installs FluxCD components using kubectl
  - Creates GitRepository and Kustomization resources
  - Validates the setup
  - Provides next steps and useful kubectl commands

- **`validate-flux.sh`**: Comprehensive validation script that:
  - Checks FluxCD installation and component health using kubectl
  - Validates GitRepository synchronization
  - Checks Kustomization status
  - Lists deployed applications
  - Provides troubleshooting information with kubectl commands

### Documentation

- **`README.md`**: Complete setup and usage guide including:
  - Quick start instructions (kubectl only)
  - Manual deployment steps
  - Application deployment examples
  - Kustomize and Helm integration
  - Monitoring and troubleshooting with kubectl
  - Security considerations

- **`kubectl-commands.md`**: Quick reference for kubectl commands including:
  - Installation and status checks
  - Logging and debugging
  - Force reconciliation
  - Resource management
  - Troubleshooting workflows

## Usage Flow

1. **Deploy FluxCD**: Run `./deploy-flux.sh` to set up FluxCD (kubectl only)
2. **Validate Setup**: Run `./validate-flux.sh` to ensure everything is working
3. **Deploy Apps**: Add your manifests to the `apps/` directory
4. **Monitor**: Use `kubectl get kustomization -n flux-system` or refer to `kubectl-commands.md`

## Key Features

- **kubectl Only**: No flux CLI dependency - uses only kubectl commands
- **GitOps Workflow**: Automatic deployment from Git repository
- **Multi-Environment Ready**: Easy to extend for staging/production
- **Helm Support**: Examples for both native K8s manifests and Helm charts
- **Kustomize Integration**: Built-in support for Kustomize overlays
- **Monitoring**: Health checks and validation tools using kubectl
- **Security**: Best practices and security considerations
- **Documentation**: Comprehensive guides, examples, and kubectl reference

## Repository Configuration

- **Source Repository**: `https://github.com/dangwn/k8s-sandbox`
- **Branch**: `main`
- **Monitored Directory**: `./apps`
- **Sync Interval**: 1 minute (configurable)
- **Namespace**: `flux-system`

All files are ready to use and follow FluxCD best practices. The setup provides a complete GitOps workflow for continuous deployment to your Kubernetes cluster using only kubectl commands - no flux CLI required!