package api

import "testing"

func TestEstimateLevel(t *testing.T) {
	band := func(c, n int) placementBand { return placementBand{Correct: c, Total: n} }
	cases := []struct {
		name  string
		bands map[string]placementBand
		want  string
	}{
		{
			name: "N2 learner passes everything up to N3",
			bands: map[string]placementBand{
				"N5": band(6, 6), "N4": band(6, 6), "N3": band(5, 6), "N2": band(2, 6), "N1": band(1, 6),
			},
			want: "N3",
		},
		{
			name:  "beginner fails the easiest band",
			bands: map[string]placementBand{"N5": band(2, 6), "N4": band(1, 6)},
			want:  "beginner",
		},
		{
			name:  "advanced passes all",
			bands: map[string]placementBand{"N5": band(6, 6), "N4": band(6, 6), "N3": band(6, 6), "N2": band(6, 6), "N1": band(5, 6)},
			want:  "N1",
		},
		{
			name:  "gap in the middle stops the walk",
			bands: map[string]placementBand{"N5": band(6, 6), "N4": band(3, 6), "N3": band(6, 6)},
			want:  "N5",
		},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := estimateLevel(c.bands); got != c.want {
				t.Errorf("estimateLevel = %q, want %q", got, c.want)
			}
		})
	}
}

func TestDailyNewWords(t *testing.T) {
	if dailyNewWords("N2") != 10 || dailyNewWords("N5") != 15 || dailyNewWords("beginner") != 15 {
		t.Errorf("unexpected daily word targets")
	}
}
