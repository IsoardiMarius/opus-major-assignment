REGISTRY?=ghcr.io/isoardimarius
IMAGE_NAME?=player-data-service
IMAGE_TAG?=latest
IMAGE_FULL=$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: docker-buildx-setup docker-buildx-local docker-buildx-push

docker-buildx-setup:
	docker buildx create --use --name opusmajor-builder || true
	docker buildx inspect --bootstrap

# Build multi-arch et charge dans le Docker local (utile pour tester sur ta machine)
docker-buildx-local: docker-buildx-setup
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_FULL) --load .

# Build multi-arch et push vers registry (GHCR recommandé)
docker-buildx-push: docker-buildx-setup
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_FULL) --push .