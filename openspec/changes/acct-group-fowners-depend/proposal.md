# Why

В `src_install` ebuild выполняет `fowners root:strata` для файлов в `/etc/strata` и `/var/lib/strata`, но `acct-group/strata` объявлен только в `RDEPEND`. PMS требует, чтобы группы/пользователи, используемые в `fowners`/`fperms`, были объявлены в `DEPEND` (зависимость должна быть удовлетворена до merge). Обычно порядок ставит acct-* раньше, но гарантия не формальная, а статистическая: при восстановлении мира, `--nodeps` или ошибке порядка merge владелец файлов не существует и `fowners` падает (или пишет несуществующего владельца в базу).

## What Changes

- `acct-group/strata` переносится (копируется) в `DEPEND` ebuild; `acct-user/strata` остаётся в `RDEPEND` (пользователь нужен в рантайме, для `fowners` достаточно группы).

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: новое требование — владение установленными файлами гарантировано декларативно.

## Impact

- Только ebuild `app-ai/strata` (зависимости); пересборка без изменения содержимого пакета.
