package db

import (
	"database/sql"
	"path/filepath"
	"testing"
)

// TestMigrateDailyStatsCompositeKey starts from the pre-Phase-8 schema
// (date TEXT PRIMARY KEY) and verifies that migration rebuilds the table so
// the same day can hold one row per language.
func TestMigrateDailyStatsCompositeKey(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "vocablock.db")

	raw, err := sql.Open("sqlite", path)
	if err != nil {
		t.Fatalf("open raw db: %v", err)
	}
	_, err = raw.Exec(`
		CREATE TABLE daily_stats (
			date TEXT PRIMARY KEY,
			words_reviewed INTEGER NOT NULL DEFAULT 0,
			words_correct INTEGER NOT NULL DEFAULT 0,
			time_spent_sec INTEGER NOT NULL DEFAULT 0
		);
		INSERT INTO daily_stats (date, words_reviewed, words_correct, time_spent_sec)
		VALUES ('2026-11-10', 2, 1, 30);
	`)
	if err != nil {
		raw.Close()
		t.Fatalf("create old schema: %v", err)
	}
	if err := raw.Close(); err != nil {
		t.Fatalf("close raw db: %v", err)
	}

	d, err := Open(dir)
	if err != nil {
		t.Fatalf("migrate: %v", err)
	}
	defer d.Close()

	for _, lang := range []string{"en", "ja"} {
		if err := d.UpsertDailyStats("2026-11-10", lang, 1, 1, 10); err != nil {
			t.Fatalf("upsert %s: %v", lang, err)
		}
	}

	rows, err := d.DB.Query(`SELECT language FROM daily_stats WHERE date = ? ORDER BY language`, "2026-11-10")
	if err != nil {
		t.Fatalf("query rows: %v", err)
	}
	defer rows.Close()
	var langs []string
	for rows.Next() {
		var lang string
		if err := rows.Scan(&lang); err != nil {
			t.Fatalf("scan language: %v", err)
		}
		langs = append(langs, lang)
	}
	if err := rows.Err(); err != nil {
		t.Fatalf("iterate rows: %v", err)
	}
	if len(langs) != 3 {
		t.Fatalf("rows = %v, want old '' row plus en and ja", langs)
	}
}
