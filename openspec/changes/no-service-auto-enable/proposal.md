# Why

`pkg_postinst` (строки 363–368) самостоятельно включает сервис: `ln -sfn .../strata.service /etc/systemd/system/multi-user.target.wants/` и `daemon-reload`, а `elog` (строка ~358) заявляет «enabled at multi-user.target». Это нарушает политику дистрибутива (сервисы включаются только явным действием администратора), удивляет пользователей автостартом GPU-сервера при загрузке и расходится с реальностью на openrc-системах (симлинк systemd-таргета там ничего не включает).

## What Changes

- Удалить автовключение из `pkg_postinst`; в `elog` — подсказка `systemctl enable --now strata`.
- Формулировка спецификации «включённый в multi-user.target» заменяется на «не включённый автоматически».

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: требование «Системный сервис сервера» — юнит не включается автоматически, способ включения документируется.

## Impact

- `app-ai/strata/strata-0.2.20.ebuild` (pkg_postinst/elog); поведение установленных систем: после обновления уже включённый юнит остаётся включённым, новые установки — выключены до явного действия.
