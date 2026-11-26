# Tasks

- [x] 1. Переписать условие `use cuda || use hip && targets+=( strata )` в форму `if ... then ... fi`.
- [x] 2. Проверить на тестовой системе состав целей при `USE=cuda`, `USE=hip`, `USE="-cuda -hip"` (dry: `ebuild ... compile` или `sh -x` фрагмент) — множество целей совпадает с текущим.
