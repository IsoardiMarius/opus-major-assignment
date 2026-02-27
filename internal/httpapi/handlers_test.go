package httpapi

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/IsoardiMarius/opus-major-assignment/internal/playerdata"
)

func setupAPI() *API {
	store := playerdata.NewStore()
	return New(store)
}

func TestHealthz(t *testing.T) {
	api := setupAPI()

	req := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	rec := httptest.NewRecorder()

	api.Healthz(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	body := rec.Body.String()
	if body != "ok" {
		t.Fatalf("expected body 'ok', got '%s'", body)
	}
}

func TestPlayerData(t *testing.T) {
	api := setupAPI()

	req := httptest.NewRequest(http.MethodGet, "/player-data", nil)
	rec := httptest.NewRecorder()

	api.PlayerData(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	var data playerdata.PlayerData
	if err := json.NewDecoder(rec.Body).Decode(&data); err != nil {
		t.Fatalf("invalid JSON response: %v", err)
	}

	if data.PlayerID != "p1" {
		t.Fatalf("unexpected player_id: %s", data.PlayerID)
	}
}
