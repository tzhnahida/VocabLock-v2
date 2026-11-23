package db

import "fmt"

// GetSessionProgress returns today's study-card resume point.
func (d *Database) GetSessionProgress(date, language string) (index int, done bool, err error) {
	var idx, dn int
	err = d.DB.QueryRow(
		`SELECT study_index, study_done FROM session_progress WHERE date = ? AND language = ?`,
		date, language,
	).Scan(&idx, &dn)
	if err != nil {
		return 0, false, nil
	}
	return idx, dn != 0, nil
}

func (d *Database) SaveSessionProgress(date, language string, index int, done bool) error {
	dn := 0
	if done {
		dn = 1
	}
	_, err := d.DB.Exec(`
		INSERT INTO session_progress (date, language, study_index, study_done, updated_at)
		VALUES (?, ?, ?, ?, datetime('now','localtime'))
		ON CONFLICT(date, language) DO UPDATE SET
			study_index = excluded.study_index,
			study_done = excluded.study_done,
			updated_at = datetime('now','localtime')
	`, date, language, index, dn)
	if err != nil {
		return fmt.Errorf("save session progress: %w", err)
	}
	return nil
}

func (d *Database) TodayQuestionTypeCounts(language string) (map[string]int, error) {
	rows, err := d.DB.Query(`
		SELECT question_type, COUNT(*) FROM review_log
		WHERE language = ? AND date(created_at) = date('now','localtime')
		GROUP BY question_type
	`, language)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]int{}
	for rows.Next() {
		var t string
		var n int
		if err := rows.Scan(&t, &n); err != nil {
			return nil, err
		}
		out[t] = n
	}
	return out, rows.Err()
}

func (d *Database) SavePendingQuestion(date, language, questionJSON string, wordID int64) error {
	_, err := d.DB.Exec(`
		INSERT INTO pending_question (date, language, question_json, word_id)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(date, language) DO UPDATE SET
			question_json = excluded.question_json,
			word_id = excluded.word_id
	`, date, language, questionJSON, wordID)
	return err
}

func (d *Database) LoadPendingQuestion(date, language string) (string, int64, error) {
	var q string
	var wordID int64
	err := d.DB.QueryRow(
		`SELECT question_json, word_id FROM pending_question WHERE date = ? AND language = ?`,
		date, language,
	).Scan(&q, &wordID)
	if err != nil {
		return "", 0, nil
	}
	return q, wordID, nil
}

func (d *Database) ClearPendingQuestion(date, language string) {
	_, _ = d.DB.Exec(`DELETE FROM pending_question WHERE date = ? AND language = ?`, date, language)
}
