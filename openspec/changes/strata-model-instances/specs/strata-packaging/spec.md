# Spec Delta: strata-packaging (strata-model-instances)

## MODIFIED Requirements

### Requirement: Системный сервис сервера
Пакет SHALL устанавливать системного пользователя `strata` (домой `/var/lib/strata`) и systemd-шаблон `strata@.service`: инстанс = id модели, адрес/порт инстанса — `/etc/strata/<id>/daemon.conf`, каталог инсталляции — `/var/lib/strata/<id>`, адрес по умолчанию — localhost. Статический unit и общие `/etc/strata/strata.json`, `/etc/strata/daemon.conf` не поставляются; пакет MUST NOT включать инстансы автоматически — это делает администратор (`systemctl enable --now strata@<id>`).

#### Scenario: Состав после установки
- **WHEN** после `emerge app-ai/strata` проверить систему
- **THEN** существуют пользователь/группа `strata`, unit-шаблон `strata@.service` (ничего не включено автоматически), скрипты управления моделями и `/usr/lib/strata/engine-register`; `/etc/strata/daemon.conf`, `/etc/strata/strata.json` и статический `strata.service` отсутствуют

#### Scenario: Явное включение
- **WHEN** администратор выполняет `systemctl enable --now strata@<id>` для установленной модели
- **THEN** инстанс включён в автозапуск и запущен, сервер отвечает на адресе из daemon.conf инстанса; сам пакет при merge не включает ничего

#### Scenario: Запуск инстанса модели
- **WHEN** модель установлена (`strata-download-model`), для неё существует `/etc/strata/<id>/daemon.conf` и выполнен `systemctl start strata@<id>.service`
- **THEN** сервер под пользователем `strata` слушает адрес из daemon.conf; ран-конфиг `strata-<id>.json` найден в `/var/lib/strata/<id>` через `STRATA_CONTROL_INSTALL=1`/`STRATA_INSTALL_DIR`

#### Scenario: Настройка хоста и порта
- **WHEN** изменить `STRATA_HOST`/`STRATA_PORT` в `/etc/strata/<id>/daemon.conf` и выполнить `systemctl restart strata@<id>`
- **THEN** инстанс слушает указанные адрес и порт (шаблон читает их через `EnvironmentFile` от инстанса); другие инстансы не затронуты

#### Scenario: Отсутствие конфига — понятная ошибка
- **WHEN** выполнить `systemctl start strata@<id>` для модели, которая не установлена (нет `/etc/strata/<id>/daemon.conf`)
- **THEN** инстанс завершается с ошибкой, unit-лог содержит указание на отсутствующий конфиг или модель

#### Scenario: Изоляция от пользовательских установок
- **WHEN** инстанс сервиса запущен
- **THEN** его данные лежат в `/var/lib/strata/<id>` (общий движок — в `/var/lib/strata`), он не читает и не изменяет каталоги пользователей (`~/.local/share/strata` и т.п.) и чужих инстансов

#### Scenario: Движок доступен сервису
- **WHEN** пакет собран с `USE=cuda` (или `hip`) и первый инстанс запускается впервые
- **THEN** системный компонент движка из `/usr/lib/strata/engine` зарегистрирован для пользователя `strata` и используется `serve`

#### Scenario: Логи в журнале systemd
- **WHEN** инстанс `strata@<id>` пишет stdout/stderr
- **THEN** вывод собирается в journal и доступен `journalctl -u strata@<id>` без дополнительных unit-настроек

#### Scenario: Несколько моделей одновременно
- **WHEN** установлены две модели и запущены оба инстанса с разными портами в daemon.conf
- **THEN** оба сервера работают одновременно; каталоги инсталляций, weights и ран-конфиги не пересекаются

#### Scenario: Апгрейд поверх статического сервиса
- **WHEN** emerge пакета поверх установки, где существовал статический `strata.service`
- **THEN** merge не создаёт unit-ссылок; weights в `/var/lib/strata/Strata-data` не трогаются; `pkg_postinst` печатает BREAKING-уведомление с инструкцией миграции (включая удаление старого wants-симлинка)

### Requirement: Предстартовая регистрация движка выполняется устанавливаемым скриптом
Шаг предстартовой регистрации движка SHALL вызывать исполняемый файл пакета и выполняться под пользователем сервиса (`User=strata`), не от root; юнит и ebuild MUST NOT содержать инлайнового shell-кода этого шага. Скрипт обязан быть идемпотентным (общий stamp-файл в состоянии пользователя), а его сбой — различим в журнале systemd и не срывать запуск сервера.

#### Scenario: Регистрация под пользователем сервиса
- **WHEN** первый после merge запуск инстанса `strata@<id>` (шаблон наследует `User=strata`)
- **THEN** ExecStartPre выполняется под `strata`, `strata admin components add engine --path /usr/lib/strata/engine --force` записывает компонент в `/var/lib/strata` и создаёт stamp

#### Scenario: Юнит не содержит shell-логики
- **WHEN** открыть установленный `strata@.service`
- **THEN** `ExecStartPre` указывает на абсолютный путь исполняемого файла пакета, без `/bin/sh -c`, составных условий и префикса подавления ошибок

#### Scenario: Идемпотентность
- **WHEN** инстансы перезапускаются повторно после успешной регистрации (общий stamp `/var/lib/strata/.strata-engine-added`)
- **THEN** регистрация не выполняется заново, запуск завершается успешно

#### Scenario: Сборка без GPU-флагов
- **WHEN** инстанс запускается на установке, собранной без `USE=cuda|hip`
- **THEN** шаг регистрации завершается успешно без сообщений, сервер работает

#### Scenario: Сбой остаётся видимым
- **WHEN** регистрация движка не удается (например, каталог данных недоступен на запись)
- **THEN** в журнале systemd присутствует сообщение скрипта с кодом возврата, сервер запущен
