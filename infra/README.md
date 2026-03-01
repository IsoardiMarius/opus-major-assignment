## Deploy Layout

This folder is split into two concerns:

- `argocd/`: ArgoCD bootstrap and ArgoCD `Application` resources.
- `apps/`: Kubernetes manifests for workloads managed by ArgoCD.

### ArgoCD

- `argocd/bootstrap/base/`: ArgoCD install manifest + shared bootstrap patches.
- `argocd/bootstrap/overlays/minikube/`: environment-specific bootstrap resources.
- `argocd/applications/base/`: shared ArgoCD Application definitions.
- `argocd/applications/overlays/minikube/`: environment-specific Application patches.

### Workloads

- `apps/player-data-service/base/`: reusable base manifests.
- `apps/player-data-service/overlays/minikube/`: environment-specific overlay.
  - `network/ingress.yaml`: ingress is environment-specific (host/class routing).
  - `patches/`: per-environment patch set (for example replicas).
