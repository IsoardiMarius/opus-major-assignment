# Trade-offs and Assumptions

## What Was Deliberately Scoped

### 1) Environment model
One local Minikube cluster with three logical namespaces (`dev/staging/prod`).

### 2) Secret handling
Grafana admin credentials come from local `.env`.

### 3) Alert delivery
Alertmanager UI is available.  
No Slack/PagerDuty/email receiver configured by default.

### 4) Repository split (app + infra)
Application code and GitOps manifests are in the same repository.

### 5) Canary traffic consistency
Rollout can route successive requests from the same user to different revisions during canary steps.

## Practical Next Improvements

1. Secrets: SOPS + External Secrets + cloud secret manager.
2. Environment parity: separate cloud clusters for dev/staging/prod.
3. Alerting operations: real receivers.
4. Policy coverage: broader Kyverno rules (image provenance, hostPath, privilege constraints).
5. Traffic steering consistency: service mesh / advanced ingress routing (header/cookie/session affinity) for stable user experience during canary.
