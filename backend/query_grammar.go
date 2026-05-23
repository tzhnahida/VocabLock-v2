//go:build ignore
package main

import (
	"fmt"
	"github.com/vocablock/v2/internal/db"
)

func main() {
	d, _ := db.Open("data")
	if d == nil { fmt.Println("open failed"); return }
	defer d.Close()

	rows, _ := d.DB.Query("SELECT id, title, explanation, example, detail FROM grammar_points ORDER BY id")
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var id int64
			var title, expl, example, detail string
			rows.Scan(&id, &title, &expl, &example, &detail)
			fmt.Printf("=== ID=%d %s ===\n", id, title)
			fmt.Printf("explanation: %s\n", expl)
			fmt.Printf("example: %s\n", example)
			fmt.Printf("detail: %s\n\n", detail)
		}
	}
}
