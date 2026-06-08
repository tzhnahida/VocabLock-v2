package db

import "fmt"

func (d *Database) InsertReviewLog(log *ReviewLog) (int64, error) {
	correct := 0
	if log.Correct {
		correct = 1
	}
	r, err := d.DB.Exec(`
		INSERT INTO review_log (word_id, subject_type, subject_id, question_type, user_answer, expected_answer, correct, score, source)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, log.WordID, log.SubjectType, log.SubjectID, log.QuestionType, log.UserAnswer, log.ExpectedAnswer, correct, log.Score, log.Source)
	if err != nil {
		return 0, fmt.Errorf("insert review log: %w", err)
	}
	return r.LastInsertId()
}

func (d *Database) GetReviewLogs(subjectType string, subjectID int64, limit int) ([]*ReviewLog, error) {
	rows, err := d.DB.Query(`
		SELECT id, word_id, COALESCE(subject_type,'word'), COALESCE(subject_id,0), question_type, user_answer, expected_answer, correct, score, source, created_at
		FROM review_log
		WHERE subject_type = ? AND subject_id = ?
		ORDER BY created_at DESC
		LIMIT ?
	`, subjectType, subjectID, limit)
	if err != nil {
		return nil, fmt.Errorf("get review logs: %w", err)
	}
	defer rows.Close()

	var logs []*ReviewLog
	for rows.Next() {
		l := &ReviewLog{}
		var correct int
		var createdAt string
		if err := rows.Scan(&l.ID, &l.WordID, &l.SubjectType, &l.SubjectID, &l.QuestionType, &l.UserAnswer, &l.ExpectedAnswer,
			&correct, &l.Score, &l.Source, &createdAt); err != nil {
			return nil, fmt.Errorf("scan review log: %w", err)
		}
		l.Correct = correct == 1
		l.CreatedAt = TimeStr(createdAt)
		logs = append(logs, l)
	}
	return logs, nil
}

func (d *Database) GetTodayStats(language string) (reviewed, correct int, err error) {
	err = d.DB.QueryRow(`
		SELECT COUNT(*), COALESCE(SUM(correct), 0)
		FROM review_log r
		WHERE date(r.created_at) = date('now','localtime')
		AND (
			(r.subject_type = 'word' AND r.subject_id IN (SELECT id FROM words WHERE language = ?))
			OR (r.subject_type = 'grammar' AND r.subject_id IN (SELECT id FROM grammar_points WHERE language = ?))
		)
	`, language, language).Scan(&reviewed, &correct)
	return
}

// GetUniqueSubjectsReviewed returns the count of distinct (subject_type, subject_id)
// pairs reviewed today for the given language. This counts unique words/grammar points
// rather than total attempts, so repeated attempts on the same word don't inflate
// the daily counter for session completion checks.
func (d *Database) GetUniqueSubjectsReviewed(language string) (int, error) {
	var count int
	err := d.DB.QueryRow(`
		SELECT COUNT(DISTINCT subject_type || ':' || subject_id)
		FROM review_log
		WHERE date(created_at) = date('now','localtime')
		AND (
			(subject_type = 'word' AND subject_id IN (SELECT id FROM words WHERE language = ?))
			OR (subject_type = 'grammar' AND subject_id IN (SELECT id FROM grammar_points WHERE language = ?))
		)
	`, language, language).Scan(&count)
	if err != nil {
		return 0, fmt.Errorf("count unique subjects: %w", err)
	}
	return count, nil
}

func (d *Database) GetQuizProgress(language string, dailyTarget int) (reviewedToday, remaining int, err error) {
	reviewedToday, err = d.GetUniqueSubjectsReviewed(language)
	if err != nil {
		return 0, 0, err
	}
	remaining = dailyTarget - reviewedToday
	if remaining < 0 {
		remaining = 0
	}
	return reviewedToday, remaining, nil
}

// SessionCounts returns the breakdown for quiz session start.
func (d *Database) SessionCounts(language string) (newWords, newGrammar, reviewWords, reviewGrammar int, err error) {
	err = d.DB.QueryRow(`
		SELECT COUNT(*) FROM words
		WHERE language = ? AND status = 'active' AND next_review_at IS NULL
	`, language).Scan(&newWords)
	if err != nil {
		return 0, 0, 0, 0, fmt.Errorf("count new words: %w", err)
	}

	err = d.DB.QueryRow(`
		SELECT COUNT(*) FROM words
		WHERE language = ? AND status = 'active' AND next_review_at IS NOT NULL AND next_review_at <= datetime('now','localtime')
	`, language).Scan(&reviewWords)
	if err != nil {
		return 0, 0, 0, 0, fmt.Errorf("count review words: %w", err)
	}

	err = d.DB.QueryRow(`
		SELECT COUNT(*) FROM grammar_points
		WHERE language = ? AND status = 'active' AND next_review_at IS NULL
	`, language).Scan(&newGrammar)
	if err != nil {
		return 0, 0, 0, 0, fmt.Errorf("count new grammar: %w", err)
	}

	err = d.DB.QueryRow(`
		SELECT COUNT(*) FROM grammar_points
		WHERE language = ? AND status = 'active' AND next_review_at IS NOT NULL AND next_review_at <= datetime('now','localtime')
	`, language).Scan(&reviewGrammar)
	if err != nil {
		return 0, 0, 0, 0, fmt.Errorf("count review grammar: %w", err)
	}

	return newWords, newGrammar, reviewWords, reviewGrammar, nil
}
