# Why

В `src_compile` компонент vision собирается командой `cmake --build "${VISION_BUILD}" --target ...` без `-j` (строка ~155): CMake по умолчанию собирает в один поток, что растягивает сборку vision-кодировщика на десятки минут на многоядерных машинах и игнорирует `MAKEOPTS`.

## What Changes

- Добавить `--parallel`/`${MAKEOPTS}`-совместимую параллелизацию в сборку vision (например, `cmake --build ... --parallel "$(makeopts_jobs)"`).

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: требование «Опциональный кодировщик изображений» — сборка учитывает MAKEOPTS.

## Impact

- Только ebuild; время сборки `USE=vision` сокращается, содержимое пакета не меняется.
