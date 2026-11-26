# Tasks

- [x] 1. Удалить блок автовключения (`ln -sfn .../multi-user.target.wants`) из `pkg_postinst`; сохранить `daemon-reload` при наличии systemd.
- [x] 2. Переписать `elog`: подсказка `systemctl enable --now strata`, без утверждений об «enabled».
- [ ] 3. Тест на чистой системе: `emerge app-ai/strata` → `systemctl is-enabled strata` = `disabled`, сервер не запущен; после `systemctl enable --now strata` — активен и отвечает на localhost.
      (Половина «не авковключает» подтверждена 26.11: merge ничего не пишет в /etc/systemd
      (`grep -c etc/systemd CONTENTS` = 0), postinst только `daemon-reload` + elog; leftover-симлинк
      wants датирован 25.11 (ручное включение пользователем), `is-active` = inactive. Половина
      «enable --now → отвечает на localhost» не выполнялась по ограничению «без старта сервиса».)
- [x] 4. Тест апгрейда: на системе с включённым сервисом пересобрать пакет — состояние `enabled` сохраняется.
      (Состояние `enabled` (симлинк wants от 25.11) пережило merge 26.11: после сборки
      `systemctl is-enabled` = enabled, эбилд к /etc/systemd не обращается.)
