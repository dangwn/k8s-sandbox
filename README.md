# Flux CD for K8s Sandbox

Minimal Flux CD setup for automatic Kubernetes deployments from GitHub with configurable repository settings.

## Quick Start

```bash
# Deploy Flux with configurable repository settings
./deploy-flux.sh

# Add your apps to the apps/ directory
# Commit and push - they'll deploy automatically!
```

## How It Works

- Repository configuration stored in ConfigMap for easy updates
- Automatically deploys anything in the `apps/` directory
- Configurable sync intervals and paths

## Configuration

Repository settings are stored in `clusters/local/repository-config.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: repository-config
  namespace: flux-system
data:
  repository_url: "https://github.com/dangwn/k8s-sandbox.git"
  repository_branch: "main"
  sync_interval: "1m0s"
  apps_path: "./apps"
```

To change repository or sync settings:
1. Edit `clusters/local/repository-config.yaml`
2. Run `./generate-flux-config.sh` to update resources
3. Apply changes: `kubectl apply -f clusters/local/`

## Add Applications

1. Create YAML files in `apps/my-app/`
2. Commit and push to the configured branch
3. Flux deploys them automatically

## Commands

```bash
# Check status
kubectl -n flux-system get all

# View current configuration
kubectl -n flux-system get configmap repository-config -o yaml

# Update configuration from templates
./generate-flux-config.sh

# Force sync
kubectl -n flux-system annotate gitrepository/flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Remove Flux
./cleanup-flux.sh
```

## Configuration Management

The repository uses a ConfigMap-based approach for easy configuration:

- **Templates**: `clusters/local/*.template.yaml` files define resource structure
- **Configuration**: `clusters/local/repository-config.yaml` contains all settings
- **Generator**: `./generate-flux-config.sh` creates resources from templates + config
- **Deployment**: Resources are applied during `./deploy-flux.sh`

To modify repository settings:
1. Edit the ConfigMap values in `repository-config.yaml`
2. Run `./generate-flux-config.sh` to regenerate resources
3. Apply updated resources: `kubectl apply -f clusters/local/`

That's it!