package engine

import "testing"

func TestPlanSessionFitsBudget(t *testing.T) {
	// 20 questions, half choice (1 unit) half grammar (5 units):
	// average = 3 units → 10 minutes = 60 units fits 20 questions.
	plan := PlanSession(20, 10, map[string]int{"choice": 50, "grammar": 50}, []QuestionType{TypeChoice, TypeGrammar})
	if plan.Total != 20 {
		t.Fatalf("total = %d, want 20", plan.Total)
	}
	if plan.Quotas[TypeChoice]+plan.Quotas[TypeGrammar] != 20 {
		t.Errorf("quotas = %v", plan.Quotas)
	}
}

func TestPlanSessionCutsQuestionsWhenOverBudget(t *testing.T) {
	// 20 questions averaging 3 units = 60 units; a 5-minute budget is 30
	// units, so only 10 questions fit.
	plan := PlanSession(20, 5, map[string]int{"choice": 50, "grammar": 50}, []QuestionType{TypeChoice, TypeGrammar})
	if plan.Total != 10 {
		t.Fatalf("total = %d, want 10", plan.Total)
	}
}

func TestPlanSessionKeepsTargetWhenTimeIsShort(t *testing.T) {
	// 8 choice questions cost 8 units; a 60-minute budget does not inflate.
	plan := PlanSession(8, 60, map[string]int{"choice": 1}, []QuestionType{TypeChoice})
	if plan.Total != 8 {
		t.Fatalf("total = %d, want 8", plan.Total)
	}
}

func TestPlanSessionEqualSharesWithoutWeights(t *testing.T) {
	plan := PlanSession(9, 0, nil, []QuestionType{TypeChoice, TypeFill, TypeSpelling})
	if plan.Total != 9 {
		t.Fatalf("total = %d", plan.Total)
	}
	sum := 0
	for _, q := range plan.Quotas {
		sum += q
	}
	if sum != 9 {
		t.Errorf("quota sum = %d, want 9", sum)
	}
	if plan.Quotas[TypeChoice] == 0 || plan.Quotas[TypeFill] == 0 {
		t.Errorf("equal shares got zero quota: %v", plan.Quotas)
	}
}
