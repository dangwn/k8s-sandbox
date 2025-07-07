# Flux CD for K8s Sandbox

Minimal Flux CD setup for automatic Kubernetes deployments from GitHub.

## Quick Start

```bash
# Deploy Flux
./deploy-flux.sh

# Add your apps to the apps/ directory
# Commit and push - they'll deploy automatically!
```

## How It Works

- Monitors `https://github.com/dangwn/k8s-sandbox.git`
- Automatically deploys anything in the `apps/` directory
- Syncs every 1 minute

## Add Applications

1. Create YAML files in `apps/my-app/`
2. Commit and push to `master` branch
3. Flux deploys them automatically

## Commands

```bash
# Check status
kubectl -n flux-system get all

# Force sync
kubectl -n flux-system annotate gitrepository/flux-system reconcile.fluxcd.io/requestedAt="$(date +%s)" --overwrite

# Remove Flux
./cleanup-flux.sh
```

That's it!