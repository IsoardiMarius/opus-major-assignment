## Repository layout

- `app/`: Go service source and Dockerfile
- `infra/apps/`: reusable app/platform manifests
    - `infra/apps/workloads/...`
    - `infra/apps/platform/...`
- `infra/clusters/local/`: cluster wiring (ArgoCD install + ArgoCD applications)
- `infra/scripts/`: deploy and demo automation
- `docs/`: project documentation