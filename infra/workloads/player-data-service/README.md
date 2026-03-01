## player-data-service

- `base/`: ressources communes à tous les environnements.
- `overlays/dev/`: variantes pour l'environnement dev.

### Entrypoints

```bash
kustomize build workloads/player-data-service/base
kustomize build workloads/player-data-service/overlays/dev
```
