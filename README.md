# Python Bootstrap Infrastructure

## Overview

This repository contains the GitOps configuration for deploying the Python Bootstrap application to Kubernetes using Helm.

## Repository Structure

```
.
├── Chart.yaml                 # Helm chart metadata
├── values-dev.yaml           # Development environment configuration
├── values-prod.yaml          # Production environment configuration
├── application.yaml          # ArgoCD Application (dev)
├── application-prod.yaml     # ArgoCD Application (prod)
├── validate-and-sync.sh      # Local validation script
└── .github/
    └── workflows/
        ├── helm-test.yml     # Validates Helm configuration
        ├── dependabot-auto-merge.yml
        └── manual-image-update.yml
```

## Environment Configurations

### Development (`values-dev.yaml`)
- **Replicas**: 2 (minimal HA)
- **Image Pull Policy**: `Always` (get latest)
- **Autoscaling**: Enabled (2-5 replicas)
- **Log Level**: INFO
- **Health Check Probes**: `/health` endpoint

### Production (`values-prod.yaml`)
- **Replicas**: 3 (true HA)
- **Image Pull Policy**: `IfNotPresent` (use cached)
- **Autoscaling**: Enabled (3-10 replicas)
- **Pod Disruption Budget**: 2 minimum available
- **Log Level**: WARN
- **Affinity**: Pod anti-affinity for node distribution

## Key Features

### 1. **Health Checks**
The application exposes health endpoints:
- `GET /health` - Combined liveness + readiness
- `GET /health/live` - Liveness probe only
- `GET /health/ready` - Readiness probe only

Configure in Helm values:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
readinessProbe:
  httpGet:
    path: /health
    port: 8080
```

### 2. **Security**
- **Network Policies**: Enabled (restricts traffic)
- **Pod Security Context**: Non-root user (UID 1000)
- **Container Security**: No privilege escalation, dropped capabilities

### 3. **High Availability**
- **Pod Disruption Budget**: Ensures minimum availability during node maintenance
- **Pod Anti-Affinity**: Spreads pods across nodes
- **Horizontal Pod Autoscaler**: Scales based on CPU/memory

### 4. **Image Updates**
Images are automatically updated by the `python-bootstrap` CI/CD pipeline:
- When a commit is pushed to `python-bootstrap/main`
- Tests pass and Docker image is built
- This workflow updates the `tag` in `values-dev.yaml`

## Validating Configuration

### Quick Validation (Local)
```bash
# Make script executable
chmod +x validate-and-sync.sh

# Validate dev environment
./validate-and-sync.sh dev

# Validate prod environment
./validate-and-sync.sh prod
```

### Manual Validation
```bash
# Install dependencies
helm dependency update

# Lint the chart
helm lint . --strict

# Template and validate YAML
helm template python-bootstrap . -f values-dev.yaml | kubectl apply --dry-run=client -f -

# Full validation with debug output
helm template python-bootstrap . -f values-dev.yaml --debug
```

### Development Deployment
```bash
# Install to local cluster
helm install python-bootstrap . \
  --namespace default \
  -f values-dev.yaml \
  --wait

# Verify
kubectl get pods
kubectl logs -l app.kubernetes.io/name=python-bootstrap
```

### Dry-run Production Deployment
```bash
# See what would be deployed
helm template python-bootstrap . -f values-prod.yaml | kubectl apply --dry-run=client -f -
```

## CI/CD Integration

### GitHub Actions Workflows

#### `helm-test.yml` - Runs on PR and Push
- Lints chart
- Validates YAML syntax
- Tests with both dev and prod values
- Creates test Kubernetes cluster and deploys
- Verifies probes and resources

#### `manual-image-update.yml` - Manual Image Update
Trigger from GitHub Actions tab to manually update image tag:
1. Select environment (dev/prod)
2. Provide image tag (v1.2.3 or commit SHA)
3. Automatically creates PR or updates values file

#### Automatic Image Updates
When `python-bootstrap` builds and pushes a new image:
1. Tag is captured (e.g., `v1.2.3` or commit SHA)
2. `values-dev.yaml` is automatically updated
3. A commit is pushed with the new tag

Example:
```yaml
# Before
k8s-helm-templates:
  image:
    tag: ""

# After CI/CD updates
k8s-helm-templates:
  image:
    tag: "abc123def456"  # Commit SHA or version tag
```

## Updating Chart Versions

### When to Update Chart Version
- **Patch** (`0.0.X`): Changes to Helm templates, values structure, or docs
- **Minor** (`0.X.0`): New features in Helm (e.g., new probes, new templates)
- **Major** (`X.0.0`): Breaking changes

### How to Update
1. Update `Chart.yaml`:
```yaml
version: 0.1.0  # Increment appropriately
appVersion: "1.0.0"  # Application version from python-bootstrap
```

2. Update `k8s-helm-templates` dependency if needed:
```yaml
dependencies:
  - name: k8s-helm-templates
    version: "0.1.0"  # Update to latest from upstream
    repository: "https://rg-hermann.github.io/k8s-helm-templates/"
```

3. Commit and push:
```bash
git add Chart.yaml
git commit -m "chore(helm): bump chart to 0.1.0"
git push origin main
```

## Troubleshooting

### Pod not starting
```bash
# Check events
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Check probes
kubectl get pod <pod-name> -o jsonpath='{.status.conditions[*]}'
```

### Image pull errors
```bash
# Verify image exists
docker pull ghcr.io/rg-hermann/python-bootstrap:<tag>

# Check pull policy
yq '.k8s-helm-templates.image.pullPolicy' values-dev.yaml
```

### Health checks failing
```bash
# Port-forward to test locally
kubectl port-forward svc/python-bootstrap 8080:80

# Test endpoint
curl http://localhost:8080/health
```

### Helm template validation errors
```bash
# Check if k8s-helm-templates chart is available
helm search repo k8s-templates

# Update repositories
helm repo update

# Update dependencies
helm dependency update
```

## References

- [Helm Docs](https://helm.sh/docs/)
- [k8s-helm-templates](https://github.com/rg-hermann/k8s-helm-templates/)
- [Python Bootstrap App](https://github.com/rg-hermann/python-bootstrap/)

## Contributing

1. Make changes to `values-*.yaml` or add templates
2. Validate locally: `./validate-and-sync.sh dev`
3. Open a PR - GitHub Actions will validate
4. After merge, changes will be auto-deployed to dev environment (if using ArgoCD)

## Maintenance

### Regular Tasks
- [ ] Review Dependabot PRs and auto-merge minor/patch updates
- [ ] Test new chart versions before promoting to prod
- [ ] Monitor pod health and adjust resources as needed
- [ ] Review and update health probe configurations quarterly

```

### 4. Aplicar configuração com Kubectl (alternativo)

```bash
helm template . -f values-dev.yaml | kubectl apply -f -
```

### 5. ArgoCD (recomendado)

```bash
# Deploy em desenvolvimento
kubectl apply -f application.yaml

# Deploy em produção
kubectl apply -f application-prod.yaml
```

## Verificar Deploy

```bash
# Verificar aplicações
kubectl get app -n argocd

# Logs do pod
kubectl logs -f deployment/python-bootstrap-dev-k8s-helm-templates -n dev-apps

# Health checks
curl http://python-bootstrap.local/actuator/health/liveness
curl http://python-bootstrap.local/actuator/health/readiness
```

## Configurações por Ambiente

### Desenvolvimento
- **Replicas**: 1
- **Namespace**: dev-apps
- **Host**: python-bootstrap.local
- **Pull Policy**: Always
- **Resources**: 100m CPU, 128Mi RAM (requests)

### Produção
- **Replicas**: 3
- **Namespace**: prod-apps
- **Host**: python-bootstrap.prod.local
- **Pull Policy**: IfNotPresent
- **Resources**: 250m CPU, 256Mi RAM (requests)
- **TLS**: Enabled
- **Probes**: Mais conservadores (timeouts maiores)

## Customizações

Para alterar valores em qualquer ambiente, edite `values-dev.yaml` ou `values-prod.yaml` e faça commit. ArgoCD sincronizará automaticamente.

## Fluxo de Atualização

1. **Novo push** no `python-bootstrap` (código)
2. **GitHub Actions** faz build e push da imagem para GHCR
3. **GitHub Actions** atualiza a tag da imagem aqui (`values-dev.yaml`)
4. **ArgoCD** detecta mudança e sincroniza
5. **Kubernetes** faz rolling update dos pods

## Links Úteis

- [python-bootstrap (app code)](https://github.com/rg-hermann/python-bootstrap)
- [k8s-helm-templates (template)](https://github.com/rg-hermann/k8s-helm-templates)
- [ArgoCD](http://argocd.local)

