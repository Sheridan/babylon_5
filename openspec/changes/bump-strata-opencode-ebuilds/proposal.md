# Proposal

## Why

Оверлей `babylon_5` отстаёт от upstream: `app-ai/strata` собран для 0.2.17 (upstream — 0.2.20), `app-ai/opencode-bin` — для 1.19.6 (upstream — уже 2.4.1, другая мажорная линия). Пользователи оверлея не получают исправления и новые модели Strata и остаются на устаревшей ветке opencode 1.x.

## What Changes

- Новый эбилд `app-ai/strata-0.2.20` (тег `v0.2.20`), собираемый из исходного архива GitHub; старый `strata-0.2.17.ebuild` удаляется из оверлея (в оверлее живёт одна версия пакета).
- Новый эбилд `app-ai/opencode-bin-2.4.1` (тег `v2.4.1`); старый `opencode-bin-1.19.6.ebuild` удаляется.
- **BREAKING** для `opencode-bin`: в релизах opencode 2.x больше нет ассета `LICENSE` — источник текста лицензии в эбилде меняется на raw-файл `LICENSE` из репозитория на теге `v${PV}` (SRC_URI, отдельный distfile).
- Manifest обоих категорий пересобираются под новые distfiles.
- Ассеты релизов opencode 2.x для linux-x64 сохранили имена (`opencode-linux-x64[-baseline][-musl].tar.gz`), поэтому схема выбора по `elibc`/`baseline` остаётся без изменений.

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: версия пакета и исходный тег меняются с 0.2.17 на 0.2.20 в требовании «Пакет доступен из оверлея»; остальное наблюдаемое поведение неизменно.
- `opencode-packaging`: версия пакета и тег меняются с 1.19.6 на 2.4.1 в требованиях «Пакет доступен из оверлея как бинарная поставка» и «Версия установленного CLI»; способ получения текста лицензии меняется (LICENSE больше не ассет релиза).

## Impact

- `app-ai/strata/`: новый `strata-0.2.20.ebuild` (копия 0.2.17 без изменений содержимого, кроме версии), удаление `strata-0.2.17.ebuild`, обновление `Manifest`.
- `app-ai/opencode-bin/`: новый `opencode-bin-2.4.1.ebuild` (PV + замена SRC_URI-строки LICENSE на raw URL тега), удаление `opencode-bin-1.19.6.ebuild`, обновление `Manifest`.
- Файлы `files/` (systemd-юнит, конфиги, `library_check.py`, README.gentoo) не меняются; проверка их пригодности для 0.2.20 — часть задач.
- Установленные системы: штатный `emerge --update` переведёт на новые версии; данных миграций нет.
