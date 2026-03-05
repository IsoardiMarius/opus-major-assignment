# Opus Major - SRE Home Assignment

This repository delivers a production-like Kubernetes setup for a simple Go API (`/player-data`) with GitOps, progressive delivery, policy guardrails, and observability.

## What is delivered

- Go API containerized and published to GHCR.
- ArgoCD bootstrap from Git (`infra/clusters/local/argocd/install`).
- ArgoCD applications layer (`infra/clusters/local/argocd/applications`) deploying:
  - `argo-rollouts`
  - `kyverno`
  - `policy-guardrails`
  - `monitoring-stack`
  - `player-data-service` ApplicationSet (`dev/staging/prod`)
- Workload manifests managed with Kustomize base + overlays (`infra/apps/workloads/player-data-service`).
- Monitoring stack (Prometheus, Alertmanager, Grafana).
- CI with tests, infra validation, image scan, and digest pinning for GitOps deploy.

## Prerequisites
> **Note:** versions below are recommended, not strictly required.

- **Docker Desktop**: 4.62.0  
  Install: https://docs.docker.com/desktop/
- **Minikube**: v1.38.1  
  Install: https://minikube.sigs.k8s.io/docs/start/
- **kubectl**: v1.35.1  
  Install: https://kubernetes.io/docs/tasks/tools/
- **Git**:  
  Install: https://git-scm.com/downloads

Repository access (required to push):

- accept the GitHub repository invitation before first push
- if you did not receive it, check spam/junk folder for GitHub invitation email

Create local config:

```bash
cp .env.example .env
```

## Quickstart

### 0) Optional reset

```bash
pkill -f "minikube tunnel" || true
minikube delete --all --purge || true
```

### 1) Start cluster + ingress

```bash
minikube start --driver=docker --cpus=6 --memory=6000 --disk-size=40g
# is required because all local URLs are exposed via NGINX Ingress.
minikube addons enable ingress
```

In another terminal (keep running):

```bash
# this emulates cloud `LoadBalancer` behavior;
# without it ingress hostnames (`*.127.0.0.1.nip.io`) may not route correctly.
sudo minikube tunnel
```

### 2) Deploy

```bash
bash infra/scripts/deploy.sh
```

The script:

- bootstraps ArgoCD
- creates Grafana credentials secret from `.env`
- applies ArgoCD applications
- waits for critical apps to become healthy
- writes credentials to `.credentials/`

Manual walkthrough: [`docs/manual-deployment.md`](docs/manual-deployment.md)

## Access URLs

- ArgoCD: <http://argocd.127.0.0.1.nip.io>
  - user: `admin`
  - password: `.credentials/argocd.env`
- Grafana: <http://grafana.127.0.0.1.nip.io>
  - user/password: `.credentials/grafana.env`
- Alertmanager: <http://alertmanager.127.0.0.1.nip.io>
- API dev: <http://player-data-dev.127.0.0.1.nip.io/player-data>
- API staging: <http://player-data-staging.127.0.0.1.nip.io/player-data>
- API prod: <http://player-data-prod.127.0.0.1.nip.io/player-data>

## Deployment and promotion model

### Guided test flow (end-to-end)

1. Modify the app code in `app/internal/playerdata/store.go` (for example change one `PlayerID` value).
2. Commit and push to `main`.
3. Watch CI progress in GitHub Actions:
   - https://github.com/IsoardiMarius/opus-major-assignment/actions
4. After CI succeeds, wait ~30-60 seconds, then open ArgoCD.
5. Verify behavior:
   - only **dev** is updated automatically (CI pins digest only in dev overlay) :
     https://player-data-dev.127.0.0.1.nip.io/player-data
   - `staging` and `prod` do not change until explicit promotion :
      https://player-data-staging.127.0.0.1.nip.io/player-data

### What happens during dev update

- CI updates: `infra/apps/workloads/player-data-service/overlays/dev/kustomization.yaml`.
- ArgoCD detects repo changes (reconciliation interval set to 30s).
- Argo Rollouts performs canary steps (`20% -> 50% -> 100%`) with Prometheus analysis.
- If analysis fails, rollout is aborted and stable ReplicaSet continues serving traffic.

### Promote to staging/prod

Promotion is explicit and reviewable:

1. Copy digest from `infra/apps/workloads/player-data-service/overlays/dev/kustomization.yaml` into `infra/apps/workloads/player-data-service/overlays/staging/kustomization.yaml`.
2. Push to `main` and wait for ArgoCD sync.
3. Validate staging on <http://player-data-staging.127.0.0.1.nip.io/player-data>.
4. Copy same digest from `infra/apps/workloads/player-data-service/overlays/staging/kustomization.yaml` into `infra/apps/workloads/player-data-service/overlays/prod/kustomization.yaml`.
5. Push to `main` and wait for ArgoCD sync.
6. Validate prod on <http://player-data-prod.127.0.0.1.nip.io/player-data>.


### Rollback

- Runtime safety rollback: failed canary analysis aborts rollout and keeps stable version serving.
- Authoritative rollback: revert promotion commit (digest) in Git and push to `main`.

Details: [`docs/release-flow.md`](docs/release-flow.md)

## Observability demo

Run demo:

```bash
bash infra/scripts/demo-monitoring.sh full-demo 120
```

What to observe while it runs:

1. Open Grafana: <http://grafana.127.0.0.1.nip.io>
2. Open dashboard: `Player Data Service - SLO`
3. Watch these panels move:
   - request rate
   - p95 latency
4. Use environment filter (`dev/staging/prod`) to compare behavior.

After script ends:

1. Open Alertmanager: <http://alertmanager.127.0.0.1.nip.io>
2. Refresh the page once.
3. You should see demo alert:
   - `PlayerDataServiceDevHighCpuDemo`
   - this alert is intentionally generated by temporary CPU burn workload in `player-data-dev`.

Details: [`docs/observability.md`](docs/observability.md)

## Architecture and trade-offs
 
- Repository layout: [`docs/repo-layout.md`](docs/repo-layout.md)
- Architecture: [`docs/architecture.md`](docs/architecture.md)
- Trade-offs and assumptions: [`docs/trade-offs.md`](docs/trade-offs.md)
