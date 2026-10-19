---
description: Code review av git-ändringar
argument-hint: "[target]"
---
Gör en code review av följande ändringar. Target: `$1`

Möjliga targets (om inget anges, använd staged):
- `staged` — `git diff --cached`
- `unstaged` — `git diff`
- `HEAD~N` — `git diff HEAD~N`
- en commit-hash — `git diff <hash>^..<hash>`
- `branch:<name>` — `git diff main..<name>`

Fokusera på:
- Buggar och logikfel
- Saknad felhantering
- Säkerhetsproblem
- Namngivning och läsbarhet
- Onödig komplexitet

Visa diff:en först, sen ge feedback per fil. Avsluta med en sammanfattning (👍/⚠️/🚨).
