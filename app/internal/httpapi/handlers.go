package httpapi

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/IsoardiMarius/opus-major-assignment/internal/playerdata"
)

type API struct {
	store *playerdata.Store
}

func New(store *playerdata.Store) *API {
	return &API{store: store}
}

func (a *API) PlayerData(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, a.store.Get())
}

func (a *API) Healthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ok"))
}

func (a *API) Readyz(w http.ResponseWriter, r *http.Request) {
	// In a real system: check downstream deps. Here: always ready.
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("ready"))
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	if err := enc.Encode(v); err != nil {
		log.Printf("failed to encode json response: %v", err)
	}
}
