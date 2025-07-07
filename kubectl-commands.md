# FluxCD kubectl Commands Reference

This is a quick reference for managing FluxCD with kubectl only (no flux CLI required).

## 🚀 Installation Commands

```bash
# Install FluxCD components
kubectl apply -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml

# Verify installation
kubectl get pods -n flux-system
kubectl get crd | grep fluxcd
```

## 📊 Status Check Commands

```bash
# Check all FluxCD resources
kubectl get all -n flux-system

# Check GitRepository status
kubectl get gitrepository -n flux-system
kubectl get gitrepository -n flux-system -o wide

# Check Kustomization status
kubectl get kustomization -n flux-system
kubectl get kustomization -n flux-system -o wide

# Check HelmReleases (if using Helm)
kubectl get helmrelease --all-namespaces
```

## 🔍 Detailed Status Commands

```bash
# GitRepository details
kubectl describe gitrepository flux-system -n flux-system

# Kustomization details
kubectl describe kustomization apps -n flux-system

# Component deployment status
kubectl get deployment -n flux-system
kubectl describe deployment source-controller -n flux-system
```

## 📝 Logs and Events

```bash
# View component logs
kubectl logs -n flux-system deployment/source-controller
kubectl logs -n flux-system deployment/kustomize-controller
kubectl logs -n flux-system deployment/helm-controller
kubectl logs -n flux-system deployment/notification-controller

# Follow logs in real-time
kubectl logs -n flux-system deployment/source-controller -f

# Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i flux
```

## 🔄 Force Reconciliation

```bash
# Force GitRepository sync
kubectl annotate --overwrite gitrepository/flux-system -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"

# Force Kustomization sync
kubectl annotate --overwrite kustomization/apps -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"

# Force all Kustomizations sync
kubectl get kustomization -n flux-system -o name | \
  xargs -I {} kubectl annotate --overwrite {} -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"

# Force HelmRelease sync
kubectl annotate --overwrite helmrelease/my-release -n default \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"
```

## 📦 Resource Management

```bash
# Create GitRepository
kubectl apply -f - <<EOF
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: my-repo
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: main
  url: https://github.com/user/repo
EOF

# Create Kustomization
kubectl apply -f - <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: my-app
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: my-repo
  path: "./apps"
  prune: true
EOF
```

## 🛠 Troubleshooting Commands

```bash
# Check component health
kubectl get deployment -n flux-system
kubectl get pods -n flux-system

# Check resource conditions
kubectl get gitrepository -n flux-system -o json | \
  jq '.items[].status.conditions[]'

kubectl get kustomization -n flux-system -o json | \
  jq '.items[].status.conditions[]'

# Check for failed reconciliations
kubectl get kustomization -n flux-system -o json | \
  jq '.items[] | select(.status.conditions[]?.status == "False")'

# Restart FluxCD components
kubectl rollout restart deployment/source-controller -n flux-system
kubectl rollout restart deployment/kustomize-controller -n flux-system
kubectl rollout restart deployment/helm-controller -n flux-system
```

## 🔐 Secret Management (for private repos)

```bash
# Create SSH key secret
kubectl create secret generic flux-system \
  --from-file=identity=./id_rsa \
  --from-file=identity.pub=./id_rsa.pub \
  --from-file=known_hosts=./known_hosts \
  -n flux-system

# Create token secret
kubectl create secret generic flux-system \
  --from-literal=username=git \
  --from-literal=password=<token> \
  -n flux-system
```

## 📈 Monitoring Commands

```bash
# Watch GitRepository status
watch kubectl get gitrepository -n flux-system

# Watch Kustomization status
watch kubectl get kustomization -n flux-system

# Watch all FluxCD resources
watch kubectl get gitrepository,kustomization,helmrelease --all-namespaces

# Check resource usage
kubectl top pods -n flux-system
```

## 🧹 Cleanup Commands

```bash
# Remove specific Kustomization
kubectl delete kustomization apps -n flux-system

# Remove GitRepository
kubectl delete gitrepository flux-system -n flux-system

# Uninstall FluxCD (careful!)
kubectl delete -f https://github.com/fluxcd/flux2/releases/latest/download/install.yaml
```

## 📋 One-liner Status Summary

```bash
# Quick status check
echo "=== FluxCD Status ===" && \
kubectl get pods -n flux-system --no-headers | awk '{print $1 ": " $3}' && \
echo "=== GitRepositories ===" && \
kubectl get gitrepository -n flux-system --no-headers | awk '{print $1 ": " $2}' && \
echo "=== Kustomizations ===" && \
kubectl get kustomization -n flux-system --no-headers | awk '{print $1 ": " $2}'
```

## 🎯 Common Workflows

### Deploy New Application
```bash
# 1. Add manifests to your repo's apps/ directory
# 2. Commit and push
git add apps/my-new-app/
git commit -m "Add new app"
git push

# 3. Force sync if needed
kubectl annotate --overwrite gitrepository/flux-system -n flux-system \
  reconcile.fluxcd.io/requestedAt="$(date +%s)"

# 4. Check status
kubectl get kustomization apps -n flux-system
```

### Debug Failed Deployment
```bash
# 1. Check Kustomization status
kubectl describe kustomization apps -n flux-system

# 2. Check logs
kubectl logs -n flux-system deployment/kustomize-controller

# 3. Check events
kubectl get events -n flux-system --sort-by='.lastTimestamp'

# 4. Validate manifests manually
kubectl apply --dry-run=client -f apps/my-app/
```

---

💡 **Tip**: Bookmark this file and use it as your go-to reference for FluxCD operations!