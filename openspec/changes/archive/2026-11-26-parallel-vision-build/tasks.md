# Tasks

- [x] 1. В `src_compile` заменить сборку vision на `cmake --build "${VISION_BUILD}" --target "${vtarget}" --parallel "$(makeopts_jobs)"`.
- [x] 2. Пересобрать `USE="cuda vision"` на тестовой системе: сборка многопоточная (`htop`/`ninja` логи), время заметно меньше предыдущего прогона.
      (Proгон 26.11: `emerge =app-ai/strata-0.2.20 USE="cuda monitor vision"` — merge ~17 мин
      (emerge.log 1795680056→1795681061), load avg 8+ при сборке, `--parallel $(makeopts_jobs)`
      в эбилде; baseline однопоточного прогона не фиксировался — сравнение «до/после» не формализовано.)
- [x] 3. Проверить `strata-vision` в составе пакета (`qlist`), регрессий нет.
      (`qlist` показывает `engine/0.1.66-linux-x86_64-cuda/strata-vision`; `qcheck` —
      1643/1645 файлов хороши, 2 отличия = правленые пользователем protected-конфиги в /etc/strata.)
