# Tasks

- [x] 1. Зафиксировать фактические зависимости и лицензии: `textual-8.2.8` (PyPI metadata), существующие ebuild-и этих пакетов в `::guru` (если доступен через rsync) — как база.
- [x] 2. Создать ebuildы отсутствующих пакетов в оверлее: `dev-python/textual`, `dev-python/linkify-it-py`, `dev-python/uc-micro-py`; при необходимости — новые версии `mdit-py-plugins`, `rich`, `markdown-it-py`, `pygments`, `platformdirs` (только требуемые диапазоны).
      Отклонение: проверено по исходникам 8.2.8 — импортов `linkify_it`/`uc_micro`/`mdit_py_plugins` нет,
      linkify-it-py/uc-micro-py/mdit-py-plugins не вендорятся; остальные зависимости уже есть в `::gentoo`.
      Из `::guru`-ebuild взята база, удалены только test-зависимости (BDEPEND + httpx), добавлен `RESTRICT="test"`.
- [x] 3. Для каждого нового/повышенного пакета: `Manifest` (`pmerge -L` или `emerge --metadata`+`repoman manifest`), `pkgcheck scan <категория/пакет>` без новых error.
      (repoman недоступен — Manifest перегенерирован скриптом с корректным форматом: AUX/DIST/EBUILD, BLAKE2B+SHA512.)
- [x] 4. Проверить разрешимость: `emerge -av app-ai/strata` (USE по умолчанию) завершает расчёт зависимостей без `::guru`; проверить обратные зависимости изменённых пакетов на тестовой системе.
      Fake-root (`emerge -pv --with-bdeps=y`, `*/*::guru` под маской): дерево 394 пакета, `::guru` — 0;
      `monitor` включён по умолчанию через profiles/package.use оверлея. Изменённых пакетов `::gentoo` нет,
      вендорится только textual (обратные зависимости проверятся при установке, задача 5).
- [x] 5. Merge, установка на тестовую систему, `strata monitor` на консоли (TTY, без X) показывает TUI и корректно выходит.
      Отклонение: установка в систему запрещена; проверено на распакованном бинарном пакете в песочнице bwrap
      с псевдо-TTY (`script -qec`): TUI отрисовал экран (заголовок STRATA / MONITOR, панель CONNECTION, статус
      CONNECTING — сервер намеренно не запущен), выход по `q` кодом 0. Плюс `strata doctor` из того же пакета
      показывает `ok monitor_tui version 8.2.8` (textual из babylon_5).
- [x] 6. README.gentoo: заменить раздел-обходной путь про guru на текст «textual и зависимости входят в babylon_5».
