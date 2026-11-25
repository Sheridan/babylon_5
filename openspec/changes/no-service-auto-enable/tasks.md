# Tasks

- [x] 1. Удалить блок автовключения (`ln -sfn .../multi-user.target.wants`) из `pkg_postinst`; сохранить `daemon-reload` при наличии systemd.
- [x] 2. Переписать `elog`: подсказка `systemctl enable --now strata`, без утверждений об «enabled».
- [ ] 3. Тест на чистой системе: `emerge app-ai/strata` → `systemctl is-enabled strata` = `disabled`, сервер не запущен; после `systemctl enable --now strata` — активен и отвечает на localhost.
- [ ] 4. Тест апгрейда: на системе с включённым сервисом пересобрать пакет — состояние `enabled` сохраняется.
