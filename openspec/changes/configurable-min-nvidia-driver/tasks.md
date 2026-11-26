# Tasks

- [x] 1. Ввести `MIN_NVIDIA_DRIVER` в `strata-0.2.20.ebuild`, заменить литерал в `--min-driver`.
- [x] 2. Добавить в README.gentoo короткий раздел о пороге драйвера (происхождение значения, как переопределить, риски).
- [x] 3. Пересобрать `USE=cuda` на тестовой системе (драйвер 575.x) — регистрация движка проходит без изменений поведения.
      (Proгон 26.11: merge с `USE=cuda`, затем `/usr/lib/strata/engine-register` от пользователя
      `strata` с окружением юнита (HOME=/var/lib/strata) на драйвере 595.112.07 — rc=0, повторный
      запуск идемпотентен, `strata components engines` показывает `0.1.66 cuda, local build`.)
