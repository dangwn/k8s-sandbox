# FluxCD GitOps Setup for k8s-sandbox (kubectl only)

This repository contains the configuration for deploying FluxCD to continuously deploy applications from the `apps` directory to your Kubernetes cluster using only kubectl (no flux CLI required).

## Overview

FluxCD will monitor the `apps` directory in the `main` branch of this repository and automatically deploy any Kubernetes manifests it finds to your cluster. This enables a GitOps workflow where you can manage your deployments through Git commits.

## Repository Structure

```
k8s-sandbox/
├── apps/                    # Your application manifests go here
├── clusters/
│   └── production/
│       ├── apps.yaml       # Kustomization for apps directory
│       └── kustomization.yaml
├── flux-system/
│   ├── gotk-components.yaml # FluxCD component reference
│   └── gotk-sync.yaml      # GitRepository and sync configuration
├── deploy-flux.sh          # Automated deployment script
└── README.md              # This file
```

## Quick Start

### Prerequisites

- Kubernetes cluster (v1.28 or newer)
- `kubectl` configured to access your cluster
- No flux CLI required - everything uses kubectl only!

### Option 1: Automated Deployment (Recommended)

Simply run the deployment script:

```bash
./deploy-flux.sh
```

This script will:
1. Check prerequisites (kubectl and cluster access)
2. Download and install FluxCD components using kubectl
3. Configure GitRepository to watch this repo
4. Set up Kustomization to deploy from the `apps` directory
5. Validate the setup

### Option 2: Manual Deployment

If you prefer to deploy manually or want to understand the process:

1. **Install FluxCD:**
   ```bash
   # Using kubectl to install latest FluxCD components
   kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
   ```

2. **Create GitRepository resource:**
   ```bash
   kubectl apply -f - <<EOF
   apiVersion: source.toolkit.fluxcd.io/v1
   kind: GitRepository
   metadata:
     name: flux-system
     namespace: flux-system
   spec:
     interval: 1m0s
     ref:
       branch: main
     url: https://github.com/dangwn/k8s-sandbox
   EOF
   ```

3. **Create Kustomization for apps:**
   ```bash
   kubectl apply -f - <<EOF
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
   ```

## Using FluxCD

### Deploying Applications

1. Create your Kubernetes manifests in the `apps` directory:
   ```bash
   mkdir -p apps/my-app
   ```

2. Add your manifests:
   ```yaml
   # apps/my-app/deployment.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-app
     namespace: default
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: my-app
     template:
       metadata:
         labels:
           app: my-app
       spec:
         containers:
         - name: my-app
           image: nginx:latest
           ports:
           - containerPort: 80
   ```

3. Commit and push:
   ```bash
   git add apps/
   git commit -m "Add my-app deployment"
   git push origin main
   ```

4. FluxCD will automatically detect the changes and deploy your application within ~1 minute.

### Organizing Applications

You can organize your applications in subdirectories:

```
apps/
├── web-apps/
│   ├── frontend/
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── backend/
│       ├── deployment.yaml
│       └── service.yaml
├── databases/
│   └── postgres/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── configmap.yaml
└── monitoring/
    └── prometheus/
        └── helm-release.yaml
```

### Using Kustomize

FluxCD supports Kustomize out of the box. You can create `kustomization.yaml` files in your app directories:

```yaml
# apps/my-app/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: my-app
  version: v1.0.0
```

### Using Helm Charts

You can also deploy Helm charts using HelmRepository and HelmRelease resources:

```yaml
# apps/my-helm-app/helm-repository.yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: bitnami
  namespace: default
spec:
  interval: 1h
  url: https://charts.bitnami.com/bitnami
---
# apps/my-helm-app/helm-release.yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: redis
  namespace: default
spec:
  interval: 5m
  chart:
    spec:
      chart: redis
      version: "17.x"
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: default
  values:
    auth:
      enabled: false
```

## Monitoring and Troubleshooting

### Useful Commands

Check FluxCD status:
```bash
kubectl get all -n flux-system
```

Check GitRepository status:
```bash
kubectl get gitrepository -n flux-system
kubectl describe gitrepository flux-system -n flux-system
```

Check Kustomization status:
```bash
kubectl get kustomization -n flux-system
kubectl describe kustomization apps -n flux-system
```

View FluxCD logs:
```bash
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
kubectl logs -n flux-system deployment/helm-controller
```

Force reconciliation:
```bash
kubectl annotate --overwrite gitrepository/flux-system -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
kubectl annotate --overwrite kustomization/apps -n flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

### Common Issues

1. **Repository not syncing:**
   - Check if the repository URL is accessible
   - Verify the branch name is correct
   - Check GitRepository resource status: `kubectl describe gitrepository flux-system -n flux-system`

2. **Applications not deploying:**
   - Check Kustomization status: `kubectl describe kustomization apps -n flux-system`
   - Check events: `kubectl get events -n flux-system --sort-by='.lastTimestamp'`
   - Verify your manifests are valid YAML
   - Check for namespace issues

3. **Authentication issues (for private repos):**
   - You'll need to create a secret with SSH key or personal access token
   - See [Flux documentation](https://fluxcd.io/flux/components/source/gitrepositories/#ssh-authentication) for details

## Configuration

### Changing Sync Interval

To change how often FluxCD checks for changes, modify the `interval` field in the GitRepository and Kustomization resources:

```yaml
spec:
  interval: 5m0s  # Check every 5 minutes instead of 1 minute
```

### Adding Multiple Directories

To watch additional directories, create more Kustomization resources:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./infrastructure
  prune: true
```

## Security Considerations

- This setup uses public repository access. For private repositories, configure authentication
- Consider using RBAC to limit FluxCD's permissions
- Review deployed manifests before pushing to main branch
- Use branch protection rules and pull request reviews

## Resources

- [FluxCD Documentation](https://fluxcd.io/flux/)
- [Kustomize Documentation](https://kustomize.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [FluxCD Helm Guide](https://fluxcd.io/flux/guides/helmreleases/)

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review FluxCD logs: `kubectl logs -n flux-system deployment/source-controller`
3. Check Kubernetes events: `kubectl get events -n flux-system --sort-by='.lastTimestamp'`
4. Run the validation script: `./validate-flux.sh`
5. Consult the [FluxCD documentation](https://fluxcd.io/flux/)