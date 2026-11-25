# Spec Delta

## MODIFIED Requirements

### Requirement: Системный сервис сервера
Пакет SHALL устанавливать системного пользователя `strata` (домой `/var/lib/strata`), systemd-юнит `strata.service`, запускающий `strata serve` под этим пользователем, конфиг адреса/порта `/etc/strata/daemon.conf` и конфигурацию сервера `/etc/strata/strata.json`; адрес прослушивания по умолчанию — только localhost. Установка пакета MUST NOT включать сервис автоматически — включение выполняет администратор (`systemctl enable --now strata`), о чём сообщает `pkg_postinst`.

#### Scenario: Состав после установки
- **WHEN** после `emerge app-ai/strata` проверить систему
- **THEN** существуют пользователь/группа `strata`, юнит `strata.service` (в состоянии `disabled`, не включён автоматически), `/etc/strata/daemon.conf` и `/etc/strata/strata.json`

#### Scenario: Явное включение
- **WHEN** администратор выполняет `systemctl enable --now strata`
- **THEN** сервис включён в автозапуск и запущен, сервер отвечает на localhost

#### Scenario: Настройка хоста и порта
- **WHEN** изменить `STRATA_HOST`/`STRATA_PORT` в `/etc/strata/daemon.conf` и выполнить `systemctl restart strata`
- **THEN** сервер слушает указанные адрес и порт (юнит читает их через `EnvironmentFile`)

#### Scenario: Изоляция от пользовательских установок
- **WHEN** сервис запущен
- **THEN** все его данные лежат в `/var/lib/strata`, и он не читает и не изменяет каталоги пользователей (`~/.local/share/strata` и т.п.)

#### Scenario: Движок доступен сервису
- **WHEN** пакет собран с `USE=cuda` (или `hip`) и сервис запускается впервые
- **THEN** системный компонент движка из `/usr/lib/strata/engine` зарегистрирован для пользователя `strata` и используется `serve`
