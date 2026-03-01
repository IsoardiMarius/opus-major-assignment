.PHONY: render-workload render-cluster render-bootstrap validate

render-workload:
	kubectl kustomize workloads/player-data-service/overlays/minikube

render-cluster:
	kubectl kustomize clusters/minikube

render-bootstrap:
	kubectl kustomize bootstrap/argocd/overlays/minikube

validate: render-workload render-cluster
	@echo "Local manifests render successfully."
	@echo "Bootstrap render requires network access to raw.githubusercontent.com."
