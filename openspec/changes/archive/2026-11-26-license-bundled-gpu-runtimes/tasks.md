# Tasks

- [x] 1. Составить инвентарь копируемых библиотек (cuda- и hip-сборки) и определить их лицензии по пакетам-источникам (`equery b`, файлы в `/usr/share/licenses`).
  Инвентарь подтверждён сборкой `USE="cuda vision monitor"` (`--buildpkgonly`): CUDA-компонент нёс `libcublas.so.13`,
  `libcublasLt.so.13`, `libcudart.so.13` (замыкание NEEDED из `/opt/cuda/**`; `libnvrtc` — кандидат `collect_libs.py`,
  в финальное замыкание не вошёл), от `dev-util/nvidia-cuda-toolkit`, `LICENSE="NVIDIA-CUDA"` (бинарные, EULA);
  cuDNN не биндится. HIP-сборка — `libhiprtc*`, `libhipblas*`, `libamd_comgr` и замыкание из `/opt/rocm/**`, которые в
  Gentoo собираются из исходников под MIT (dev-util/hip, dev-libs/rocm-comgr: `LICENSE="MIT"`); system-библиотеки
  переносимости `libatomic.so.1`/`libz.so.1` (в этой сборке не потребовались) с upstream-уведомлениями в
  `tools/packaging/notices/`. AMD-GPU-PRO-EULA не подходит: он на бинарную PRO-редакцию ROCm, а не на эти пакеты.
- [x] 2. Обновить `LICENSE` ebuild с USE-кондишеналами; проверить валидность идентификаторов против `/var/db/repos/gentoo/licenses/`.
- [x] 3. Установить тексты лицензий в `/usr/share/licenses/strata-<PF>/` (или иной принятый в оверлее путь) для каждой группы бинарных компонентов.
  Реализовано двояко: тексты едут внутри папки компонента (`package_engine.py` пакует топ-левел `LICENSE*`:
  `LICENSE.txt` — MIT Strata, `LICENSE-CUDA-EULA.txt` — EULA тулкита сборки с фолбэком-ссылкой,
  `LICENSE-libatomic.txt`/`LICENSE-libz.txt` — upstream-уведомления, `LICENSE-BUNDLED.txt` — инвентарь каждой .so по
  группам лицензий), и те же файлы ставятся в `/usr/share/licenses/${PF}/`. Генерация инвентаря
  исправлена: при отсутствии собственных `.so` второй `printf` печатал строку из одного таба —
  теперь один `printf` со списком аргументов (проверено харнессом на пустом и непустом массивах).
- [x] 4. Дополнить `metadata.xml` (`<comments>`: пакет включает рантайм-библиотеки CUDA/ROCm).
- [x] 5. `pkgcheck scan app-ai/strata` — замечаний по LICENSE/лицензиям нет; пересобрать `USE=cuda` и (при доступности ROCm) `USE=hip`.
  pkgcheck чист. Сборка `USE="cuda vision monitor"` (`--buildpkgonly`) подтвердила: компонент несёт `LICENSE.txt`,
  `LICENSE-CUDA-EULA.txt` (82 КБ, из `/opt/cuda/EULA.txt`), `LICENSE-BUNDLED.txt` (инвентарь по группам), и те же тексты
  в `/usr/share/licenses/strata-0.2.20/`; `readelf -d` — RUNPATH `$ORIGIN` у `strata` и `strata-vision`. ROCm на хосте
  нет — hip-ветка не проверяется live (тексты/инвентарь для неё общие по коду).
