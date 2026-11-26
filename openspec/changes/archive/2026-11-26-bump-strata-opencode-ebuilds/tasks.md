# Tasks

## 1. opencode-bin 2.4.1

- [x] 1.1 Создать `app-ai/opencode-bin/opencode-bin-2.4.1.ebuild` копией 1.19.6 с PV 2.4.1 и заменой ассета LICENSE на `https://github.com/anomalyco/opencode/raw/v${PV}/LICENSE -> ${P}-LICENSE`; удалить `opencode-bin-1.19.6.ebuild`. Проверка: `ebuild app-ai/opencode-bin/opencode-bin-2.4.1.ebuild clean manifest` завершается без ошибок, Manifest содержит distfiles для 2.4.1.
- [x] 1.2 Тестовая сборка без установки (эбилды в IMAGE под /var/tmp/portage): `sudo ebuild app-ai/opencode-bin/opencode-bin-2.4.1.ebuild clean unpack install`. Проверка: фазы проходят без ошибок digest, в `${D}` есть `usr/bin/opencode` и `usr/share/doc/${PF}/LICENSE`.
- [x] 1.3 Smoke-тест без установки: запустить `/usr/bin/opencode --version` из WORKDIR портажного sandbox. Проверка: вывод содержит `2.4.1`.

## 2. strata 0.2.20

- [x] 2.1 Скачать и распаковать архив тега `v0.2.20`; проверить наличие путей, на которые опирается эбилд: `engine/CMakeLists.txt` (проект `strata VERSION`), `terminal/` (включая `bin/strata`, `tools/vision`), `tools/packaging/package_engine.py`. При расхождении — точечно поправить эбилд. Проверка: все пути присутствуют в распакованном дереве (или список расхождений зафиксирован и исправлен).
- [x] 2.2 Сравнить Python-imporты терминала 0.2.20 с RDEPEND эбилда 0.2.17 (numpy, jinja2, regex, pyyaml, tqdm, requests, pillow, psutil, textual); при новых зависимостях — дописать в RDEPEND. Проверка: `python -c "import ..."` каждого модуля терминала проходит в окружении сборки, список RDEPEND обновлён или подтверждён без изменений.
- [x] 2.3 Создать `app-ai/strata/strata-0.2.20.ebuild` (копия 0.2.17 с новым PV и правками из 2.1/2.2 при необходимости); удалить `strata-0.2.17.ebuild`. Проверка: `ebuild app-ai/strata/strata-0.2.20.ebuild clean manifest` проходит, Manifest обновлён.
- [x] 2.4 Тестовая сборка без установки с текущим набором USE (hip, при необходимости vision): `sudo ebuild app-ai/strata/strata-0.2.20.ebuild clean prepare configure compile`. Проверка: компиляция завершается без ошибок, артефакты движка в build-дереве WORKDIR.

## 3. Интеграционная проверка оверлея

- [x] 3.1 `pkgcheck scan app-ai/strata app-ai/opencode-bin` (или `repoman check`, что доступно) без новых ошибок.

## Workflow follow-up

- Установку выполняет пользователь: `emerge -1av app-ai/opencode-bin app-ai/strata`, затем smoke `opencode --version` (2.4.1), `qlist app-ai/opencode-bin`, `strata --help`, `systemctl restart strata` + `systemctl status strata` (осторожно: рестарт прервёт текущую сессию в opencode под strata).
- Закоммитить изменения оверлея (push — по решению пользователя).
- After review, archive the change (`openspec archive bump-strata-opencode-ebuilds`).
