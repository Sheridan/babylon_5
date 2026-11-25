# Design

## Context

В ebuild: vision конфигурируется `-DSTRATA_VISION_HIP=ON` при HIP и CUDA-архитектурами при CUDA; целевое имя — `strata-vision`/`strata-vision-hip`. Значит флаг тянет зависимости выбранного GPU-бэкенда, а не только CUDA.

## Goals / Non-Goals

**Goals:** точный текст флага.
**Non-Goals:** не переименовывать флаг (совместимость USE-настроек).

## Decisions

- Текст: `Build the vision encoder for the selected GPU backend (CUDA or HIP)`. Для локалей — тот же смысл. Альтернатива «CUDA-only» — неверно для HIP-сборок.

## Risks / Trade-offs

- Нет.
