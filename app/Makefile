.PHONY: test test-race fmt fmt-check

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
