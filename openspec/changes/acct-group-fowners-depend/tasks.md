# Tasks

- [x] 1. В `strata-0.2.20.ebuild` добавить `acct-group/strata` в `DEPEND` (оставив RDEPEND как есть, кроме удалённой строки ninja из соседнего изменения — не смешивать патчи построчно).
- [x] 2. `pkgcheck scan app-ai/strata` — без замечаний по fowners/зависимостям.
- [ ] 3. На тестовой системе проверить порядок: `emerge --tree -pv app-ai/strata` ставит `acct-group/strata` до merge strata; merge проходит успешно, `ls -l /etc/strata` показывает владельцев `root:strata`.
