package engine

import "sort"

// SessionPlan is the per-question-type quota derived from the daily count
// target and the session time budget.
//
// The rule (design B): start from daily_target questions. If the time those
// questions would take exceeds session_time_budget, cut the total down to fit
// the budget; if it takes less, keep the target (unused time is fine).
type SessionPlan struct {
	Total  int
	Quotas map[QuestionType]int
}

// PlanSession computes the plan. weights come from the training plan's
// question_type_ratio (empty = equal share across available types).
// TimeWeights is the per-type cost in 10-second units.
func PlanSession(target, budgetMinutes int, weights map[string]int, available []QuestionType) SessionPlan {
	plan := SessionPlan{Quotas: map[QuestionType]int{}}
	if target <= 0 {
		return plan
	}

	types := make([]QuestionType, 0, len(available))
	seen := map[QuestionType]bool{}
	for _, t := range available {
		if !seen[t] {
			seen[t] = true
			types = append(types, t)
		}
	}
	if len(types) == 0 {
		for name := range weights {
			t := QuestionType(name)
			if !seen[t] {
				seen[t] = true
				types = append(types, t)
			}
		}
	}
	if len(types) == 0 {
		plan.Total = target
		return plan
	}

	ws := make([]int, len(types))
	sumW := 0
	for i, t := range types {
		w := weights[string(t)]
		if w < 0 {
			w = 0
		}
		ws[i] = w
		sumW += w
	}
	if sumW == 0 {
		for i := range ws {
			ws[i] = 1
		}
		sumW = len(ws)
	}

	// Weighted average cost of one question, in 10-second units.
	totalCost := 0
	for i, t := range types {
		cost := TimeWeights[string(t)]
		if cost < 1 {
			cost = 1
		}
		totalCost += ws[i] * cost
	}
	avgCost := float64(totalCost) / float64(sumW)
	if avgCost < 1 {
		avgCost = 1
	}

	total := target
	if budgetMinutes > 0 {
		maxByTime := int(float64(budgetMinutes*6) / avgCost)
		if maxByTime < 1 {
			maxByTime = 1
		}
		if maxByTime < total {
			total = maxByTime
		}
	}
	plan.Total = total

	// Largest-remainder allocation so the quotas add up to exactly Total.
	type remainder struct {
		t   QuestionType
		rem float64
	}
	rems := make([]remainder, 0, len(types))
	assigned := 0
	for i, t := range types {
		exact := float64(total) * float64(ws[i]) / float64(sumW)
		q := int(exact)
		plan.Quotas[t] = q
		assigned += q
		rems = append(rems, remainder{t, exact - float64(q)})
	}
	sort.Slice(rems, func(i, j int) bool { return rems[i].rem > rems[j].rem })
	for i := 0; assigned < total; i++ {
		plan.Quotas[rems[i%len(rems)].t]++
		assigned++
	}
	return plan
}
