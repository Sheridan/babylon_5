# Tasks

- [x] 1. В `src_compile` заменить сборку vision на `cmake --build "${VISION_BUILD}" --target "${vtarget}" --parallel "$(makeopts_jobs)"`.
- [ ] 2. Пересобрать `USE="cuda vision"` на тестовой системе: сборка многопоточная (`htop`/`ninja` логи), время заметно меньше предыдущего прогона.
- [ ] 3. Проверить `strata-vision` в составе пакета (`qlist`), регрессий нет.
