# Manual Deployment Walkthrough

Use this when you want to understand each step instead of running `infra/scripts/deploy.sh`.

## 1) Start local cluster

```bash
minikube start --driver=docker --cpus=6 --memory=6000 --disk-size=40g
minikube addons enable ingress
```

In another terminal (keep running):

```bash
sudo minikube tunnel
```

## 2) Bootstrap ArgoCD

```bash
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -k infra/clusters/local/argocd/install
```

Wait for ArgoCD core components:

```bash
kubectl -n argocd rollout status deploy/argocd-redis --timeout=600s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s
kubectl -n argocd rollout status deploy/argocd-server --timeout=600s
```

## 3) Create Grafana admin secret

```bash
bash infra/scripts/create-grafana-admin-secret.sh .env
```

This reads `.env` and creates `monitoring/grafana-admin-credentials`.

## 4) Apply ArgoCD applications

```bash
kubectl apply -k infra/clusters/local/argocd/applications
```

Check generated resources:

```bash
kubectl -n argocd get applicationset
kubectl -n argocd get applications
```

Expected applications:

- `argo-rollouts`
- `kyverno`
- `policy-guardrails`
- `monitoring-stack`
- `player-data-service-dev`
- `player-data-service-staging`
- `player-data-service-prod`

## 5) Verify status

```bash
kubectl -n argocd get applications
kubectl -n monitoring get pods
kubectl -n player-data-dev get pods
kubectl -n player-data-staging get pods
kubectl -n player-data-prod get pods
```

## 6) Retrieve credentials (manual)

If you did not use `deploy.sh`, decode manually:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | (base64 --decode 2>/dev/null || base64 -D); echo
kubectl -n monitoring get secret grafana-admin-credentials -o jsonpath='{.data.admin-user}' | (base64 --decode 2>/dev/null || base64 -D); echo
kubectl -n monitoring get secret grafana-admin-credentials -o jsonpath='{.data.admin-password}' | (base64 --decode 2>/dev/null || base64 -D); echo
```

If you used `deploy.sh`, credentials are already stored in:

- `.credentials/argocd.env`
- `.credentials/grafana.env`
