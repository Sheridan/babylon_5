# Why

`src_install` копирует в каталог компонента библиотеки рантайма CUDA/ROCm (строки ~211–232: libnvrtc, библиотеки cublas/torch-обвязки, ROCm-рантайм), при этом `LICENSE="MIT"` описывает только код Strata. По конвенциям Gentoo пакет, устанавливающий проприетарные двоичные компоненты, обязан отражать их лицензии в `LICENSE` и поставлять тексты лицензий в `/usr/share/licenses/<PF>/`.

## What Changes

- Определить лицензии копируемых библиотек (для NVIDIA-компонентов — `NVIDIA-CUDA` из дерева лицензий, для AMD-компонентов — соответствующая: `NCSA-AMD`/`AMD-GPU-PRO-EULA` по факту источника).
- Дополнить `LICENSE` ebuild (например, `LICENSE="MIT cuda? ( NVIDIA-CUDA )"`) и установить тексты лицензий через `dosym`/`dodoc` — из файлов лицензий пакетов-источников тулкетных библиотек.
- Отразить состав в `metadata.xml` (`<comments>` или upstream-секция без изменений).

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: новое требование — комплектование сторонних рантайм-библиотек лицензионно корректно.

## Impact

- `app-ai/strata/strata-0.2.20.ebuild` (LICENSE, доп. установка текстов), `metadata.xml`; содержимое пакета получает файлы лицензий.
