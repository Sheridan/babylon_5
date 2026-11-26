# Design

## Context

См. proposal.md — Why. Текущее состояние пакета: статический `strata.service` читает `/etc/strata/strata.json` (плейсхолдеры `REPLACE`) и `/etc/strata/daemon.conf`; регистрация движка — `ExecStartPre=/usr/bin/strata-engine-register` со штампом `/var/lib/strata/.strata-engine-added`. Upstream-CLI (`/usr/bin/strata` → `/usr/share/strata/setup.py`) поддерживает режим «control install»: при `STRATA_CONTROL_INSTALL=1` и `STRATA_INSTALL_DIR=<dir>` вся конфигурация инстанса живёт в `<dir>` (`strata-<id>.json`, логи), а каталог компонентов — общий (`~/.local/share/strata/components`, для сервиса — `/var/lib/strata/.local/share/strata/components`). Каталог моделей зашит в `setup.py` (`MODELS`/`FAMILIES`), команда `strata install --family F --model M` скачивает веса с HuggingFace.

Ключевые ограничения: модели 60–120 ГБ (перекачка недопустима); движок ~1 ГБ, ставить его нужно один раз на хост; ран-конфиг ищет в `$HOME/.config/strata` или в install-папке — при `HOME=/var/lib/strata` натащит бытовых моделей в `/var/lib/strata/models`, поэтому инстанс обязан работать с `STRATA_INSTALL_DIR`; `/etc/strata` под CONFIG_PROTECT.

## Goals / Non-Goals

- Goals: один скачивающий скрипт создаёт всё окружение инстанса; инстансы полностью независимы; удаление безопасно; все скрипты самодокументируемы.
- Non-Goals: автовыбор свободного порта (порт всегда 8080, правка руками); удаление/обновление весов из GUI-каталога upstream; управление не-Strata-сервисами; web-интерфейс администрирования.

## Decisions

1. **Изоляция через режим control install, а не через отдельного пользователя на модель.**
   `STRATA_INSTALL_DIR=/var/lib/strata/<id>` даёт штатный upstream-механизм single-model (ран-конфиг, логи — в install-папке), без клонов пользователей и дублирования движка. Альтернатива «user per model» отвергнута: ломает единый `strata`-user, требует N домашний каталогов и N копий компонентов.

2. **Скачивание выполняет upstream-установщик (`setup.py`, install-режим) от имени пользователя `strata`.**
   Обёртка `strata-download-model` делает так: валидация пары по каталогу, два `install -d -m 0750 -o strata -g strata` (отдельно для `<id>` и `<id>/Strata-data`: GNU `install` проставляет владельца/права только последнему компоненту), затем `sudo -u strata env HOME=/var/lib/strata STRATA_CONTROL_INSTALL=1 STRATA_INSTALL_DIR=/var/lib/strata/<id> /usr/share/strata/setup.py --family F --model M --yes --no-start --data-dir /var/lib/strata/<id>/Strata-data` — файлы рождаются владельцем `strata`, отдельного `chown -R` нет. Обёртка `strata install` отвергнута по факту проверки: она резолвит установщик как `Path($STRATA_INSTALL_DIR)/setup.py`, то есть ищет setup.py внутри ещё несозданной install-папки. Флаги сверены с setup.py 0.2.20 и 0.2.22: `--yes` принимает рекомендации setup (в том числе лицензионные гейты), явный `--model` служит согласием с рисковой конфигурацией; `--port` и `--host` не передаём: порт по умолчанию 8080, адрес задаёт `daemon.conf`; без `--data-dir` веса уходят в `$HOME/Strata-data`, поэтому `--data-dir` обязателен. Токен HuggingFace — по приоритету: уже записанный в `/etc/strata/<id>/daemon.conf`, иначе `HF_TOKEN`, иначе `HUGGING_FACE_HUB_TOKEN`; передаётся явным `env`, потому что sudo окружение вычищает. Повторный вызов при прерванном скачивании повторно запускает тот же setup.py (штатный resume, окружение инстанса не затирается); первое неудачное скачивание удаляет созданную папку инстанса, чтобы не оставлять полуинстанс. Альтернатива — самостоятельная загрузка HF-весов скриптом — отвергнута: дублирование логики upstream, риск рассинхрона каталога.
3. **Ран-конфиг генерирует upstream, а не пакет.**
   `setup.py` в install-режиме сам пишет `/var/lib/strata/<id>/strata-<id>.json` с `exe: "component:strata-engine"` и корректными путями весов. Пакет не хранит и не подставляет JSON-шаблон с путями (в отличие от прежнего `/etc/strata/strata.json` с `REPLACE`).

4. **Регистрация движка — тот же `strata-engine-register`, штамп один на хост.**
   Хелпер установлен в `/usr/lib/strata/engine-register` (не `/usr/bin` — это внутренность пакета, администратору там делать нечего), шаблон вызывает его `ExecStartPre`. Он наследует `User=strata`/`HOME=/var/lib/strata`, поэтому регистрация работает под `strata` без изменений: systemd применяет `User=` и к `ExecStartPre`. Идемпотентность держится на общем штампе `/var/lib/strata/.strata-engine-added` (он же в `ReadWritePaths`), так что каждый инстанс лишь проверяет его. В комментарии скрипта исправить «вызывается от root» на «от пользователя сервиса» — иначе следующий читатель вернёт сломанную регистрацию.

5. **Имя инстанса = id модели; привязка systemd — через `%i`.**
   Шаблон: `EnvironmentFile=/etc/strata/%i/daemon.conf`, `Environment=STRATA_CONTROL_INSTALL=1 STRATA_INSTALL_DIR=/var/lib/strata/%i HOME=/var/lib/strata` и `ExecStart=/usr/bin/strata serve --profile /var/lib/strata/%i/strata-%i.json --host ${STRATA_HOST} --port ${STRATA_PORT}`. Без `--engine`: у `serve` этот флаг принимает только `strata|mock`, модель берётся из ран-конфига, на который указывает `--profile`. Без `--config`: ран-конфиг инстанса задаётся именно `--profile`. Идентификатор совпадает с именем install-папки и именем ран-конфига `strata-%i.json`, который ищет upstream (`MODEL_ID` = `[a-z0-9][a-z0-9_.-]*`). В репозитории юнит лежит как `files/strata.template.service` и ставится `systemd_newunit ... strata@.service`: pkgcheck запрещает `@` в именах файлов категории FILESDIR. Альтернатива «произвольное имя инстанса + конфиг с ссылкой на модель» отвергнута: два источника имени, сложнее удаление.

6. **Хост/порт — только в `/etc/strata/<id>/daemon.conf`.**
   Скачивание пишет файл с `STRATA_HOST=127.0.0.1`, `STRATA_PORT=8080` (права 0640 root:strata). Порт не выбирается автоматически: инстансов на хосте обычно один-два, коллизии администратор разрешает правкой файла (в справке — пример). `serve` читает `STRATA_PORT`/`STRATA_HOST` из окружения (проверено на живом CLI), ран-конфиг остаётся машинописным.

7. **Каталог доступных моделей читает отдельный хелпер `strata-catalog` (/usr/lib/strata) через AST, без импорта.**
   `strata-list-available`, `strata-download-model` и `strata-models-inspect` вызывают `/usr/lib/strata/strata-catalog` (устанавливается в `/usr/lib/strata`, не в `/usr/bin` — администраторы его вручную не запускают). Хелпер вытаскивает `FAMILIES`/`MODELS` из `/usr/share/strata/setup.py` и `SUPPORTED_SELECTIONS` из `strata_control/models.py` модулем `ast` — импорт исполнял бы setup.py (зависимость от setuptools, побочные эффекты), awk не разбирает вложенные литералы. Из `models.py` берутся поля гейтов (`license_gate`, `risky`): без них `strata-list-available` скрывал бы, что swift/gyro требуют явного согласия, а `strata-download-model` не мог бы объяснять причину отказа. Команды: `families`, `models [family]` (TSV), `license <family>`, `id <family> <MODEL>` (выводит id так же, как `setup.py --list` — сверено с `_model_install_dir_name`), `for-id`, `show`; неизвестная пара — код 2 с перечислением family. Пути к коду — через `STRATA_CODE` (тесты) с default `/usr/share/strata`. Альтернатива `strata models list` не годится: она перечисляет установленное, а не доступное.

8. **`strata-models-inspect` — собственный обзор инстанса, а не обёртка `strata models inspect`.**
   Реализование: каталожные данные пары через `strata-catalog for-id`/`show`, затем ран-конфиг (`python3 -m json.tool`-разбор через python3), размер весов (`du -sh`), env-файл с портом, состояние `strata@<id>`. Штатная диагностика отвергнута при проверке: `strata models inspect` требует настроенного install-окружения и работает с ран-конфигами в `$HOME`, то есть для чужого инстанса её всё равно пришлось бы обвешивать окружением инстанса от имени `strata`; собственный обзор читает те же файлы напрямую и работает без root. Неизвестный id или несохранённый инстанс — код 1 с подсказкой, id сохраняется только после успешного скачивания.

9. **`strata-rm-model` — отказ при активном сервисе, затем два `rm -rf` с санитизацией пути.**
    Проверка `systemctl is-active strata@<id>` и `is-enabled`; дополнительно — отказ удалять env-файл, который world-readable и содержит токен (сообщение объясняет, что токен утечёт, и как это починить). Удаление строго `/var/lib/strata/<id>` и `/etc/strata/<id>` после проверки, что `<id>` совпадает с `[a-z0-9][a-z0-9_.-]*` и разрешается внутри ожидаемого родителя. Общий каталог компонентов не трогается (движок нужен другим инстансам). Upstream uninstall не предоставляет — только так.

10. **Справка — общий here-doc-блок в каждом скрипте, без общих библиотек.**
   Каждый скрипт самодостаточен (буквально копируется на машину); `--help|-h|без аргументов` печатает usage/аргументы/примеры/переменные окружения и выходит 0; права root для справки не нужны (проверка root — после разбора `--help`).

11. **Базовый `strata.service` и его конфиги удаляются.**
    Единственный путь запуска — шаблон. `pkg_postinst` объясняет переход; старые файлы пользователя остаются на диске (Portage их не удаляет), но в README помечены устаревшими. Отказ от двойной поддержки (статический + шаблон) сознательный: два механизма настраивают один сервер.

## Risks / Trade-offs

- [Прерванное скачивание 100+ ГБ] → обёртка не трогает половину скачанного: повторный вызов запускает тот же `setup.py` (штатный resume); каталоги создаются заранее через `install -d`, повтор их не затирает, а первое неудачное скачивание убирает созданную папку инстанса.
- [`--data-dir` переопределит пути глобально] → флаг передаётся только в разовом окружении одного вызова, глобально ничего не пишем.
- [Upstream может сменить интерфейс `setup.py` между релизами] → обёртка вызывает `/usr/share/strata/setup.py` напрямую и опирается на `--family/--model/--yes/--no-start/--data-dir`; каталожный хелпер читает `setup.py` из того же дерева, поэтому рассинхрон (переименованные литералы, пропавшие флаги) виден сразу и даёт понятную ошибку, а не молчаливую порчу. Проверено на 0.2.20 и 0.2.22 (26.11: вывод каталожного хелпера над обоими деревьями побайтово совпал, флаги `setup.py`/`serve`, гейты `models.py`, requirements и CMake-опции движка не менялись; harness перегнан на дереве 0.2.22).
- [Права на скачанные файлы] → всё создаётся от имени `strata`, отдельного `chown -R` нет; при смешанном владении (ручные правки root'ом) `strata-download-model` не чинит молча — предупреждение в выводе.
- [Шаблон + `ProtectSystem=strict` + `ReadWritePaths=/var/lib/strata`] → ран-конфиг, логи и веса пишутся только туда; временные файлы HF-загрузки — тоже; при нехватке места сервер падает с понятной ошибкой в журнале.
- [Два инстанса на порт 8080] → второй не стартует (порт занят), виден ошибка в `journalctl -u strata@<id> --since`; правится `daemon.conf`. Принято осознанно.
- [Разрыв совместимости с `/etc/strata/strata.json`] → README + `pkg_postinst`: миграция = `strata-download-model`, затем перенос правок из старого `daemon.conf` в новый.

## Migration Plan

1. Обновить пакет: появляются шаблон и скрипты, исчезают `strata.service` и его конфиги (файлы пользователя Portage сохраняет).
2. Администратор: `systemctl stop strata.service` (если был включён), `strata-list-available`, `strata-download-model <f>/<m>`, `systemctl start strata@<m>`; перенести самописные настройки из старых `/etc/strata/*.conf`.
3. Откат: вернуть предыдущую версию пакета (ebuild 0.2.20 с прежним комплектом), файлы `/etc/strata` у целевой машины не удалялись; скачанные модели откат не трогает.

## Open Questions

- (нет)
