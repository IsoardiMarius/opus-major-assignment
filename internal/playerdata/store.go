package playerdata

type PlayerData struct {
	PlayerID string `json:"player_id"`
	Username string `json:"username"`
	Level    int    `json:"level"`
	Region   string `json:"region"`
}

type Store struct {
	data PlayerData
}

func NewStore() *Store {
	return &Store{
		data: PlayerData{
			PlayerID: "p2",
			Username: "jammer",
			Level:    1,
			Region:   "eu-west",
		},
	}
}

func (s *Store) Get() PlayerData {
	return s.data
}
