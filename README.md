# Python Bootstrap Infra

Repositório de configuração GitOps para a aplicação **Python Bootstrap**.

## Estrutura

- **Chart.yaml**: Declaração de dependências (k8s-helm-templates)
- **values-dev.yaml**: Valores customizados para ambiente de desenvolvimento
- **values-prod.yaml**: Valores customizados para ambiente de produção
- **application.yaml**: ArgoCD Application para sincronização contínua (dev)
- **application-prod.yaml**: ArgoCD Application para produção

## Setup

### 1. Atualizar dependências Helm

```bash
helm dependency update
```

### 2. Testar template localmente (dev)

```bash
helm template . -f values-dev.yaml
```

### 3. Testar template para produção

```bash
helm template . -f values-prod.yaml
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

