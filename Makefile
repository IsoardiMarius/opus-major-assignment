REGISTRY?=ghcr.io/isoardimarius
IMAGE_NAME?=player-data-service
IMAGE_TAG?=latest
IMAGE_FULL=$(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: test test-race fmt fmt-check docker-build docker-run \
        docker-buildx-setup docker-buildx-local docker-buildx-push

test:
	go test ./...

# Helps detect concurrency issues
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
