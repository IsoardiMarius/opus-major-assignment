package main

import (
	"context"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/IsoardiMarius/opus-major-assignment/internal/httpapi"
	"github.com/IsoardiMarius/opus-major-assignment/internal/observability"
	"github.com/IsoardiMarius/opus-major-assignment/internal/playerdata"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func main() {
	port := envInt("PORT", 8080)

	store := playerdata.NewStore()
	api := httpapi.New(store)

	reg := prometheus.NewRegistry()
	metrics := observability.NewMetrics(reg)

	mux := http.NewServeMux()

	// Core endpoints
	mux.Handle("/healthz", metrics.Wrap("/healthz", http.HandlerFunc(api.Healthz)))
	mux.Handle("/readyz", metrics.Wrap("/readyz", http.HandlerFunc(api.Readyz)))
	mux.Handle("/player-data", metrics.Wrap("/player-data", http.HandlerFunc(api.PlayerData)))

	// Prometheus metrics endpoint
	mux.Handle("/metrics", promhttp.HandlerFor(reg, promhttp.HandlerOpts{}))

	srv := &http.Server{
		Addr:              ":" + strconv.Itoa(port),
		Handler:           logRequests(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
		BaseContext: func(_ net.Listener) context.Context {
			return context.Background()
		},
	}

	// Start
	go func() {
		log.Printf("listening on :%d", port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	// Graceful shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	log.Printf("shutdown signal received")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
	log.Printf("server stopped")
}

func envInt(key string, def int) int {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return def
	}
	return n
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("method=%s path=%s remote=%s duration=%s", r.Method, r.URL.Path, r.RemoteAddr, time.Since(start))
	})
}
