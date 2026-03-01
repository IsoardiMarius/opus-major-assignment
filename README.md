## Prerequisites

> **Note:** Versions below are recommended but not strictly required.

### Required

- **Docker Desktop**: **4.62.0**

  Install: https://docs.docker.com/desktop/

- **Minikube**: **v1.38.1**

  Install: https://minikube.sigs.k8s.io/docs/start/

- **kubectl**: **v1.35.1**

  Install: https://kubernetes.io/docs/tasks/tools/

- **Git**:

  Install: https://git-scm.com/install/

### For local development

- **Go**: **1.25.0** (matches this repository’s `go.mod`)

  Install: https://go.dev/dl/


### Verify your installation

```
docker version
minikube version
kubectl version
git --version
go version
```

## Quickstart (Minikube + ArgoCD + GitOps)

### Immutable image flow (CI -> GitOps)

- CI builds and pushes the image, then captures the exact image digest (`sha256:...`).
- CI updates `deploy/kustomize/overlays/minikube/kustomization.yaml` with that digest.
- ArgoCD syncs from `main`, so the cluster deploys `image@sha256:...` (immutable).

### Observability assets (versioned)

- Prometheus alert rules are versioned in:
  - `deploy/kustomize/base/observability-alerts-configmap.yaml`
- Grafana dashboard JSON is versioned in:
  - `deploy/kustomize/base/grafana-dashboard-configmap.yaml`

Included alerts:
- 5xx ratio on `/player-data` > 5% (10m)
- p95 latency on `/player-data` > 500ms (10m)
- availability on `/player-data` < 99.5% (15m)

Note:
- These assets are deployed as `ConfigMap` objects.
- If you run a Prometheus/Grafana stack with sidecar provisioning, it can load them directly based on labels.

### 0) Clean reset (optional but recommended)

```
pkill -f "minikube tunnel" || true
minikube delete --all --purge || true
```

### 1) Start Minikube and Ingress

```
minikube start --driver=docker
kubectl get nodes
minikube addons enable ingress
```

For Docker driver on macOS, keep a tunnel running in another terminal:

```
minikube tunnel
```

### 2) Bootstrap ArgoCD

```
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -k deploy/argocd/bootstrap
```

Wait for ArgoCD:

```
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-application-controller --timeout=300s
```

### 3) Deploy the app via ArgoCD (GitOps)

Then apply ArgoCD applications and settings:

```
kubectl apply -f deploy/argocd/app-monitoring.yaml
kubectl apply -f deploy/argocd/app-service.yaml
kubectl -n argocd get applications
```

Verify monitoring stack is ready:

```
kubectl -n argocd get applications
kubectl -n monitoring get prometheus,alertmanager
kubectl -n monitoring get pods
kubectl -n monitoring exec deploy/kube-prometheus-stack-grafana -c grafana -- \
  sh -c 'wget -qO- http://kube-prometheus-stack-prometheus.monitoring:9090/-/ready; echo'
```

Expected output includes `Prometheus Server is Ready.`.

ArgoCD update speed:

- `deploy/argocd/argocd-cm.yaml` sets polling to every `30s` (no jitter).


### 4) Access the service through Ingress (HTTP)

Default local host exposed by Ingress:

- http://player-data.127.0.0.1.nip.io/player-data

```
curl -fsS http://player-data.127.0.0.1.nip.io/healthz
curl -fsS http://player-data.127.0.0.1.nip.io/readyz
curl -fsS http://player-data.127.0.0.1.nip.io/player-data
```

### 5) Access Grafana UI

- URL: http://grafana.127.0.0.1.nip.io
- User: `admin`
- Password (as configured in `deploy/argocd/app-monitoring.yaml`): `admin1234`
- The `player-data-service` dashboard should appear automatically from ConfigMap provisioning.

### 6) Access ArgoCD UI

- URL: http://argocd.127.0.0.1.nip.io
- Local note: HTTPS can present a self-signed cert warning; HTTP is the default local entrypoint.
- User: `admin`
- Initial password:

```
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```
