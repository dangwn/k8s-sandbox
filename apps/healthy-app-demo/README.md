# Healthy App Demo with FluxCD Health Checks and Rollback

This demo showcases FluxCD's health check capabilities with a deployment that becomes healthy within 10 seconds and automatic rollback if health checks fail within 30 seconds.

## Components

### Deployment (`deployment.yaml`)
- **Image**: `nginx:1.21-alpine`
- **Replicas**: 2
- **Health Checks**:
  - Startup probe: Initial delay 2s, check every 2s, fail after 5 attempts
  - Readiness probe: Initial delay 5s, check every 2s
  - Liveness probe: Initial delay 15s, check every 10s
- **Expected behavior**: Becomes healthy within 10 seconds

### FluxCD Kustomization (`../../clusters/local/healthy-app-kustomization.yaml`)
- **Health Check Timeout**: 30 seconds
- **Monitored Resources**: healthy-app-demo deployment
- **Behavior**: 
  - Waits for deployment to become healthy
  - Rolls back if health checks fail within 30 seconds
  - Retries every 5 seconds

## Testing

### Deploy:
```bash
kubectl apply -f ../../clusters/local/healthy-app-kustomization.yaml
```

### Monitor:
```bash
# Check kustomization status
flux get kustomizations healthy-app-demo

# Check pod status
kubectl get pods -l app=healthy-app-demo
```

### Expected Behavior:
- Pods should become ready within 10 seconds
- FluxCD should report the kustomization as successful

## Health Check Configuration

```yaml
healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: healthy-app-demo
    namespace: default
timeout: 30s
wait: true
retryInterval: 5s
```

## Cleanup

```bash
kubectl delete kustomization healthy-app-demo -n flux-system
kubectl delete deployment healthy-app-demo
kubectl delete service healthy-app-demo
```
