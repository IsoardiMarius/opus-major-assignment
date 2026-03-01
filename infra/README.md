## Infra GitOps Layout

Cette infra est organisée en trois axes:

- `workloads/`: manifests Kubernetes des applications (base + overlays par environnement).
- `platform/`: configuration des composants plateforme partagés (monitoring, logging, etc.).
- `clusters/`: définition par cluster (bootstrap ArgoCD + Applications ArgoCD à déployer).

### Arborescence

```text
infra/
├── clusters/
│   └── minikube-dev/
│       ├── bootstrap/
│       │   └── argocd/
│       └── apps/
├── workloads/
│   └── player-data-service/
│       ├── base/
│       └── overlays/dev/
├── platform/
│   └── monitoring-stack/
│       └── values/dev.yaml
├── docs/
└── scripts/
```

### Conventions

- `base/` ne contient aucune valeur spécifique à un environnement.
- `overlays/dev|staging|prod` portent uniquement les différences d'environnement.
- `clusters/<cluster-name>/` contient le câblage ArgoCD de ce cluster.
- `platform/` contient les valeurs/manifestes réutilisables non applicatifs.

Voir aussi: `docs/structure-conventions.md`.

### Déploiement (minikube-dev)

1. Bootstrap ArgoCD:

```bash
kustomize build clusters/minikube-dev/bootstrap/argocd | kubectl apply -f -
```

2. Déployer les Applications ArgoCD:

```bash
kustomize build clusters/minikube-dev/apps | kubectl apply -f -
```

3. Vérifier les builds kustomize:

```bash
kustomize build workloads/player-data-service/overlays/dev >/dev/null
kustomize build clusters/minikube-dev/apps >/dev/null
kustomize build clusters/minikube-dev/bootstrap/argocd >/dev/null
```
