APP_NAME=player-data-service

.PHONY: tidy test build run

tidy:
	go mod tidy

test:
	go test ./...

build:
	go build -o bin/$(APP_NAME) ./cmd/server

run:
	PORT=8080 go run ./cmd/server