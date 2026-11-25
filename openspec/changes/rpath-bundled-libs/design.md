# Design

## Context

Distfiles-смонтированный бинарный тест прервался (том `/var/git/babylon_5-distfiles` отваливался), аудит NEEDED не выполнялся — наличие проблемы не подтверждено. Известно: `$ORIGIN` задавался только для `CMAKE_EXE_LINKER_FLAGS`; юнит `strata.service` не определяет `LD_LIBRARY_PATH`; runtime-библиотеки укладываются в каталог компонента.

## Goals / Non-Goals

**Goals:** детерминированный запуск движка/визона из `/usr/lib/strata/*` без env.
**Non-Goals:** не переводить библиотеки в `/usr/lib64` (конфликт с системными тулкитами).

## Decisions

- Сначала аудит: `objdump -p` (NEEDED + RUNPATH) и `ldd` для каждого ELF компонента при пустом `LD_LIBRARY_PATH`; решение о правке — по факту.
- При подтверждении пробела: `-DCMAKE_SHARED_LINKER_FLAGS='-Wl,-rpath,$ORIGIN:$ORIGIN/../lib'` и аналогично exe; формат пути подобрать по фактической раскладке компонента.

## Risks / Trade-offs

- Изменение runpath не влияет на содержимое системных каталогов; риск — лишний rpath у библиотек, которые его не требуют (безвредно).
