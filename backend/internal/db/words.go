package db

import (
	"database/sql"
	"fmt"
)

func (d *Database) InsertWord(w *Word) (int64, error) {
	r, err := d.DB.Exec(`
		INSERT INTO words (word, reading, meaning, pos, language, source)
		VALUES (?, ?, ?, ?, ?, ?)
	`, w.Word, w.Reading, w.Meaning, w.POS, w.Language, w.Source)
	if err != nil {
		return 0, fmt.Errorf("insert word: %w", err)
	}
	return r.LastInsertId()
}

func (d *Database) GetWord(id int64) (*Word, error) {
	w := &Word{}
	err := d.DB.QueryRow(`
		SELECT id, word, reading, meaning, pos, language, source,
		       easiness_factor, interval, repetitions,
		       next_review_at, last_review_at,
		       total_attempts, total_correct, created_at, updated_at
		FROM words WHERE id = ?
	`, id).Scan(
		&w.ID, &w.Word, &w.Reading, &w.Meaning, &w.POS, &w.Language, &w.Source,
		&w.EasinessFactor, &w.Interval, &w.Repetitions,
		&w.NextReviewAt, &w.LastReviewAt,
		&w.TotalAttempts, &w.TotalCorrect, &w.CreatedAt, &w.UpdatedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("get word: %w", err)
	}
	return w, nil
}

func (d *Database) ListWords(language string, limit, offset int) ([]*Word, int, error) {
	var count int
	countQuery := `SELECT COUNT(*) FROM words`
	args := []interface{}{}
	if language != "" {
		countQuery += ` WHERE language = ?`
		args = append(args, language)
	}
	if err := d.DB.QueryRow(countQuery, args...).Scan(&count); err != nil {
		return nil, 0, fmt.Errorf("count words: %w", err)
	}

	query := `
		SELECT id, word, reading, meaning, pos, language, source,
		       easiness_factor, interval, repetitions,
		       next_review_at, last_review_at,
		       total_attempts, total_correct, created_at, updated_at
		FROM words`
	if language != "" {
		query += ` WHERE language = ?`
	}
	query += ` ORDER BY created_at DESC LIMIT ? OFFSET ?`
	args = append(args, limit, offset)

	rows, err := d.DB.Query(query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("list words: %w", err)
	}
	defer rows.Close()

	var words []*Word
	for rows.Next() {
		w := &Word{}
		if err := rows.Scan(
			&w.ID, &w.Word, &w.Reading, &w.Meaning, &w.POS, &w.Language, &w.Source,
			&w.EasinessFactor, &w.Interval, &w.Repetitions,
			&w.NextReviewAt, &w.LastReviewAt,
			&w.TotalAttempts, &w.TotalCorrect, &w.CreatedAt, &w.UpdatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan word: %w", err)
		}
		words = append(words, w)
	}
	return words, count, nil
}

func (d *Database) UpdateWord(w *Word) error {
	_, err := d.DB.Exec(`
		UPDATE words SET word=?, reading=?, meaning=?, pos=?,
		       easiness_factor=?, interval=?, repetitions=?,
		       next_review_at=?, last_review_at=?,
		       total_attempts=?, total_correct=?,
		       updated_at=datetime('now')
		WHERE id=?
	`, w.Word, w.Reading, w.Meaning, w.POS,
		w.EasinessFactor, w.Interval, w.Repetitions,
		w.NextReviewAt, w.LastReviewAt,
		w.TotalAttempts, w.TotalCorrect, w.ID)
	if err != nil {
		return fmt.Errorf("update word: %w", err)
	}
	return nil
}

func (d *Database) DeleteWord(id int64) error {
	_, err := d.DB.Exec(`DELETE FROM words WHERE id = ?`, id)
	if err != nil {
		return fmt.Errorf("delete word: %w", err)
	}
	return nil
}

func (d *Database) ResetWord(id int64) error {
	_, err := d.DB.Exec(`
		UPDATE words SET easiness_factor=2.5, interval=0, repetitions=0,
		       next_review_at=NULL, last_review_at=NULL,
		       total_attempts=0, total_correct=0,
		       updated_at=datetime('now')
		WHERE id=?
	`, id)
	if err != nil {
		return fmt.Errorf("reset word: %w", err)
	}
	return nil
}

func (d *Database) GetReviewWords(language string, limit int) ([]*Word, error) {
	rows, err := d.DB.Query(`
		SELECT id, word, reading, meaning, pos, language, source,
		       easiness_factor, interval, repetitions,
		       next_review_at, last_review_at,
		       total_attempts, total_correct, created_at, updated_at
		FROM words
		WHERE language = ?
		ORDER BY next_review_at ASC NULLS FIRST
		LIMIT ?
	`, language, limit)
	if err != nil {
		return nil, fmt.Errorf("get review words: %w", err)
	}
	defer rows.Close()

	var words []*Word
	for rows.Next() {
		w := &Word{}
		if err := rows.Scan(
			&w.ID, &w.Word, &w.Reading, &w.Meaning, &w.POS, &w.Language, &w.Source,
			&w.EasinessFactor, &w.Interval, &w.Repetitions,
			&w.NextReviewAt, &w.LastReviewAt,
			&w.TotalAttempts, &w.TotalCorrect, &w.CreatedAt, &w.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan review word: %w", err)
		}
		words = append(words, w)
	}
	return words, nil
}

func (d *Database) GetWordsByIDs(ids []int64) ([]*Word, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	query := `
		SELECT id, word, reading, meaning, pos, language, source,
		       easiness_factor, interval, repetitions,
		       next_review_at, last_review_at,
		       total_attempts, total_correct, created_at, updated_at
		FROM words WHERE id IN (?`
	for i := 1; i < len(ids); i++ {
		query += ", ?"
	}
	query += ")"

	args := make([]interface{}, len(ids))
	for i, id := range ids {
		args[i] = id
	}

	rows, err := d.DB.Query(query, args...)
	if err != nil {
		return nil, fmt.Errorf("get words by ids: %w", err)
	}
	defer rows.Close()

	var words []*Word
	for rows.Next() {
		w := &Word{}
		if err := rows.Scan(
			&w.ID, &w.Word, &w.Reading, &w.Meaning, &w.POS, &w.Language, &w.Source,
			&w.EasinessFactor, &w.Interval, &w.Repetitions,
			&w.NextReviewAt, &w.LastReviewAt,
			&w.TotalAttempts, &w.TotalCorrect, &w.CreatedAt, &w.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan word: %w", err)
		}
		words = append(words, w)
	}
	return words, nil
}

func (d *Database) BulkInsertWords(words []*Word) error {
	tx, err := d.DB.Begin()
	if err != nil {
		return fmt.Errorf("begin tx: %w", err)
	}
	defer tx.Rollback()

	stmt, err := tx.Prepare(`
		INSERT INTO words (word, reading, meaning, pos, language, source)
		VALUES (?, ?, ?, ?, ?, ?)
	`)
	if err != nil {
		return fmt.Errorf("prepare: %w", err)
	}
	defer stmt.Close()

	for _, w := range words {
		if _, err := stmt.Exec(w.Word, w.Reading, w.Meaning, w.POS, w.Language, w.Source); err != nil {
			return fmt.Errorf("insert: %w", err)
		}
	}
	return tx.Commit()
}
