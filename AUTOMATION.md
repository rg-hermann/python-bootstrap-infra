# 🚀 GitOps Automation Pipeline

## Fluxo Completamente Automático

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DESENVOLVIMENTO LOCAL                                │
└─────────────────────────────────────────────────────────────────────────────┘

1. Developer faz commit e push em k8s-helm-templates/main
   ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions: Release Charts                            │
│                 (k8s-helm-templates/.github/workflows/release.yaml)         │
│                                                                              │
│  ✓ Detecta nova versão no Chart.yaml                                        │
│  ✓ Publica automaticamente no Helm Chart Repository (gh-pages)              │
│  ✓ Cria release automática no GitHub                                        │
└─────────────────────────────────────────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Dependabot (Semanal)                               │
│           (python-bootstrap-infra/.github/dependabot.yml)                   │
│           (java-bootstrap-infra/.github/dependabot.yml)                     │
│                                                                              │
│  ✓ Verifica novas versões do k8s-helm-templates                             │
│  ✓ Cria PR automaticamente se houver atualização                            │
│  ✓ Atualiza Chart.yaml com a nova versão                                    │
└─────────────────────────────────────────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                    GitHub Actions: Auto Merge PR                             │
│         (python-bootstrap-infra/.github/workflows/dependabot-auto-merge.yml)│
│         (java-bootstrap-infra/.github/workflows/dependabot-auto-merge.yml) │
│                                                                              │
│  ✓ Aprova PR do Dependabot automaticamente                                   │
│  ✓ Ativa auto-merge (merge automático quando checks passam)                 │
│  ✓ Chart.yaml atualizado automaticamente em main                            │
└─────────────────────────────────────────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ArgoCD (Contínuo)                                    │
│           (python-bootstrap-infra/application.yaml com automated: true)     │
│           (java-bootstrap-infra/application.yaml com automated: true)       │
│                                                                              │
│  ✓ Monitora repositório infra continuamente                                 │
│  ✓ Detecta mudanças em Chart.yaml automaticamente                           │
│  ✓ Sincroniza Kubernetes automaticamente                                    │
│  ✓ Executa 'helm dependency update' internamente                            │
│  ✓ Aplica novo template no cluster                                          │
│  ✓ Faz prune + selfHeal para consistência                                   │
└─────────────────────────────────────────────────────────────────────────────┘
   ↓
┌─────────────────────────────────────────────────────────────────────────────┐
│                      KUBERNETES (dev-apps)                                   │
│                                                                              │
│  ✓ Nova versão da aplicação rodando com novo template!                      │
│  ✓ Service porta 80 → Container 8080 (mapeamento correto)                   │
│  ✓ Health checks funcionando (/health para Python, /actuator/* para Java)   │
│  ✓ Ingress funcional (python-bootstrap.local, java-bootstrap.local)         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Componentes Automáticos

### 1️⃣ **k8s-helm-templates** (Release Automation)
```yaml
# .github/workflows/release.yaml
- Acionado: Push em main
- Ação: helm/chart-releaser-action
- Resultado: Publica no Helm Chart Repository automaticamente
```

### 2️⃣ **python-bootstrap-infra** e **java-bootstrap-infra** (Dependency Updates)
```yaml
# .github/dependabot.yml
- Escopo: Monitorar Helm dependencies
- Frequência: Semanal
- PR: Automático se houver nova versão

# .github/workflows/dependabot-auto-merge.yml
- Acionado: PR aberto
- Ação: Aprova + Auto-merge se for Dependabot
- Resultado: Merge automático quando checks passam
```

### 3️⃣ **ArgoCD Applications**
```yaml
# application.yaml (ambos os infra repos)
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
```

## Tempo de Propagação

| Etapa | Tempo | Automático? |
|-------|-------|------------|
| Push k8s-helm-templates → Helm Repo | ~1 min | ✅ |
| Dependabot detecta nova versão | ~1 min | ✅ |
| PR criado + Auto-merge | ~2 min | ✅ |
| ArgoCD sincroniza | ~5 min | ✅ |
| **Total (da mudança ao K8s)** | **~10 min** | **✅ 100%** |

## O que você precisa fazer

### Apenas 3 coisas manuais:

1. **Uma única vez**: Confirmar que Helm Chart Repository está publicado
   ```bash
   # Verificar se está em: https://rg-hermann.github.io/k8s-helm-templates/
   helm repo add rg-hermann https://rg-hermann.github.io/k8s-helm-templates/
   helm repo update
   helm search repo rg-hermann
   ```

2. **Uma única vez**: Validar que Dependabot está habilitado no GitHub
   - Settings → Code security and analysis → Dependabot → Habilitado

3. **Uma única vez**: Validar que ArgoCD está sincronizando
   ```bash
   kubectl get app -n argocd
   argocd app sync python-bootstrap-dev  # Ou deixar automático
   ```

## Após isso: 100% Automático! 🤖

```
Code change → Teste automático → Build automático 
  → Helm publish automático → Dependabot PR automático 
    → Auto-merge automático → K8s deploy automático
```

Qualquer mudança em `k8s-helm-templates/Chart.yaml` ou nos templates se propaga automaticamente para os deployments em até 10 minutos sem nenhuma intervenção manual!

## Monitorando o Pipeline

```bash
# Verificar status das aplicações ArgoCD
kubectl get app -n argocd
argocd app get python-bootstrap-dev
argocd app get java-bootstrap-dev

# Ver sincronizações
kubectl logs -n argocd -l app.kubernetes.io/instance=python-bootstrap-dev

# Ver se Dependabot criar PRs (Semanal)
# Ir em: GitHub → python-bootstrap-infra → Pull Requests
```

---

**Resultado Final**: Infraestrutura como código com GitOps puro. Tudo declarativo, versionado e auditável! 🚀
