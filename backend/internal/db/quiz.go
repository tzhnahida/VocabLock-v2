package db

import "fmt"

func (d *Database) InsertReviewLog(log *ReviewLog) (int64, error) {
	correct := 0
	if log.Correct {
		correct = 1
	}
	r, err := d.DB.Exec(`
		INSERT INTO review_log (word_id, question_type, user_answer, expected_answer, correct, score, source)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`, log.WordID, log.QuestionType, log.UserAnswer, log.ExpectedAnswer, correct, log.Score, log.Source)
	if err != nil {
		return 0, fmt.Errorf("insert review log: %w", err)
	}
	return r.LastInsertId()
}

func (d *Database) GetReviewLogs(wordID int64, limit int) ([]*ReviewLog, error) {
	rows, err := d.DB.Query(`
		SELECT id, word_id, question_type, user_answer, expected_answer, correct, score, source, created_at
		FROM review_log
		WHERE word_id = ?
		ORDER BY created_at DESC
		LIMIT ?
	`, wordID, limit)
	if err != nil {
		return nil, fmt.Errorf("get review logs: %w", err)
	}
	defer rows.Close()

	var logs []*ReviewLog
	for rows.Next() {
		l := &ReviewLog{}
		var correct int
		if err := rows.Scan(&l.ID, &l.WordID, &l.QuestionType, &l.UserAnswer, &l.ExpectedAnswer,
			&correct, &l.Score, &l.Source, &l.CreatedAt); err != nil {
			return nil, fmt.Errorf("scan review log: %w", err)
		}
		l.Correct = correct == 1
		logs = append(logs, l)
	}
	return logs, nil
}

func (d *Database) GetTodayStats(language string) (reviewed, correct int, err error) {
	err = d.DB.QueryRow(`
		SELECT COUNT(*), COALESCE(SUM(correct), 0)
		FROM review_log r
		JOIN words w ON r.word_id = w.id
		WHERE date(r.created_at) = date('now') AND w.language = ?
	`, language).Scan(&reviewed, &correct)
	return
}

func (d *Database) GetQuizProgress(language string, dailyTarget int) (reviewedToday, remaining int, err error) {
	reviewedToday, _, err = d.GetTodayStats(language)
	if err != nil {
		return 0, 0, err
	}
	remaining = dailyTarget - reviewedToday
	if remaining < 0 {
		remaining = 0
	}
	return reviewedToday, remaining, nil
}
