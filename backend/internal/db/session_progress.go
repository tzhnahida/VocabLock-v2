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
		// No row yet is the normal first-run case.
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
