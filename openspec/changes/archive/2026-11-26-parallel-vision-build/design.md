# Design

## Context

Основной движок собирается `cmake_src_compile`, который сам подставляет параллелизм из `MAKEOPTS`. Второй прогон — ручная команда `cmake --build` для vision — параметра параллелизма не имеет.

## Goals / Non-Goals

**Goals:** параллельная сборка vision с учётом MAKEOPTS.
**Non-Goals:** не распараллеливать configure; не менять target-состав.

## Decisions

- Использовать `makeopts_jobs` (eportage bash-completion `multiprocessing`-хелперов: `$(makeopts_jobs)`) и передать `cmake --build ... --parallel N`. Альтернатива `--parallel` без числа (CMake сам по CPU count) — отвергнута: игнорирует `-jN` из MAKEOPTS.

## Risks / Trade-offs

- Пик памяти при параллельной сборке CUDA-единиц выше; для целевых машин разработки приемлемо (MAKEOPTS пользователь контролирует).
