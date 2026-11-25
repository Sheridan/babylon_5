# Why

Описание флага `vision` в `metadata.xml` и `profiles/use.local.desc` — «Build the CUDA vision encoder component». Фактически vision собирается и с HIP (`STRATA_VISION_HIP`, `strata-vision-hip`), а OpenCL к нему отношения не имеет; в исходном ревью описание значилось как «OpenCL-кодировщик» — расхождение метаданных с реальными зависимостями путает пользователей при выборе флагов.

## What Changes

- Уточнить описания в `metadata.xml` и `use.local.desc`: флаг добавляет CUDA- или HIP-зависимости в зависимости от выбранного бэкенда.

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: требование «Опциональный кодировщик изображений» — описания флага соответствуют зависимостям.

## Impact

- `app-ai/strata/metadata.xml`, `profiles/use.local.desc`; контент только текстовый.
