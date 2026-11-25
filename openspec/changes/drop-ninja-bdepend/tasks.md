# Tasks

- [x] 1. Удалить `BDEPEND="dev-build/ninja"` (строка 21) из `app-ai/strata/strata-0.2.20.ebuild`.
- [ ] 2. `pkgcheck scan app-ai/strata` — без новых замечаний; убедиться, что `equery depend`/`emerge -e --nodeps -pv` не упоминает `dev-build/ninja`.
- [ ] 3. Пересобрать пакет (`USE=cuda`) — configure/compile проходят (ninja берётся из `dev-util/ninja`).
