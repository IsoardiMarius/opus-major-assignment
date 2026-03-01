## minikube-dev Cluster

Contient la définition GitOps pour le cluster local `minikube-dev`.

- `bootstrap/argocd/`: installation + configuration ArgoCD.
- `apps/`: Applications ArgoCD (platform + workloads).

### Entrypoints

```bash
kustomize build clusters/minikube-dev/bootstrap/argocd
kustomize build clusters/minikube-dev/apps
```
