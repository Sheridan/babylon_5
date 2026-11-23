# opencode-packaging Specification

## Purpose

Определяет наблюдаемое поведение пакета `app-ai/opencode-bin` в оверлее `babylon_5`: какой бинарный комплект он устанавливает, от чего зависит и каких системных интеграций он сознательно не делает (сервер запускается пользователем вручную).

## Requirements

### Requirement: Пакет доступен из оверлея как бинарная поставка
Оверлей `babylon_5` SHALL предоставлять пакет `app-ai/opencode-bin` (версия 1.19.6, тег `v1.19.6`) с корректным Manifest, лицензией MIT и KEYWORDS `~amd64`: исполняемый файл берётся из готового архива GitHub Releases по SRC_URI с проверкой digest, без компиляции и без исходного дерева upstream.

#### Scenario: Установка из оверлея
- **WHEN** пользователь с подключённым оверлеем `babylon_5` выполняет `emerge app-ai/opencode-bin`
- **THEN** Portage находит пакет, скачивает архив релиза, проверяет хеши и завершает установку без ошибок

#### Scenario: Версия установленного CLI
- **WHEN** сразу после установки выполнить `/usr/bin/opencode --version`
- **THEN** CLI печатает `1.19.6` и завершается кодом 0

### Requirement: Выбор варианта бинарника архитектурой и USE-флагом
SRC_URI пакета SHALL выбирать вариант ассета релиза по профилю машины: `amd64` + `elibc_glibc`/`elibc_musl` и `IUSE="baseline"` (native по умолчанию, baseline — для старых CPU); каждый вариант имеет отдельный distfile с собственным digest.

#### Scenario: musl-профиль
- **WHEN** пакет устанавливается на musl-систему
- **THEN** скачанный и установленный бинарник — `-musl`-ассет релиза, `opencode --version` работает

#### Scenario: baseline по флагу
- **WHEN** установка выполнена с `USE=baseline`
- **THEN** установлен baseline-ассет, бинарник запускается

### Requirement: Runtime-зависимости агента
Пакет SHALL объявлять runtime-зависимости `dev-vcs/git` и `sys-apps/ripgrep`: агент вызывает их в рантайме, и после merge пакета оба инструмента доступны системе.

#### Scenario: Зависимости после merge
- **WHEN** `emerge app-ai/opencode-bin` завершился успешно
- **THEN** `git` и `rg` присутствуют в системе (установлены как зависимости)

### Requirement: Только бинарник, без системной интеграции
Пакет MUST NOT создавать системных пользователей/групп, каталоги в `/var/lib`, файлы в `/etc`, systemd-юниты (ни system-, ни user-mode) и иную фоновую интеграцию: состав установленной системы — `/usr/bin/opencode` и файлы документации в `/usr/share/doc`. Запуск сервера (`opencode serve` / `opencode web`) и автозапуск — ответственность пользователя.

#### Scenario: Состав после установки
- **WHEN** после `emerge app-ai/opencode-bin` выполнить `qlist app-ai/opencode-bin`
- **THEN** список состоит только из `/usr/bin/opencode` и файлов в `/usr/share/doc/${PF}/` (LICENSE)

#### Scenario: Ноль фоновых сервисов
- **WHEN** после установки проверить `getent passwd opencode`, `/var/lib/opencode`, `/usr/lib/systemd/system/opencode.service`, `/usr/lib/systemd/user/opencode.service`
- **THEN** ни один из этих путей не существует, ни один процесс opencode не запущен без действия пользователя
