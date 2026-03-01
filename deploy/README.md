## Deploy Layout

This directory is split by lifecycle responsibility.

- `bootstrap/`: install and minimally configure Argo CD.
- `clusters/`: cluster desired state (AppProject + Argo CD Applications).
- `platform/`: shared platform stacks configuration (monitoring values).
- `workloads/`: service-level Kubernetes manifests.

### `bootstrap/argocd`

- `base/`: pinned Argo CD install source.
- `overlays/minikube/`: local-only patches (`server.insecure`, fast reconciliation, ingress host).

### `clusters/minikube`

- `root-app.yaml`: app-of-apps entrypoint applied once.
- `kustomization.yaml`: managed resources for the cluster.
- `project-opus-major.yaml`: Argo CD guardrails (sources/destinations).
- `apps/`: child applications (`platform-monitoring`, `player-data-service`).

### `platform/monitoring`

- `overlays/minikube/values.yaml`: kube-prometheus-stack chart values for local setup.

### `workloads/player-data-service`

- `base/`: environment-agnostic core workload (Deployment/Service/SA/PDB).
- `components/observability/`: opt-in observability resources (ServiceMonitor, PrometheusRule, Grafana dashboard).
- `overlays/minikube/`: namespace, ingress, network policy, replica patch, immutable image digest.

## Conventions

- Argo CD Applications always target environment overlays, never raw bases.
- `base/` contains no local-only concerns.
- Environment-specific settings live in `overlays/<env>`.
- Monitoring rules use `PrometheusRule` CRDs (not ad-hoc ConfigMaps).
