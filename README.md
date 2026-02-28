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

### 1) Start Minikube

```
minikube start --driver=docker
kubectl get nodes
```

### 2) Install ArgoCD (recommended: server-side apply)

```
kubectl create namespace argocd

kubectl apply -n argocd --server-side --force-conflicts \
-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for ArgoCD:

```
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-application-controller --timeout=300s
```

### 3) Deploy the app via ArgoCD (GitOps)

```
kubectl apply -f deploy/argocd/app-service.yaml
kubectl -n argocd get applications
```

Wait until the application is `Synced` and `Healthy`.

### 4) Access the service

Port-forward:

```
kubectl -n opus-major port-forward svc/player-data-service 8080:80
```

Test endpoints:

```
curl -fsS localhost:8080/healthz
curl -fsS localhost:8080/readyz
curl -fsS localhost:8080/player-data
curl -fsS localhost:8080/metrics | head
```

---

## Optional: Run the smoke test

```
chmod +x scripts/smoke-test.sh
./scripts/smoke-test.sh
```

