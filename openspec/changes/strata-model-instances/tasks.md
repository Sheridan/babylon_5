# Tasks

Напоминание: каждый чекбокс `[ ]` — незакрытый вопрос; задача не считается сделанной без
указанной проверки. Все изменения — в `app-ai/strata/`; последовательность работ и архитектура — в design.md.
Проверки, требующие скачивания весов или старта сервиса, отложены по ограничению хоста
(запущенный `strata@` обслуживает эту сессию; скачивания 60–190 ГБ и `systemd-run` на ней не выполняются) —
в скобках указано, что именно осталось проверить.

## 1. Подготовка: шаблон юнита и helper

- [ ] 1.1 Создать шаблон юнита по design.md (решения 4, 5, 6, 9): в репозитории `files/strata.template.service`
      (`@` запрещён pkgcheck в именах FILESDIR), ставится `systemd_newunit ... strata@.service`;
      `Environment=STRATA_CONTROL_INSTALL=1 STRATA_INSTALL_DIR=/var/lib/strata/%i HOME=/var/lib/strata`,
      `EnvironmentFile=/etc/strata/%i/daemon.conf`, `ExecStartPre=/usr/lib/strata/engine-register`,
      `ExecStart=/usr/bin/strata serve --profile /var/lib/strata/%i/strata-%i.json --host ${STRATA_HOST} --port ${STRATA_PORT}`
      (без `--engine`: у serve он принимает только strata|mock; модель — из `--profile`-конфига);
      sandbox-настройки как в прежнем `strata.service`; без `[Install]`, без статического аналога.
      Проверка: `systemd-analyze verify` без ошибок; `systemd-run`-прогон шаблона запускает сервер на порту из daemon.conf.
      (Реализовано и статически проверено 26.11: `systemd-analyze verify` шаблона и экземпляра
      `strata@q2_0.service` — exit 0. Не выполнялась только live-часть: `systemd-run` прогон на установленной
      модели — старт сервиса на этом хосте запрещён.)
- [x] 1.2 Исправить комментарий в `files/strata-engine-register`: вызывается под пользователем сервиса (`User=strata`), не от root; поведение скрипта не менять.
      (Сделано 26.11: комментарий переписан, логика не тронута; идемпотентность по общему штампу
      `/var/lib/strata/.strata-engine-added` подтверждена harness-прогоном root-фазы. `su strata` прогон
      под настоящим пользователем — часть отложенного live-теста 5.2.)

## 2. Скрипты управления моделями (files/)

- [x] 2.1 Написать `files/strata-list-available [family]`: вызывает каталожный хелпер `strata-catalog`
      (файл `files/strata-catalog`, ставится в `/usr/lib/strata`), который читает `FAMILIES`/`MODELS` из
      `setup.py` и гейты (`license_gate`, `risky`) из `strata_control/models.py` через AST, без импорта;
      пары `family/model`, для установленных — пометка INSTALLED с путём; exit коды 0/2/3 по spec.
      (Сделано 26.11: harness — вывод всех 19 пар 0.2.20, фильтр по family, exit 2 для неизвестного family,
      exit 3 при недоступном каталоге через `STRATA_CODE`, пометка INSTALLED. Реальный `/usr/share/strata`
      на хосте — dev-дерево, harness использует распакованный tarball 0.2.20.)
- [ ] 2.2 Написать `files/strata-download-model <family>/<model>`: проверка пары по каталогу до создания
      каталогов; отказ при существующем инстансе и при чужом `strata-*.json`; два `install -d -m 0750 -o strata -g strata`
      (отдельно `<id>` и `<id>/Strata-data` — GNU install красит владельца только последнего компонента);
      `sudo -u strata env HOME=/var/lib/strata STRATA_CONTROL_INSTALL=1 STRATA_INSTALL_DIR=/var/lib/strata/<id>
      /usr/share/strata/setup.py --family F --model M --yes --no-start --data-dir ...` (обёртка `strata install`
      не годится — ищет setup.py внутри install-папки); токен: daemon.conf > `HF_TOKEN` > `HUGGING_FACE_HUB_TOKEN`,
      передаётся явным `env` через sudo; пишет `/etc/strata/<id>/daemon.conf` (127.0.0.1:8080, 0644 root:strata —
      файла с токеном скрипт не создаёт, шаблон требует 0640 root:strata при наличии токена) с сохранением
      пользовательских значений при починке; первое неудачное скачивание удаляет созданную папку, повтор — resume;
      подсказка `systemctl start strata@<id>`.
      Проверка: черновой прогон на модели ~1 ГБ; после работы — `strata-<id>.json` с `exe: component:strata-engine`,
      weights только в `<id>/Strata-data`, daemon.conf не перезаписан при изменённом порту.
      (Реализовано 26.11; все не-скачивательные сценарии закрыты root-фазой harness (45 проверок): валидация пары
      до каталогов, владелец/права вновь созданных каталогов = strata, resume-ветка сохраняет daemon.conf
      с изменённым портом, ветка отказа чистит папку после первого сбоя, токен из существующего daemon.conf
      приоритетнее `HF_TOKEN`. Не выполнялась live-часть: реальное скачивание весов (60–190 ГБ) и проверка
      ран-конфига, который сгенерирует живой setup.py.)
- [x] 2.3 Написать `files/strata-list-installed`: обход `/var/lib/strata/*/strata-*.json`, id / порт из env-файла /
      размер на диске (`du`) / состояние (`systemctl is-active`); «no models installed» и exit 0 при пустом каталоге;
      нечитаемые конфиги — warning и перечисление папки.
      (Сделано 26.11: harness — пустой каталог (exit 0 + сообщение), два фикстуарных инстанса (id, порт 8080,
      ненулевой размер, running/stopped по `FAKE_ACTIVE_UNITS`), нечитаемый конфиг — warning без падения.)
- [x] 2.4 Написать `files/strata-models-inspect <id>`: собственный обзор инстанса (решение 8 — штатная
      `strata models inspect` требует окружения чужого инстанса): каталожные данные пары через
      `strata-catalog for-id`/`show`, ран-конфиг, `du -sh` весов, env-файл с портом, состояние сервиса;
      неизвестный id и несохранённый инстанс — exit 1 с подсказкой скачать.
      (Сделано 26.11: harness — обзор установленного инстанса (пара, размеры, порт, состояние), exit 1
      для неизвестного id и для каталожной, но несохранённой модели.)
- [x] 2.5 Написать `files/strata-rm-model <id>`: отказ для активного инстанса с подсказкой
      `systemctl stop strata@<id>`; отказ удалять world-readable env-файл с токеном; проверка id
      (`^[a-z0-9][a-z0-9_.-]*$`); `rm -rf` только `/var/lib/strata/<id>` и `/etc/strata/<id>`;
      подтверждение удаления только для инстансов с весами (иначе — `-f` для полуинстансов).
      (Сделано 26.11: root-фаза harness — обе папки удалены, соседний инстанс жив; активный инстанс
      отклонён с подсказкой; `../foo` и `Foo` отклонены по маске id; world-readable conf с токеном — отказ exit 1.)
- [x] 2.6 Добавить всем инструментам `--help` (-h, без root): назначение, использование, аргументы, примеры,
      пути и переменные окружения, коды возврата; `--help` не запускает strata и не обращается к каталогу.
      (Сделано 26.11: пять инструментов управления + каталожный хелпер (у него тоже есть --help) —
      справка ≥400 символов с usage-строкой, exit 0 без root и без каталога (`--help` не дёргает `load()`);
      проверено на живом хосте без STRATA_*.)

## 3. Ebuild

- [ ] 3.1 `install()`: `exeinto /usr/bin` + `doexe` пяти инструментов управления; каталожный хелпер —
      `exeinto /usr/lib/strata` + `doexe strata-catalog`; `newexe strata-engine-register engine-register` там же;
      `systemd_newunit strata.template.service strata@.service`; удалить `systemd_dounit strata.service`,
      `keepdir /var/lib/strata/Strata-data`, установку `daemon.conf`/`strata.json` в `/etc/strata`;
      `insinto /etc/strata/instances.d` + `model-instance.conf` (0644, права шаблонных конфигов, 0600 на env-файл).
      Проверка: `ebuild merge` + `qs-list` — инструменты, шаблон и конфиг в контурах, `/etc/strata/daemon.conf`
      и `/etc/strata/strata.json` в CONTENTS отсутствуют; QA чистый.
      (Реализовано 26.11: install()/pkg_postinst() переписаны, Manifest перегенерирован вручную
      (BLAKE2B+SHA512, distfile из DISTDIR), `pkgcheck scan app-ai/strata` — exit 0 без предупреждений
      (потребовало убрать exec-биты из files/ — harness запускает скрипты интерпретатором — и переименовать
      юнит из-за `@` в имени). Не выполнялась live-часть: `emerge`/`ebuild merge` на этой машине — сборка
      и установка пакета здесь не запускаются; CONTENTS на контурах не сверялся.)
- [ ] 3.2 `pkg_postinst`: `daemon-reload`; `strata-user-pwunconv` оставить; elog — workflow трёх шагов
      (list-available → download-model → `systemctl start`) + пути (env-файл `/etc/strata/<id>/daemon.conf`,
      порт 8080, один инстанс на порт) + BREAKING-уведомление (шаблон вместо `strata.service`;
      `/etc/strata/daemon.conf` и `/etc/strata/strata.json` пакетом не поставляются и не удаляются) — по spec.
      Проверка: live-прогон postinst (elog виден при merge), автовключения/`--now` нет.
      (Реализовано 26.11: elog содержит workflow, BREAKING и путь env-файла (путь поправлен 26.11 — был
      указан instances.d); в эбилде нет `--now`/enable. Live-прогон merge с выводом elog — часть 5.1.)
- [x] 3.3 Удалить `files/strata.service`, `files/daemon.conf`, `files/strata.json` (git rm); `metadata.xml` не требует изменений; `Manifest` перегенерирован.
      (Сделано 26.11: `grep -rn 'strata.service\b|etc/strata/daemon.conf|etc/strata/strata.json' app-ai/strata/`
      даёт только упоминания миграции в elog и README.gentoo (README — раздел 4); pkgcheck чист.)

## 4. Документация

- [ ] 4.1 Переписать `files/README.gentoo` (после архивации docs-config-consistency, см. follow-up): раздел «Модель как инстанс» с workflow (list-available → download-model → `systemctl start strata@<id>` → journalctl → rm-model); таблица скриптов; таблица путей и env (`/var/lib/strata/<id>`, `/etc/strata/<id>/daemon.conf`, `STRATA_CONTROL_INSTALL`/`STRATA_INSTALL_DIR`); изоляция и общий движок; BREAKING-абзац с миграцией; `strata models` и `journalctl -u strata@<id>` вместо «strata не даёт список».
      Проверка: workflow списками команд совпадает со справкой скриптов; каждый путь/env из spec «Документация пути и окружения инстансов» упомянут; в README нет ссылок на `systemctl start strata` (без инстанса), `/etc/strata/strata.json` (кроме миграции), `--models-dir`.
- [ ] 4.2 Обновить комментарии в `files/daemon.conf`-стиле: эталон daemon.conf инстанса документировать в README (pkg-config-файла больше нет) + описание `/etc/strata/instances.d/model-instance.conf`.
      Проверка: README показывает содержимое daemon.conf (STRATA_HOST/STRATA_PORT), права (0640 root:strata с токеном / 0644 default) и команду создания через download-model.

## 5. Проверки acceptance (хост с GPU, вручную; для каждой — вывод в отчёте change)

Все пункты раздела отложены 26.11 по ограничению хоста: живой `strata@` инстанс обслуживает эту сессию,
сервисы не останавливаются/не запускаются, weights 60–190 ГБ не скачиваются, `emerge` не запускается.
Статические и fixture-эквиваленты этих проверок закрыты в разделах 1–3 (harness
`/tmp/opencode/test-model-management.sh`: 50 проверок пользовательской фазы + 45 root-фазы, exit 0).

- [ ] 5.1 Установка и BREAKING: `emerge =app-ai/strata-0.2.20` на хосте с остатками старого setup — merge не пишет `/etc/strata/{daemon.conf,strata.json}`, `strata.service` недоступен (`systemctl start strata` → not found), elog содержит BREAKING и workflow.
- [ ] 5.2 Полный workflow на модели до 1 ГБ: list-available → download-model (weights в `<id>/Strata-data`, вывод `--data-dir` подтверждён логом) → `systemctl start strata@<id>` → ответ API на `127.0.0.1:8080` → `journalctl -u strata@<id>` содержит строки сервера → stop → rm-model (обе папки удалены, соседний инстанс жив).
- [ ] 5.3 Изоляция: два инстанса с разными daemon.conf (порты 8080/8081) работают одновременно; конфиги и weights не пересекаются; каталог компонентов и штамп движка общие.
- [ ] 5.4 Отказы на живом хосте: `download-model` на неизвестную пару, на занятое имя, `--help` без root, `rm-model` активного инстанса и некорректного id — сообщения и коды возврата по spec (на fixture-уровне все ветки уже закрыты root-фазой harness).
- [ ] 5.5 Регресс: `emerge` на чистом vfs-контуре без новых QA-предупреждений (`pkgcheck scan` на рабочем дереве уже чист); `systemd-analyze verify strata@.service` на хосте (на этом — exit 0 26.11).

## Workflow follow-up

- [ ] 6.1 Перед реализацией раздела 4 убедиться, что change `docs-config-consistency` заархивирован; иначе обновлять README и main-спеки поверх его результатов.
- [ ] 6.2 После реализации: обновить main-спеки (`strata-model-management`, `strata-packaging`) через sync/archive — сценарии «Системный сервис сервера» и «Предстартовая регистрация движка» переписаны, требование автовключения уже удалено `no-service-auto-enable`; при конфликтах с активными change'ами разрешать в порядке архивации.
- [ ] 6.3 Заархивировать change и упомянуть BREAKING в news item пакета (если ведём `metadata.xml` news или README.changelog-практику).
