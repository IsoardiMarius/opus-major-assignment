# Release Flow (GitOps + CI)

## Source of truth

Kubernetes desired state is stored in Git. ArgoCD continuously reconciles cluster state to repository state.

## CI behavior (`.github/workflows/ci.yml`)

On push to `main`:

1. `test`
   - `gofmt` check
   - `go test`
   - `go test -race`
2. `infra-validate`
   - render key Kustomize targets
   - validate rendered manifests with `kubeconform`
3. `push` (conditional)
   - runs only when files under `app/**` changed
   - builds and pushes image to GHCR (multi-arch)
4. `trivy` (conditional)
   - scans pushed image digest
5. `pin-digest` (conditional)
   - updates `infra/apps/workloads/player-data-service/overlays/dev/kustomization.yaml`
   - commits digest pin to `main`

## Promotion model

- `dev` is updated automatically by CI digest pin.
- `staging` and `prod` are promoted manually by PR.

Promotion steps:


1. copy digest from `overlays/dev/kustomization.yaml` to `overlays/staging/kustomization.yaml`
2. Push to `main` and wait for ArgoCD sync.
3. validate staging
4. copy same digest from staging to prod overlay
5. Push to `main` and wait for ArgoCD sync.
6. validate prod

This keeps promotion explicit, auditable, and reversible.

## Rollback model

There are two rollback layers.

### 1) Runtime protection rollback (automatic)

Argo Rollouts canary + analysis may abort a bad rollout.

- rollout stays on stable ReplicaSet
- app can appear `Synced` + `Degraded` until next action

### 2) Git rollback (authoritative)

Rollback by reverting promotion commit (or restoring previous digest), then merge.
ArgoCD reconciles back automatically.