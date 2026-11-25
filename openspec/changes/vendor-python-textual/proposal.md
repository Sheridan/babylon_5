# Why

`monitor` входит в `IUSE_DEFAULTS` ebuild, и `app-ai/strata` с флагом `monitor` требует `dev-python/textual[...]`. В `::gentoo` пакета textual нет, а `::guru` на целевых системах отключён — `emerge app-ai/strata` с USE по умолчанию не разрешается (portage не находит `dev-python/textual`). Обходной путь из README.gentoo (включить guru) делает дефолтную конфигурацию нерабочей «из коробки».

## What Changes

- В оверлей вендорится `dev-python/textual` (версия, удовлетворяющая RDEPEND ebuild) и замыкающие зависимости, отсутствующие или слишком старые в `::gentoo`: минимум `dev-python/linkify-it-py`, `dev-python/uc-micro-py`, актуальный `dev-python/mdit-py-plugins`; при необходимости — повышения `rich`, `markdown-it-py`, `pygments`, `platformdirs` до версий, попадающих в диапазоны textual.
- Точный набор и версии определяются проверкой разрешимости (deptree/emerge -av) — фиксируется в задачах.
- README.gentoo: раздел-обходной путь про `::guru` заменяется на «textual доступен из babylon_5».

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: новое требование — зависимости monitor-режима разрешимы из оверлея без сторонних репозиториев.

## Impact

- Новые категории/пакеты в оверлее: `dev-python/textual` и closure-пакеты (ebuildы на `distutils-r1` из PyPI, LICENSE MIT и т.д. по метаданным PyPI).
- Возможны bump-ы существующих python-пакетов — проверять обратные зависимости установленных систем.
- `app-ai/strata/files/README.gentoo` — переписывается раздел про textual/guru.
- Установленные системы: новых masked-проблем не ожидается; проверки `emerge -av app-ai/strata[monitor]` достаточно.
