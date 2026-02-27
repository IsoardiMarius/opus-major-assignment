# ---- Build stage ----
FROM --platform=$BUILDPLATFORM golang:1.25-alpine AS builder

WORKDIR /src
RUN apk add --no-cache ca-certificates git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG TARGETOS
ARG TARGETARCH

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /out/player-data-service ./cmd/server

# ---- Runtime stage ----
FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /
COPY --from=builder /out/player-data-service /player-data-service
EXPOSE 8080
ENTRYPOINT ["/player-data-service"]

# ---- Runtime stage ----
FROM gcr.io/distroless/static-debian12:nonroot

WORKDIR /

COPY --from=builder /out/player-data-service /player-data-service

# Expose is documentation only (still nice)
EXPOSE 8080

# Distroless nonroot already uses a non-root user
ENTRYPOINT ["/player-data-service"]