# Tasks

- [x] 1. Создать `app-ai/strata/files/strata-engine-register` (POSIX sh): stamp-файл → выход 0; поиск каталога компонента в `/usr/lib/strata/engine`; отсутствие каталога — тихий выход 0; `strata components add-build` — при ненулевом коде печать в stderr с кодом и выход 0; успех — touch stamp, выход 0.
- [x] 2. В `files/strata.service` заменить `ExecStartPre=@ENGINE_PRE@` на `ExecStartPre=/usr/lib/strata/engine-register` (без `-`-префикса).
- [x] 3. В `src_install`: удалить блок построения `engine_pre`/`sed`-подстановки (строки ~314–331); `sed "s|@EPREFIX@|${EPREFIX}|"` файла хелпера в `${T}`, `into /usr/lib/strata` + `dobin`; `systemd_dounit "${FILESDIR}/strata.service"`.
- [x] 4. Если `visible-engine-reg-pre` ещё не применён — убедиться, что итоговый юнит соответствует его требованию (нет голого `-`, сбой виден в журнале); применить изменения в порядке: сначала то, затем это.
- [ ] 5. Тест успеха: чистое состояние (нет stamp) — `systemctl start strata`, движок зарегистрирован, stamp создан, сервис активен.
- [ ] 6. Тест идемпотентности: повторный `systemctl restart strata` — повторной регистрации нет, сервис активен.
- [ ] 7. Тест сбоя: закрыть `/var/lib/strata` на запись (или убрать каталог движка + stamp) — в `journalctl -u strata` сообщение с кодом возврата, сервис при этом запущен.
- [ ] 8. Тест `USE="-cuda -hip"`: хелпер — тихий no-op, сервер стартует.

Примечание по задаче 3: установка выполнена `exeinto /usr/lib/strata` +
`newexe` (dobin пишет строго в /usr/bin, `into` на него не влияет).
Плейсхолдер @EPREFIX@ не понадобился: хелпер использует абсолютные пути
/usr и /var напрямую — как и сам юнит (ExecStart=/usr/bin/strata),
Prefix-ключей у пакета нет.
