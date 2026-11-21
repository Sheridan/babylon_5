# Proposal

## Why

Strata (https://github.com/Niko1221/Strata) — локальный LLM-стек с OpenAI/Anthropic-совместимым API и веб-интерфейсом на localhost — сегодня ставится только через AppImage/upstream-установщик, что несовместимо с моделью Gentoo. Пользователю нужен системный пакет, собираемый из исходников и управляемый Portage.

## What Changes

- Новый пакет `app-ai/strata` (ebuild + Manifest) в оверлее `babylon_5`, версия 0.2.17 (tag `v0.2.17`, engine 0.1.63), лицензия MIT.
- Сборка C++ inference-движка (`strata`, CMake ≥ 3.24, C++20) из `engine/` с GPU-бэкендами через USE-флаги: `cuda` и `hip` (оба выключены по умолчанию, взаимоисключающие через `REQUIRED_USE`).
- Установка Python-компонентов (CLI `strata`, сервер `serve/` с веб-интерфейсом на localhost, OpenAI/Anthropic API) из `terminal/` системным python3.10+ c зависимостями из Portage (numpy, jinja2, regex, pyyaml, tqdm, requests, pillow, psutil), без pip/venv.
- Опциональный флаг `vision` — сборка кодировщика изображений `strata-vision` (из `terminal/tools/vision`) для ввода картинок в веб-интерфейсе.
- Флаг `monitor` (по умолчанию включён): RDEPEND на `dev-python/textual` для TUI `strata monitor`; пакет берётся из `::guru`.
- Системный режим сервера (добавлено по ходу apply): пользователь `strata`, systemd-юнит `strata.service` (`strata serve` с web-доступом, host/port из `/etc/strata/daemon.conf`), конфигурация сервера `/etc/strata/strata.json`, данные сервиса в `/var/lib/strata`.
- Вне области этого change: Tauri-desktop приложение (`app/`), бинарные ebuild релизных архивов, SYCL/Metal-бэкенды, model packs (модели скачивает сам `strata launch`).

## Capabilities

### New Capabilities

- `strata-packaging`: поведение сборки и установки пакета `app-ai/strata` в оверлее — варианты сборки движка по USE-флагам, состав устанавливаемых файлов, зависимости и проверяемое поведение после установки (CLI отвечает, сервер поднимает веб-интерфейс).

### Modified Capabilities

_(нет — каталог `openspec/specs/` пуст, существующие спецификации не затрагиваются)_

## Impact

- Новая категория/дерево `app-ai/strata/` в репозитории (категория `app-ai` появится в оверлее впервые — её нет в дереве Gentoo, что для оверлея допустимо).
- Новые зависимости Portage-tree для RDEPEND/DEPEND: `dev-python/{numpy,jinja2,regex,pyyaml,tqdm,requests,pillow,psutil}`, `>=dev-build/cmake-3.24`, `dev-build/ninja`; условно `cuda? ( dev-util/cuda-toolkit )`, `hip? ( dev-util/hip )`, `monitor? ( dev-python/textual из ::guru )`.
- Новые оверлейные пакеты `acct-group/strata` и `acct-user/strata` (пользователь/группа сервиса; `user.eclass` удалён из дерева 2026).
- Движок использует вендоренный ggml из `third_party/strata-ggml` — сетевая загрузка при сборке не нужна, кроме тестового Catch2 (тесты в ebuild не включаются).
- Конфликт USE-флагов: CUDA и HIP в CMake взаимоисключающи (`FATAL_ERROR`) — оформляется `REQUIRED_USE`.
