# Why

Документация и файлы конфигурации противоречат друг другу: `files/strata.json` содержит `"log": "/var/lib/strata/strata.log"`, а README.gentoo требует держать `log` вне strata.json (логирование — в stdout/журнал); в README есть осиротевший абзац (~85–89) про `harness.log` — файл, которого пакет не создаёт; поведение конфигов `/etc/strata` при апгрейде (CONFIG_PROTECT, файлы `._cfg*`) нигде не описано, хотя администратору оно критично.

## What Changes

- Устранить противоречие по `log`: оставить механизм, который реально работает после сборки пакета, и описать его согласованно в README.gentoo и комментарии/структуре strata.json.
- Удалить/переписать осиротевший абзац про `harness.log`.
- Добавить в README раздел об обновлении конфигов (защита CONFIG_PROTECT, смысливание `._cfg*`).

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: новое требование — документация согласована с комплектом и поведением Portage.

## Impact

- `app-ai/strata/files/README.gentoo`, `app-ai/strata/files/strata.json`; при выборе «лог в файл» — проверка прав на `/var/lib/strata` (уже владелец strata).
