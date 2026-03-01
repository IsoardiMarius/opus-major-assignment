## Structure And Naming Conventions

### 1) Dossiers racine

- `clusters/`: tout ce qui est spécifique à un cluster réel.
- `workloads/`: manifests des applications métiers.
- `platform/`: composants et valeurs de plateforme.
- `docs/`: documentation opérationnelle.
- `scripts/`: scripts utilitaires (build/validation/migration).

### 2) Workloads

Structure standard:

```text
workloads/<app>/
├── base/
│   ├── core/
│   ├── security/
│   └── observability/
└── overlays/
    ├── dev/
    ├── staging/
    └── prod/
```

Règles:

- `base/` doit rester portable et sans dépendance environnement.
- Les overlays ne doivent contenir que des deltas (`patches`, ingress, image tag/digest, replicas).
- Un fichier = une ressource Kubernetes.

### 3) Clusters

Structure standard:

```text
clusters/<cluster-name>/
├── bootstrap/
│   └── argocd/
└── apps/
    ├── platform/
    └── workloads/
```

Règles:

- Le nom de cluster est technique (`minikube-dev`, `eks-eu-west-1-prod-01`, etc.).
- Les `Application` ArgoCD d'un cluster pointent vers les overlays d'environnement appropriés.

### 4) Platform

- Les valeurs Helm sont versionnées sous `platform/<component>/values/<env>.yaml`.
- Éviter au maximum les gros blocs `helm.values` inline dans les `Application` ArgoCD.

### 5) Validation

À chaque changement structurel:

```bash
kustomize build workloads/<app>/overlays/<env>
kustomize build clusters/<cluster>/apps
kustomize build clusters/<cluster>/bootstrap/argocd
```
