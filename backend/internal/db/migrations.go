package db

import (
	"fmt"
	"strings"
)

func (d *Database) migrate() error {
	_, err := d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS words (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			word TEXT NOT NULL,
			reading TEXT NOT NULL DEFAULT '',
			meaning TEXT NOT NULL DEFAULT '',
			pos TEXT NOT NULL DEFAULT '',
			language TEXT NOT NULL DEFAULT '',
			source TEXT NOT NULL DEFAULT 'manual',
			easiness_factor REAL NOT NULL DEFAULT 2.5,
			interval INTEGER NOT NULL DEFAULT 0,
			repetitions INTEGER NOT NULL DEFAULT 0,
			next_review_at TEXT,
			last_review_at TEXT,
			total_attempts INTEGER NOT NULL DEFAULT 0,
			total_correct INTEGER NOT NULL DEFAULT 0,
			created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
			updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
		);

		CREATE TABLE IF NOT EXISTS review_log (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			word_id INTEGER NOT NULL,
			question_type TEXT NOT NULL,
			user_answer TEXT NOT NULL DEFAULT '',
			expected_answer TEXT NOT NULL DEFAULT '',
			correct INTEGER NOT NULL DEFAULT 0,
			score REAL NOT NULL DEFAULT 0.0,
			source TEXT NOT NULL DEFAULT 'exact',
			created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
			FOREIGN KEY (word_id) REFERENCES words(id)
		);

		CREATE TABLE IF NOT EXISTS daily_stats (
			date TEXT PRIMARY KEY,
			words_reviewed INTEGER NOT NULL DEFAULT 0,
			words_correct INTEGER NOT NULL DEFAULT 0,
			time_spent_sec INTEGER NOT NULL DEFAULT 0
		);

		CREATE TABLE IF NOT EXISTS config (
			key TEXT PRIMARY KEY,
			value TEXT NOT NULL DEFAULT ''
		);

		CREATE TABLE IF NOT EXISTS assignments (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			language TEXT NOT NULL DEFAULT '',
			type TEXT NOT NULL,
			prompt TEXT NOT NULL DEFAULT '',
			context TEXT NOT NULL DEFAULT '',
			answer TEXT NOT NULL DEFAULT '',
			score REAL NOT NULL DEFAULT 0.0,
			feedback TEXT NOT NULL DEFAULT '',
			status TEXT NOT NULL DEFAULT 'pending',
			created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
			updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
		);

		CREATE TABLE IF NOT EXISTS assignment_cadence (
			language TEXT PRIMARY KEY,
			last_given_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
		);

		CREATE INDEX IF NOT EXISTS idx_words_next_review ON words(next_review_at);
		CREATE INDEX IF NOT EXISTS idx_words_language ON words(language);
		CREATE INDEX IF NOT EXISTS idx_review_log_word_id ON review_log(word_id);
		CREATE INDEX IF NOT EXISTS idx_review_log_created ON review_log(created_at);
		CREATE INDEX IF NOT EXISTS idx_assignments_status ON assignments(status);
	`)
	if err != nil {
		return err
	}

	// Phase 2: add confidence column for AI-expanded words
	if _, err := d.DB.Exec(`ALTER TABLE words ADD COLUMN confidence TEXT NOT NULL DEFAULT ''`); err != nil {
		if !strings.Contains(err.Error(), "duplicate column") {
			return fmt.Errorf("add confidence column: %w", err)
		}
	}

	// Phase 3: direction, status, tags for words + training_plans
	if _, err := d.DB.Exec(`ALTER TABLE words ADD COLUMN direction TEXT NOT NULL DEFAULT ''`); err != nil {
		if !strings.Contains(err.Error(), "duplicate column") {
			return fmt.Errorf("add direction column: %w", err)
		}
	}
	if _, err := d.DB.Exec(`ALTER TABLE words ADD COLUMN status TEXT NOT NULL DEFAULT 'active'`); err != nil {
		if !strings.Contains(err.Error(), "duplicate column") {
			return fmt.Errorf("add status column: %w", err)
		}
	}
	if _, err := d.DB.Exec(`ALTER TABLE words ADD COLUMN tags TEXT NOT NULL DEFAULT ''`); err != nil {
		if !strings.Contains(err.Error(), "duplicate column") {
			return fmt.Errorf("add tags column: %w", err)
		}
	}

	if _, err := d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS training_plans (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			language TEXT NOT NULL,
			direction TEXT NOT NULL DEFAULT 'general',
			direction_confidence REAL NOT NULL DEFAULT 0.0,
			plan_json TEXT NOT NULL DEFAULT '',
			is_active INTEGER NOT NULL DEFAULT 1,
			created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
		)
	`); err != nil {
		return fmt.Errorf("create training_plans table: %w", err)
	}

	// Phase 4: grammar_points table (SM-2 for grammar) + review_log generalization
	if _, err := d.DB.Exec(`
		CREATE TABLE IF NOT EXISTS grammar_points (
			id              INTEGER PRIMARY KEY AUTOINCREMENT,
			title           TEXT NOT NULL DEFAULT '',
			explanation     TEXT NOT NULL DEFAULT '',
			example         TEXT NOT NULL DEFAULT '',
			language        TEXT NOT NULL DEFAULT '',
			source          TEXT NOT NULL DEFAULT 'ai',
			status          TEXT NOT NULL DEFAULT 'active',
			easiness_factor REAL NOT NULL DEFAULT 2.5,
			interval        INTEGER NOT NULL DEFAULT 0,
			repetitions     INTEGER NOT NULL DEFAULT 0,
			next_review_at  TEXT,
			last_review_at  TEXT,
			total_attempts  INTEGER NOT NULL DEFAULT 0,
			total_correct   INTEGER NOT NULL DEFAULT 0,
			created_at      TEXT NOT NULL DEFAULT (datetime('now','localtime')),
			updated_at      TEXT NOT NULL DEFAULT (datetime('now','localtime'))
		)
	`); err != nil {
		return fmt.Errorf("create grammar_points table: %w", err)
	}

	_, _ = d.DB.Exec(`CREATE INDEX IF NOT EXISTS idx_grammar_points_next_review ON grammar_points(next_review_at)`)
	_, _ = d.DB.Exec(`CREATE INDEX IF NOT EXISTS idx_grammar_points_language ON grammar_points(language)`)
	_, _ = d.DB.Exec(`CREATE UNIQUE INDEX IF NOT EXISTS idx_words_word_lang ON words(word, language)`)

	if _, err := d.DB.Exec(`ALTER TABLE review_log ADD COLUMN subject_type TEXT NOT NULL DEFAULT 'word'`); err != nil {
		if !strings.Contains(err.Error(), "duplicate column") {
			return fmt.Errorf("add subject_type column: %w", err)
		}
	}
	if _, err := d.DB.Exec(`ALTER TABLE review_log ADD COLUMN subject_id INTEGER NOT NULL DEFAULT 0`); err != nil {
		if !strings.Contains(err.Error(), "duplicate column") {
			return fmt.Errorf("add subject_id column: %w", err)
		}
	}

	return nil
}
