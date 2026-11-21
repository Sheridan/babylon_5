# Design

## Context

Motivation — в proposal.md. Технические ограничения, выявленные при разборе тега `v0.2.17`:

- Три части в одном репозитории: C++ движок (`engine/`, CMake-проект `strata` версии 0.1.63, C++20, `cmake_minimum_required 3.24`), Python-стек (`terminal/`: CLI `bin/strata`, `strata.py`, пакеты `strata_cli/`, `strata_control/`, сервер `serve/` с веб-ассетами и вендоренным KaTeX) и Tauri-приложение (`app/` — вне scope).
- Цель `strata` (движок) определена только внутри `strata_gpu_engine()`, guarded by `STRATA_ENABLE_CUDA OR STRATA_ENABLE_HIP` (`engine/cmake/strata_gpu_engine.cmake`). CPU-only конфигурация движок НЕ производит — только вспомогательные утилиты `strata-gguf`, `strata-dequant`, `strata-plan`.
- Релизные скрипты (`tools/packaging/build_cuda_linux.sh`, `build_hip_linux.sh`) собирают `-DCMAKE_BUILD_TYPE=Release -DSTRATA_BUILD_TESTS=OFF -DSTRATA_PORTABLE=ON`; CUDA требует явный `CMAKE_CUDA_ARCHITECTURES` (иначе «только RTX 50») и sm_80+; HIP передаёт пути ROCm явно (`CMAKE_HIP_COMPILER`, `CMAKE_HIP_COMPILER_ROCM_ROOT`).
- Тесты (`STRATA_BUILD_TESTS=ON` по умолчанию на x86) тянут Catch2 через FetchContent → сетевой загрузке при configure; в ebuild тесты не включаются.
- ggml вендорен в архиве тега (`engine/third_party/…`, подмодулей нет — `.gitmodules` отсутствует) → сборка самодостаточна.
- Запуск CLI: POSIX-обёртка `terminal/bin/strata` находит Python (`$STRATA_PYTHON` → бандл рядом → python3 из PATH ≥3.10) и передаёт управление `strata.py`; runtime-зависимости зафиксированы в `terminal/requirements.txt` (numpy, jinja2, regex, pyyaml, tqdm, requests, pillow, psutil); ядро сервера — stdlib. `terminal/setup.py` — это НЕ PEP 517-метаданные, а dev-установщик upstream: distutils-r1 неприменим.
- Формат «компонента движка» (бинарь + библиотеки + `BUILD.json`) формирует `tools/packaging/package_engine.py`; CLI принимает локальные сборки через `strata components add-build <папка>`.
- Кодировщик изображений `strata-vision` — отдельный CMake-проект `terminal/tools/vision`.
- В CMake CUDA+HIP одновременно → `FATAL_ERROR`; флаги взаимоисключающи.

## Goals / Non-Goals

**Goals:**
- Один ebuild `app-ai/strata-0.2.17`, собираемый из исходников, с корректным Manifest.
- Детерминированное поведение при четырёх профильных конфигураций USE: `{}`, `cuda`, `hip`, `+vision` поверх.
- После установки: `strata` работает из PATH; файлы сервера/веб-UI в системе; движок (при cuda/hip) — в системе и пригоден для регистрации в CLI.

**Non-Goals:**
- Tauri-приложение (`app/`), SYCL/Metal-бэкенды, дистрибуция моделей — вне этого change. Терминальный monitor (`USE=monitor`) и systemd-сервис добавлены по ходу apply (D3, D9).
- `KEYWORDS ~x86`: движок требует AVX2 и sm_80+; 32-битные x86 не целевые.

## Decisions

**D1. Один пакет вместо пары engine/cli.** Версии движка и CLI жёстко связаны общим тегом (0.2.17 → engine 0.1.63), стабильного ABI между ними upstream не гарантирует. Разделение (например `sci-libs/strata-engine` + `app-ai/strata-cli`) потребовало бы двух SRC_URI одного дерева и согласования слотов — отвергнуто. Альтернатива «бинарный ebuild из релизных tar.gz» отвергнута: пользователь хочет сборку из исходников.

**D2. Python-часть — ручная установка дерева, не distutils-r1.** `terminal/setup.py` — dev-скрипт upstream (venv/pip), PyPI-метапакета нет. Решение: `doins -r` дерева `terminal/` (без `tests/`, `bench/`, `crates/`, `data/`) в `/usr/share/strata/`, поверх — логика `bin/strata`: ставим `/usr/bin/strata` — обёртку, выставляющую `STRATA_PYTHON` в системный `python3` (`python_gen_usedep`/PYTHON_COMPAT для построения строки зависимостей, eclass `python-utils-r1`) и вызывающую upstream-обёртку. Обёртка upstream сохраняет поиск по PATH и поведение «без checkout». Тестовый критерий: `strata --help` без дерева исходников.

**D3. Runtime-зависимости Python — через Portage.** RDEPEND: `dev-python/{numpy,jinja2,regex,pyyaml,tqdm,requests,pillow,psutil}`; pip-пины upstream игнорируются (берутся версии дерева). Флаг `monitor` (RDEPEND на `dev-python/textual`) введён по ходу apply и включён по умолчанию (`IUSE_DEFAULTS="monitor"`): в Portage-tree textual отсутствует, взводится из `::guru` (`~amd64`); pkgcheck честно ругается `NonexistentDeps` — ожидаемо для меж-оверлейной зависимости.

**D4. USE-флаги:** `cuda`, `hip`, `vision`; `REQUIRED_USE="?? ( cuda hip )"`; `vision` не требует GPU-бэкенда (CPU-кодировщик существует: `STRATA_VISION_CUDA=OFF` в релизных скриптах). Без cuda/hip ebuild собирает и ставит утилиты движка (`strata-plan` и др.) + Python-стек; отсутствие бинаря `strata` объясняется в `pkg_postinst` (получение движка — штатный рантайм-механизм Strata). Альтернатива `REQUIRED_USE="|| ( cuda hip )"` отвергнута: ломает выбор пользователя «оба off by default» и делает пакет неустанавливаемым без тулкитов.

**D5. Движок — cmake.eclass, тесты выключены всегда.** `-DSTRATA_BUILD_TESTS=OFF` (Catch2 через FetchContent противоречит network-sandbox; IUSE `test` не вводим — риск недетерминированных сетевых сборок). `DESTDIR`-установка отсутствует в CMake upstream → `src_install` ставит бинари вручную (`dobin`/`into /usr/lib/strata/engine`), включая генерацию каталога компонента: запускаем `tools/packaging/package_engine.py` (stdlib Python) над build-деревом для корректного `BUILD.json`; итог — `/usr/lib/strata/engine/<backend>/{strata,BUILD.json,…}`. Регистрация — вручную пользователем: `strata components add-build /usr/lib/strata/engine/<backend>` (текст в `pkg_postinst` и `README` в `${FILESDIR}`/doc). Компромисс: глобальной точки регистрации движка upstream не имеет — компонентная модель пользовательская.

**D6. CUDA-архитектуры:** по умолчанию `-DCMAKE_CUDA_ARCHITECTURES=native` (Gentoo собирает на целевой машине); переменная окружения/`package.env` `STRATA_CUDA_ARCHS` переопределяет (например `"86;89;120"`); если native недоступен (сборка без GPU), ebuild подставляет conservative-список `"80;86;89;120"` и печатает echo-предупреждение. HIP: `CMAKE_HIP_ARCHITECTURES` из `STRATA_HIP_ARCHS` (по умолчанию `gfx1100;gfx1201`), пути ROCm через `CMAKE_HIP_COMPILER=${EPREFIX}/usr/lib/llvm/...` — конкретные пути проверяются на этапе apply.

**D7. `vision`:** второй cmake-проект `terminal/tools/vision`, цель `strata-vision`; аргументы по бэкенду: `cuda? (-DSTRATA_VISION_CUDA=ON)`, `hip? (-DSTRATA_VISION_HIP=ON + архи)`, иначе CPU-кодировщик. Бинарь — в `/usr/lib/strata/engine/` рядом с движком (как в релизной упаковке).

**D8. Прочее:** EAPI=8; `LICENSE=MIT`; `SLOT=0`; `KEYWORDS="~amd64"`; `inherit cmake python-utils-r1`; SRC_URI — `https://github.com/Niko1221/Strata/archive/refs/tags/v0.2.17.tar.gz -> ${P}.tar.gz` (единый архив на все USE-конфигурации); `S=${WORKDIR}/Strata-0.2.17` (проверить префикс на этапе распаковки).

**D9. Системный сервис (добавлено по ходу apply):** пользователь/группа `strata` — пакетами `acct-group/strata` + `acct-user/strata` (домой `/var/lib/strata`, shell nologin, группы `strata video render`); `user.eclass` с `enewuser`/`enewgroup` удалён из дерева 2026, acct-пакеты — штатная замена. Юнит `strata.service` из `${FILESDIR}` ставится `systemd_dounit`; в нём подстановка `@ENGINE_PRE@` (sed в src_install: `||` и `&&` в shell-строке экранируются; при USE без GPU строка вырезается целиком) и `EnvironmentFile=/etc/strata/daemon.conf`: `User/Group=strata`, `Environment=HOME=/var/lib/strata`, `StateDirectory=strata` (0750), `ExecStart=/usr/bin/strata serve --engine strata --config ${STRATA_CONFIG} --host ${STRATA_HOST} --port ${STRATA_PORT}`, `ExecStartPre` — однократная регистрация компонента движка в `/var/lib/strata` по marker-файлу, hardening (`NoNewPrivileges`, `ProtectSystem=strict`, `ProtectHome`, `ReadWritePaths=/var/lib/strata`, `SupplementaryGroups=video render`), `Restart=on-failure`. Конфиги: `daemon.conf` (STRATA_HOST=127.0.0.1, STRATA_PORT=8080, STRATA_CONFIG=/etc/strata/strata.json) и шаблон `strata.json` (keys по схеме setup.py: exe/args/cwd/tokenizer/model_name/log/port; `exe=component:strata-engine`, пути модели — плейсхолдеры REPLACE; 0640 root:strata). Авто-включение: `systemd_enable_service` (dosym в `/usr/lib`) свежий systemd enabled не показывает (vendor-symlinks игнорируются, `is-enabled=disabled`), а `systemctl` в sandbox pkg_postinst может виснуть — поэтому в postinst прямой `ln -sfn` в `/etc/systemd/system/multi-user.target.wants/` под `[[ -d /run/systemd/system ]]`. Серверные данные живут только в `/var/lib/strata` — изоляция от домашних установок (см. спеку «Изоляция от пользовательских установок»).

## Risks / Trade-offs

- [CPU-only merge без движка может surprise-нуть] → явное сообщение `pkg_postinst`; спецификация фиксирует это как ожидаемое поведение.
- [Upstream-обёртка `bin/strata` может ожидать соседства с деревом `terminal/`] → ставим дерево целиком в `/usr/share/strata`, обёртка вызывает `bin/strata` из него; smoke-тест `strata --help` в задачах.
- [`package_engine.py` может требовать поля, извест only в CI (build-id, нотисы)] → fallback: генерировать `BUILD.json` минимальным JSON из ebuild (version=0.1.63, backend, archs) и проверять принятие CLI через `strata components add-build`; при отказе CLI — документировать прямой запуск бинаря.
- [HIP-тулкит Gentoo отличается от путей релизных скриптов ROCm] → переменные кэша CMake задаёт ebuild; при неуспехе HIP-бэкенд остаётся experimental-флагом, не блокируя default/cuda.
- [Версии Python-библиотек в дереве Gentoo старше pip-пинов] → зависимости указываем без жёстких версий, конфликты ловятся на этапе merge-теста; при реальном конфликте — slotted зависимости в следующем change.
- [Движок живёт в per-user components, не в системе] → принимаем модель upstream; ebuild поставляет готовый каталог компонента.

## Open Questions

- ~~systemd-юнит для сервера~~ и ~~флаг `monitor`~~ — решены внутри этого change (D9, D3). Открытым остаётся только HIP-прогон на реальном ROCm.
