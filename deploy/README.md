## Deploy Layout

This folder is split into two concerns:

- `argocd/`: ArgoCD bootstrap and ArgoCD `Application` resources.
- `apps/`: Kubernetes manifests for workloads managed by ArgoCD.

### ArgoCD

- `argocd/bootstrap/`: install ArgoCD and apply local bootstrap customizations.
  - `ingress/`: ArgoCD ingress definitions.
  - `patches/`: ConfigMap patches applied during bootstrap.
- `argocd/applications/`: declarative ArgoCD applications for this repository.

### Workloads

- `apps/player-data-service/base/`: reusable base manifests.
- `apps/player-data-service/overlays/minikube/`: environment-specific overlay.
