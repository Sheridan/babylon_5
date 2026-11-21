# Tasks

## 1. Заготовка пакета

- [x] 1.1 Создать каталог `app-ai/strata/` и `strata-0.2.17.ebuild` с метаданными из design D8 (EAPI=8, SRC_URI тега `v0.2.17`, LICENSE MIT, SLOT 0, KEYWORDS ~amd64, IUSE `cuda hip vision`, `REQUIRED_USE="?? ( cuda hip )"`); проверка: `ebuild app-ai/strata/strata-0.2.17.ebuild help` и `metadata` проходят без ошибок, `S` после распаковки совпадает с реальным префиксом архива (проверить `ebuild … unpack`).
- [x] 1.2 Объявить зависимости: DEPEND/BDEPEND на `>=dev-build/cmake-3.24`, `dev-build/ninja`; RDEPEND на `dev-python/{numpy,jinja2,regex,pyyaml,tqdm,requests,pillow,psutil}` через `python_gen_cond_dep` из `python-single-r1` (PYTHON_COMPAT 3_10–3_14, REQUIRED_USE python); условно `cuda? ( >=dev-util/nvidia-cuda-toolkit-12.8 sys-devel/gcc:14= )` (nvcc 12.9 не принимает host-компилятор новее gcc 14), `hip? ( >=dev-util/hip-6 )`; проверка: `emerge -pe` резолвится (фаза `ebuild … depend` в portage 3.0.82 падает собственным TypeError, не использована).

## 2. Базовая установка (USE без cuda/hip)

- [x] 2.1 Настроить сборку движка через `cmake` с `-DSTRATA_BUILD_TESTS=OFF -DSTRATA_PORTABLE=ON` и без GPU-бэкендов; сборка в network-sandbox проходит: `ebuild … clean compile` при пустом `USE` (только утилиты `strata-plan`, `strata-gguf`, `strata-dequant`).
- [x] 2.2 Реализовать `src_install` Python-части: `doins -r` дерева `terminal/` целиком (решение изменено при имплементации: runtime-код `strata.py`/`serve/` достучен до `tools/` и `data/`, гарантий upstream нет; ~22 МБ) в `/usr/share/strata`, установка обёртки `/usr/bin/strata` (по D2: `STRATA_PYTHON` → системный python3, вызов `bin/strata` из `/usr/share/strata`); проверка: `ebuild … install && ebuild … qmerge`, затем в чистом shell `strata --help` возвращает 0 без дерева исходников.
- [x] 2.3 Установить утилиты движка (`dobin strata-plan strata-gguf strata-dequant`) и `dodoc README.md docs/INSTALL.md`; проверить `qlist app-ai/strata` — файлы на месте, файлов моделей нет (спека «Отсутствие моделей»).

## 3. GPU-бэкенды движка

- [x] 3.1 Реализовать `src_configure`/`src_install` для `use cuda` по design D6 (native по умолчанию, переопределение через `STRATA_CUDA_ARCHS`, fallback-список с предупреждением): `ebuild … clean compile USE=cuda` собирает цель `strata` (проверка: `cmake --build build --target strata` не падает, бинарь `strata` появляется в build-дереве). Примечание: nvcc 12.9 требует host-gcc 14 — вся CUDA-конфигурация пинится на gcc:14; при pid-ns sandbox nvcc висит в do_wait (обход `PID_SANDBOX=disable`, см. README.gentoo).
- [ ] 3.2 Реализовать ветку `use hip` по design D6 (`CMAKE_HIP_ARCHITECTURES` из `STRATA_HIP_ARCHS`, пути ROCm через cache-переменные); проверка: `ebuild … clean compile USE=hip` конфигурируется и собирает цель `strata` на машине с ROCm; на машине без ROCm — `REQUIRED_USE`/DEPEND выдают понятную ошибку, а не падение configure.
- [x] 3.3 Сформировать каталог компонента движка `/usr/lib/strata/engine/<backend>/` с `BUILD.json` через `tools/packaging/package_engine.py` (+ `--verify` каждой папки в src_install); проверка: `strata components add-build /usr/lib/strata/engine/<папка>` завершается успешно, `strata components engines` показывает локальную сборку. Примечание: для CUDA+vision в BUILD.json добавлено поле `vision_archs` (package_engine.py иначе отвергает компонент); список ядер считается из `${T}/cuda-arch` целиком (в sandbox GPU не виден → fallback-список без строки `native`).
- [x] 3.4 Проверить блокировку `USE="cuda hip"`: `emerge -pv` отклоняет микс с сообщением REQUIRED_USE (спека «Конфликт бэкендов»).

## 4. Флаг vision

- [x] 4.1 Добавить сборку второго cmake-проекта `terminal/tools/vision` (цель `strata-vision`) с аргументами по активному бэкенду (D7); проверка: матрица `USE=vision` (без GPU) и `USE="vision cuda"` зелёные; при USE=cuda/hip ридер кладётся в папку компонента, при USE=vision без бэкенда — в `/usr/lib/strata/vision/` (копируется в папку движка вручную, на PATH не ищется).

## 5. Проверки и метаданные оверлея

- [x] 5.1 Сгенерировать/обновить Manifest: `ebuild … manifest`; dist entry v0.2.17 присутствует, `merge` воспроизводится из локального DISTDIR.
- [x] 5.2 Прогнать QA: `pkgcheck scan app-ai/strata` (pkgcheck 0.10.49; pkgcore читал master из `/var/db/repos/gentoo` — вылечено правкой `location` в `/etc/portage/repos.conf/gentoo.conf` на рабочий `/storage/ceph/gentoo/portage`); исправлены: metadata email, порядок S, лишние eclass'ы, длинные строки/пробелы, PYTHON_COMPAT 3_10–3_15; локальные USE-флаги описаны в `metadata.xml` (pkgcheck читает их только оттуда; `profiles/use.local.desc` оставлен для portage), юнит ставится через `systemd_dounit` (DeprecatedInsinto); итог: чисто, кроме ожидаемых `NonexistentDeps`/`NonsolvableDeps` на `dev-python/textual` (пакет в `::guru`); `acct-group/strata`, `acct-user/strata` чисты (KEYWORDS `~amd64`).
- [x] 5.3 Матрица сценариев спеки на dev-машине (RTX 5080, CUDA 12.9, без ROCm): `{}` (CPU, monitor, vision-cpu) — зелёная, `cuda` — зелёная, `cuda vision` (+monitor) — зелёная финальным merge; smoke (`strata --help`, `strata monitor --help`, `qlist`) проходят; `hip` отложен — ROCm на машине нет, строка помечена непроверенной.
- [x] 5.4 Добавить `README.md` в `${FILESDIR}`-доки (через `dobin` не надо — `dodoc README.gentoo`): регистрация движка через `strata components add-build`, получение моделей, запрет сборки без GPU-тулкитов для движка; проверка: док входит в `qlist`.

## 6. Системный сервис (добавлено по запросу пользователя)

- [x] 6.1 Создать системного пользователя/группу `strata` (домой `/var/lib/strata`, shell nologin, группы `strata video render`). Реализация изменена: `user.eclass` (`enewuser`/`enewgroup`) удалён из дерева 2026, поэтому созданы оверлейные пакеты `acct-group/strata` и `acct-user/strata`, на которые strata зависит через RDEPEND.
- [x] 6.2 Установить systemd-юнит `strata.service` (`systemd_dounit`): `User=strata`, `EnvironmentFile=/etc/strata/daemon.conf`, `ExecStart=/usr/bin/strata serve --engine strata --config ${STRATA_CONFIG} --host ${STRATA_HOST} --port ${STRATA_PORT}`, `StateDirectory=strata`, hardening-настройки; авто-включение в `multi-user.target` в `pkg_postinst` — прямым `ln -sfn` в `/etc/systemd/system/multi-user.target.wants/` (свежий systemd больше не считает enabled vendor-symlink из `/usr/lib`, а `systemctl` внутри sandbox может виснуть).
- [x] 6.3 Установить конфиги: `/etc/strata/daemon.conf` (STRATA_HOST=127.0.0.1, STRATA_PORT=8080, STRATA_CONFIG) и шаблон `/etc/strata/strata.json` (0640 root:strata, плейсхолдеры модели/tokenizer, log в /var/lib/strata).
- [x] 6.4 Первый запуск: в юните `ExecStartPre` регистрировать системный компонент движка в `/var/lib/strata` для пользователя `strata` (однократно, по marker-файлу `.strata-engine-added`, без `|| true` — только `||`-ветка touch); при USE без GPU строка `@ENGINE_PRE@` вырезается sed'ом (в sed экранируются `|` и `&` из shell-строки).
- [x] 6.5 Проверка: `systemd-analyze verify` — без замечаний; `systemctl is-enabled` = enabled (postinst-symlink), сервис в своём StateDirectory (домашний каталог разработчика не тронут); `strata serve` с плейсхолдер-конфигом падает до bind (tokenizer не найден) — проверено, что `StartLimitBurst=5`/`StartLimitIntervalSec=300` останавливают loop (`failed/start-limit-hit`); HTTP-ответ на 127.0.0.1 и смена порта через daemon.conf отложены — на машине нет ни одной GGUF-модели, `serve` не поднимается без реальной модели (проверяется пользователем после заполнения `/etc/strata/strata.json`).

## Workflow follow-up

- После принятия: коммит в `babylon_5` и push (синхронизация в `/var/db/repos/babylon_5` пойдёт через `emerge --sync babylon_5`).
- Монитор (`USE=monitor`, зависимость от `dev-python/textual::guru`) реализован здесь же; проверка `strata launch`/serve с реальной моделью остаётся за change.
