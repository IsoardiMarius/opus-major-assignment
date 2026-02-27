package playerdata

import (
	"sync"
)

type PlayerData struct {
	PlayerID string `json:"player_id"`
	Username string `json:"username"`
	Level    int    `json:"level"`
	Region   string `json:"region"`
}

type Store struct {
	mu   sync.RWMutex
	data PlayerData
}

func NewStore() *Store {
	return &Store{
		data: PlayerData{
			PlayerID: "p1",
			Username: "jammer",
			Level:    1,
			Region:   "eu-west",
		},
	}
}

func (s *Store) Get() PlayerData {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.data
}

func (s *Store) Update(p PlayerData) PlayerData {
	s.mu.Lock()
	defer s.mu.Unlock()

	// Simple merge semantics (avoid wiping fields if omitted)
	if p.PlayerID != "" {
		s.data.PlayerID = p.PlayerID
	}
	if p.Username != "" {
		s.data.Username = p.Username
	}
	if p.Level != 0 {
		s.data.Level = p.Level
	}
	if p.Region != "" {
		s.data.Region = p.Region
	}

	return s.data
}
