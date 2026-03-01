## Prerequisites

- Docker Desktop
- Minikube
- kubectl
- Git
- Go 1.25.x (for local app development)

Optional local checks:

```bash
docker version
minikube version
kubectl version
git --version
go version
```

## Architecture (GitOps)

- Argo CD bootstrap: `deploy/bootstrap/argocd/overlays/minikube`
- Cluster desired state (AppProject + child Applications): `deploy/clusters/minikube`
- Platform stack (kube-prometheus-stack values): `deploy/platform/monitoring/overlays/minikube/values.yaml`
- Workload manifests: `deploy/workloads/player-data-service`

Deployment model:

1. Bootstrap Argo CD once.
2. Apply the root app (`app-of-apps`).
3. Argo CD continuously syncs platform + workload from Git.

## Quickstart (Minikube + Argo CD)

### 0) Optional clean reset

```bash
pkill -f "minikube tunnel" || true
minikube delete --all --purge || true
```

### 1) Start cluster and ingress

```bash
minikube start --driver=docker
minikube addons enable ingress
kubectl get nodes
```

For Docker driver on macOS:

```bash
sudo minikube tunnel
```

### 2) Bootstrap Argo CD

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -k deploy/bootstrap/argocd/overlays/minikube
```

Wait for Argo CD core components:

```bash
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
```

### 3) Apply root application (cluster desired state)

```bash
kubectl apply -f deploy/clusters/minikube/root-app.yaml
kubectl -n argocd get applications
```

Expected apps:

- `cluster-minikube-root`
- `platform-monitoring`
- `player-data-service`

### 4) Validate service + observability

```bash
curl -fsS http://player-data.127.0.0.1.nip.io/player-data
```

Grafana:

- URL: http://grafana.127.0.0.1.nip.io
- User: `admin`
- Password (local-only setup): `admin1234`

Argo CD:

- URL: http://argocd.127.0.0.1.nip.io
- User: `admin`
- Initial password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

## Immutable image flow

CI builds/pushes image, captures digest, then updates:

- `deploy/workloads/player-data-service/overlays/minikube/kustomization.yaml`

Argo CD then deploys immutable `image@sha256:...`.

## Local validation helpers

```bash
make -C deploy validate
```

Notes:

- `render-bootstrap` needs network access (`raw.githubusercontent.com`) because Argo CD install is pinned from upstream.
- `server.insecure=true` and Grafana admin password are intentionally scoped to Minikube overlay for local demo convenience.
