# Tasks

- [x] 1. Составить инвентарь копируемых библиотек (cuda- и hip-сборки) и определить их лицензии по пакетам-источникам (`equery b`, файлы в `/usr/share/licenses`).
  Инвентарь (по `src_install` и `tools/packaging/`): CUDA-сборка несёт `libcudart`, `libcublas`, `libcublasLt`,
  `libnvrtc` и транзитивное NEEDED-замыкание из `/opt/cuda/**` (dev-util/nvidia-cuda-toolkit, `LICENSE="NVIDIA-CUDA"`,
  бинарные); HIP-сборка — `libhiprtc*`, `libhipblas*`, `libamd_comgr` и замыкание из `/opt/rocm/**`, которые в Gentoo
  собираются из исходников под MIT (dev-util/hip, dev-libs/rocm-comgr: `LICENSE="MIT"`); дополнительно system-библиотеки
  переносимости `libatomic.so.1`/`libz.so.1` с upstream-уведомлениями в `tools/packaging/notices/`. vision биндит только
  cublas/cudart (или hipblas/hipblaslt) — cuDNN в комплект не попадает. AMD-GPU-PRO-EULA не подходит: он на бинарную
  PRO-редакцию ROCm, а не на эти пакеты.
- [x] 2. Обновить `LICENSE` ebuild с USE-кондишеналами; проверить валидность идентификаторов против `/var/db/repos/gentoo/licenses/`.
- [x] 3. Установить тексты лицензий в `/usr/share/licenses/strata-<PF>/` (или иной принятый в оверлее путь) для каждой группы бинарных компонентов.
  Реализовано двояко: тексты едут внутри папки компонента (`package_engine.py` пакует топ-левел `LICENSE*`:
  `LICENSE.txt` — MIT Strata, `LICENSE-CUDA-EULA.txt` — EULA тулкита сборки с фолбэком-ссылкой,
  `LICENSE-libatomic.txt`/`LICENSE-libz.txt` — upstream-уведомления, `LICENSE-BUNDLED.txt` — инвентарь каждой .so по
  группам лицензий), и те же файлы ставятся в `/usr/share/licenses/${PF}/`.
- [x] 4. Дополнить `metadata.xml` (`<comments>`: пакет включает рантайм-библиотеки CUDA/ROCm).
- [ ] 5. `pkgcheck scan app-ai/strata` — замечаний по LICENSE/лицензиям нет; пересобрать `USE=cuda` и (при доступности ROCm) `USE=hip`.
  pkgcheck чист; проверка `USE="cuda vision monitor"` сборкой `--buildpkgonly` идёт; ROCm на хосте нет — hip-ветка
  не проверяется live (тексты/инвентарь для неё общие по коду).
