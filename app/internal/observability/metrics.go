package observability

import (
	"net/http"
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

type Metrics struct {
	RequestsTotal   *prometheus.CounterVec
	RequestDuration *prometheus.HistogramVec
}

func NewMetrics(reg prometheus.Registerer) *Metrics {
	m := &Metrics{
		RequestsTotal: prometheus.NewCounterVec(
			prometheus.CounterOpts{
				Name: "http_requests_total",
				Help: "Total number of HTTP requests processed.",
			},
			[]string{"path", "method", "status"},
		),
		RequestDuration: prometheus.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "http_request_duration_seconds",
				Help:    "HTTP request duration in seconds.",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"path", "method", "status"},
		),
	}

	reg.MustRegister(m.RequestsTotal, m.RequestDuration)
	return m
}

// Wrap instruments a handler and records status code + duration.
func (m *Metrics) Wrap(path string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		rr := &respRecorder{ResponseWriter: w, status: 200}
		start := time.Now()

		next.ServeHTTP(rr, r)

		status := strconv.Itoa(rr.status)
		m.RequestsTotal.WithLabelValues(path, r.Method, status).Inc()
		m.RequestDuration.WithLabelValues(path, r.Method, status).Observe(time.Since(start).Seconds())
	})
}

type respRecorder struct {
	http.ResponseWriter
	status int
}

func (rr *respRecorder) WriteHeader(code int) {
	rr.status = code
	rr.ResponseWriter.WriteHeader(code)
}
