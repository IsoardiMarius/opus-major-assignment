# Architecture

## Goal

A simple Go API (`/player-data`) in a production-like Kubernetes setup with:

- declarative infrastructure
- GitOps reconciliation
- logical environment separation
- baseline security controls
- actionable observability

## Runtime topology

- One local Kubernetes cluster (Minikube)
- ArgoCD in namespace `argocd`
- Monitoring stack in namespace `monitoring`
- Workload namespaces:
  - `player-data-dev`
  - `player-data-staging`
  - `player-data-prod`

## ArgoCD layering

Cluster-scoped ArgoCD resources are split into two layers:

- Install layer: `infra/clusters/local/argocd/install`
  - installs ArgoCD from pinned upstream manifest (`v3.3.2`)
  - applies local patches (`timeout.reconciliation=30s`, ingress config)
- Applications layer: `infra/clusters/local/argocd/applications`
  - declares all ArgoCD `Application` and `ApplicationSet` resources

### Application order (sync waves)

- Wave `0`: `argo-rollouts`, `kyverno`
- Wave `1`: `policy-guardrails`
- Wave `2`: `player-data-service` ApplicationSet

This ensures CRDs/controllers are ready before workload reconciliation.

## Workload configuration model

Workload manifests use Kustomize base + overlays:

- Base: `infra/apps/workloads/player-data-service/base`
  - Rollout (Argo Rollouts), Service, Ingress, ServiceAccount, PDB
  - NetworkPolicy
  - ServiceMonitor + PrometheusRules + Grafana dashboard ConfigMap
  - AnalysisTemplate for canary quality gates
- Overlays: `infra/apps/workloads/player-data-service/overlays/{dev,staging,prod}`
  - namespace
  - environment labels
  - replica count patch
  - ingress host patch
  - namespace-specific alert expressions
  - immutable image digest pin

## Progressive delivery and policy guardrails

- Progressive delivery uses `Rollout` canary steps (`20% -> 50% -> 100%`) with Prometheus analysis.
- Failed analysis triggers rollout abort (`progressDeadlineAbort: true`) and keeps stable ReplicaSet serving traffic.
- Kyverno policies enforce baseline pod requirements on `player-data-*` namespaces:
  - `runAsNonRoot=true`
  - cpu/memory requests and limits required

## Exposure strategy

Services are exposed by NGINX Ingress + `nip.io` hostnames:

- `argocd.127.0.0.1.nip.io`
- `grafana.127.0.0.1.nip.io`
- `alertmanager.127.0.0.1.nip.io`
- `player-data-{dev|staging|prod}.127.0.0.1.nip.io`

`minikube tunnel` is required locally to emulate cloud `LoadBalancer` behavior.

## Reusability note

`infra/apps/**` is designed to be reusable across additional cluster folders (for example a future `infra/clusters/gke-dev`).
Cluster-specific concerns stay in `infra/clusters/<cluster>/...`.
