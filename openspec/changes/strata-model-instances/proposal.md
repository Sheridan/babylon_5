# Proposal

## Why

Администратор хоста сегодня может запустить только один статический сервер: пакет требует вручную заполнить `/etc/strata/strata.json` (плейсхолдеры `REPLACE`) и не даёт ни списка доступных моделей, ни установки, ни удаления. Нужен сценарий: посмотреть каталог, скачать модель одной командой, запустить её как `systemctl start strata@<модель>.service`, при желании удалить. Upstream уже поддерживает изолированный режим установки (`STRATA_CONTROL_INSTALL=1` + `STRATA_INSTALL_DIR`), в котором одна папка инсталляции содержит ровно одну модель — пакет должен открыть этот режим скриптами и шаблонным юнитом.

## What Changes

- Пакет устанавливает systemd-шаблон `strata@.service`: инстанс `strata@<id>` запускает `strata serve` с ран-конфигом `/var/lib/strata/<id>/strata-<id>.json` и адресом из `/etc/strata/<id>/daemon.conf`.
- Пять скриптов администратора (каждый с подробной `--help`):
  `strata-list-available`, `strata-download-model`, `strata-list-installed`, `strata-models-inspect`, `strata-rm-model`.
- `strata-download-model` создаёт всё окружение инстанса: каталоги с владельцем `strata`, скачивание модели от имени пользователя `strata` в изолированную install-папку, генерацию ран-конфига (движок — общий компонент `component:strata-engine`) и `/etc/strata/<id>/daemon.conf` с портом 8080 по умолчанию (правка — руками).
- Изоляция: инстанс видит только свою модель (`STRATA_INSTALL_DIR=/var/lib/strata/<id>`), данные модели в `/var/lib/strata/<id>/Strata-data`; пользователь `strata` владеет всем в `/var/lib/strata`.
- **BREAKING** Удаляются статические `strata.service`, `/etc/strata/strata.json` и `/etc/strata/daemon.conf`: единственный поддерживаемый способ запустить сервер — инстанс `strata@<id>`, созданный `strata-download-model`. Логи сервиса — в `journalctl -u strata@<id>`.

## Capabilities

### New Capabilities

- `strata-model-management`: управление моделями хоста администратором — каталог доступных моделей, скачивание с созданием полного окружения инстанса, обзор установленных, диагностика одной модели, удаление; изоляция инстансов друг от друга и `--help` у всех скриптов.

### Modified Capabilities

- `strata-packaging`: требование «Системный сервис сервера» — вместо статического `strata.service` с `/etc/strata/strata.json` пакет устанавливает шаблон `strata@.service` с поинстансными `EnvironmentFile` и `/etc/strata/<id>/` (MODIFIED-блок сохраняет и переписывает все текущие сценарии, включая «Явное включение» из `no-service-auto-enable`); требование «Предстартовая регистрация движка выполняется устанавливаемым скриптом» — регистрация под пользователем `strata` в шаблоне.

## Impact

- `app-ai/strata/files/`: новые `strata@.service` и скрипты; удаление `strata.service`, `strata.json`, `daemon.conf`; правки `strata-engine-register` (комментарий про пользователя) и `README.gentoo`.
- `app-ai/strata/strata-0.2.20.ebuild`: установка скриптов (`dobin`), состав `/etc/strata`, текст `pkg_postinst`; CONFIG_PROTECT для `/etc/strata` сохраняется.
- Зависимости: новых нет; каталог моделей читается python-хелпером из поставляемого `/usr/share/strata/setup.py`.
- Порядок: накладывается поверх изменений `no-service-auto-enable` и `docs-config-consistency` (те же юнит/README/spec) — начинать после их архивации.
