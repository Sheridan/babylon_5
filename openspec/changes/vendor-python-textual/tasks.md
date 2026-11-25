# Tasks

- [ ] 1. Зафиксировать фактические зависимости и лицензии: `textual-8.2.8` (PyPI metadata), существующие ebuild-и этих пакетов в `::guru` (если доступен через rsync) — как база.
- [ ] 2. Создать ebuildы отсутствующих пакетов в оверлее: `dev-python/textual`, `dev-python/linkify-it-py`, `dev-python/uc-micro-py`; при необходимости — новые версии `mdit-py-plugins`, `rich`, `markdown-it-py`, `pygments`, `platformdirs` (только требуемые диапазоны).
- [ ] 3. Для каждого нового/повышенного пакета: `Manifest` (`pmerge -L` или `emerge --metadata`+`repoman manifest`), `pkgcheck scan <категория/пакет>` без новых error.
- [ ] 4. Проверить разрешимость: `emerge -av app-ai/strata` (USE по умолчанию) завершает расчёт зависимостей без `::guru`; проверить обратные зависимости изменённых пакетов на тестовой системе.
- [ ] 5. Merge, установка на тестовую систему, `strata monitor` на консоли (TTY, без X) показывает TUI и корректно выходит.
- [ ] 6. README.gentoo: заменить раздел-обходной путь про guru на текст «textual и зависимости входят в babylon_5».
