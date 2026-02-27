REGISTRY?=ghcr.io/isoardimarius
IMAGE_NAME?=player-data-service
IMAGE_TAG?=latest
IMAGE_FULL=$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: test test-race fmt fmt-check docker-build docker-run \
        docker-buildx-setup docker-buildx-local docker-buildx-push

test:
	go test ./...

test-race:
	go test -race ./...

fmt:
	gofmt -w .

fmt-check:
	@set -e; \
	UNFORMATTED="$$(gofmt -l .)"; \
	if [ -n "$$UNFORMATTED" ]; then \
		echo "The following files are not gofmt formatted:"; \
		echo "$$UNFORMATTED"; \
		exit 1; \
	fi

docker-build:
	docker build -t $(IMAGE_FULL) .

docker-run:
	docker run --rm -p 8080:8080 $(IMAGE_FULL)

docker-buildx-setup:
	docker buildx create --use --name opusmajor-builder || true
	docker buildx inspect --bootstrap

# Build multi-arch et charge dans le Docker local (utile pour tester sur ta machine)
docker-buildx-local: docker-buildx-setup
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_FULL) --load .

# Build multi-arch et push vers registry (GHCR recommandé)
docker-buildx-push: docker-buildx-setup
	docker buildx build --platform linux/amd64,linux/arm64 -t $(IMAGE_FULL) --push .