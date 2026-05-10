package db

import (
	"database/sql"
	"time"
)

// NullTime scans a possibly-null SQLite datetime string into *time.Time.
func NullTime(s sql.NullString) *time.Time {
	if !s.Valid || s.String == "" {
		return nil
	}
	t, err := time.Parse("2006-01-02 15:04:05", s.String)
	if err != nil {
		// Try RFC3339
		t, err = time.Parse(time.RFC3339, s.String)
		if err != nil {
			return nil
		}
	}
	return &t
}

// TimeStr parses a non-null SQLite datetime string.
func TimeStr(s string) time.Time {
	t, err := time.Parse("2006-01-02 15:04:05", s)
	if err != nil {
		t, _ = time.Parse(time.RFC3339, s)
	}
	return t
}

type Word struct {
	ID             int64      `json:"id"`
	Word           string     `json:"word"`
	Reading        string     `json:"reading"`
	Meaning        string     `json:"meaning"`
	POS            string     `json:"pos"`
	Language       string     `json:"language"`
	Source         string     `json:"source"`
	EasinessFactor float64    `json:"easiness_factor"`
	Interval       int        `json:"interval"`
	Repetitions    int        `json:"repetitions"`
	NextReviewAt   *time.Time `json:"next_review_at"`
	LastReviewAt   *time.Time `json:"last_review_at"`
	TotalAttempts  int        `json:"total_attempts"`
	TotalCorrect   int        `json:"total_correct"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type ReviewLog struct {
	ID             int64     `json:"id"`
	WordID         int64     `json:"word_id"`
	QuestionType   string    `json:"question_type"`
	UserAnswer     string    `json:"user_answer"`
	ExpectedAnswer string    `json:"expected_answer"`
	Correct        bool      `json:"correct"`
	Score          float64   `json:"score"`
	Source         string    `json:"source"`
	CreatedAt      time.Time `json:"created_at"`
}

type DailyStats struct {
	Date          string `json:"date"`
	WordsReviewed int    `json:"words_reviewed"`
	WordsCorrect  int    `json:"words_correct"`
	TimeSpentSec  int    `json:"time_spent_sec"`
}
