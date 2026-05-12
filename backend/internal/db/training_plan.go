package db

import "fmt"

type TrainingPlan struct {
	ID                 int64   `json:"id"`
	Language           string  `json:"language"`
	Direction          string  `json:"direction"`
	DirectionConfidence float64 `json:"direction_confidence"`
	PlanJSON           string  `json:"plan_json"`
	IsActive           bool    `json:"is_active"`
	CreatedAt          string  `json:"created_at"`
}

func (d *Database) InsertTrainingPlan(lang, direction string, confidence float64, planJSON string) (int64, error) {
	// Deactivate existing plans for this language
	d.DB.Exec(`UPDATE training_plans SET is_active = 0 WHERE language = ?`, lang)

	active := 1
	r, err := d.DB.Exec(`
		INSERT INTO training_plans (language, direction, direction_confidence, plan_json, is_active)
		VALUES (?, ?, ?, ?, ?)
	`, lang, direction, confidence, planJSON, active)
	if err != nil {
		return 0, fmt.Errorf("insert training plan: %w", err)
	}
	return r.LastInsertId()
}

func (d *Database) GetActivePlan(language string) (*TrainingPlan, error) {
	row := d.DB.QueryRow(`
		SELECT id, language, direction, direction_confidence, plan_json, is_active, created_at
		FROM training_plans
		WHERE language = ? AND is_active = 1
		ORDER BY created_at DESC
		LIMIT 1
	`, language)

	p := &TrainingPlan{}
	var active int
	if err := row.Scan(&p.ID, &p.Language, &p.Direction, &p.DirectionConfidence,
		&p.PlanJSON, &active, &p.CreatedAt); err != nil {
		return nil, err
	}
	p.IsActive = active == 1
	return p, nil
}

func (d *Database) GetSessionLogs(language string, limit int) ([]*ReviewLog, error) {
	rows, err := d.DB.Query(`
		SELECT r.id, r.word_id, r.question_type, r.user_answer, r.expected_answer,
			r.correct, r.score, r.source, r.created_at
		FROM review_log r
		JOIN words w ON r.word_id = w.id
		WHERE w.language = ? AND date(r.created_at) = date('now')
		ORDER BY r.created_at ASC
		LIMIT ?
	`, language, limit)
	if err != nil {
		return nil, fmt.Errorf("get session logs: %w", err)
	}
	defer rows.Close()

	var logs []*ReviewLog
	for rows.Next() {
		l := &ReviewLog{}
		var correct int
		var createdAt string
		if err := rows.Scan(&l.ID, &l.WordID, &l.QuestionType, &l.UserAnswer, &l.ExpectedAnswer,
			&correct, &l.Score, &l.Source, &createdAt); err != nil {
			return nil, fmt.Errorf("scan log: %w", err)
		}
		l.Correct = correct == 1
		l.CreatedAt = TimeStr(createdAt)
		logs = append(logs, l)
	}
	return logs, nil
}
