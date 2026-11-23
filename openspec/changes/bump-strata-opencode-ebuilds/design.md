# Design

## Context

Оба пакета живут в оверлее `babylon_5` (этот репозиторий — Gentoo overlay, priority 10, masters = gentoo). Текущее состояние:

- `app-ai/strata/strata-0.2.17.ebuild` — сборка из исходного архива тега (`archive/refs/tags/v${PV}.tar.gz`), жёстко завязан на layout дерева: `engine/` (cmake), `terminal/` (установка Python-терминала целиком), `tools/packaging/package_engine.py` (компонент движка), `terminal/tools/vision`. Файлы `files/` (юнит, конфиги, `library_check.py`, README.gentoo) — наши, не upstream.
- `app-ai/opencode-bin/opencode-bin-1.19.6.ebuild` — бинарная поставка из ассетов релиза с ветвлением `elibc`/`baseline`; лицензию брал ассетом `${UPSTREAM_URI}/LICENSE`.
- Release notes Strata 0.2.18–0.2.20 — только новые модели/кванты; перестройки layout не объявлено (крупное перемещение папок было в 0.2.16, эбилд ему уже соответствует). У релиза opencode v2.4.1 ассеты linux-x64 named identично 1.x, но LICENSE-ассета нет (проверено по API релиза).

## Goals / Non-Goals

**Goals:**
- В оверлее актуальные версии: `strata-0.2.20`, `opencode-bin-2.4.1`; обе собираются/устанавливаются.
- Эбилды остаются однострочными поdiff от предыдущих версий (минимальный дрейф).

**Non-Goals:**
- Не трогаем `app-ai/openspec-bin` (2.1.1 == upstream).
- Не добавляем shell-completion для opencode (это есть в guru-эбилде, но противоречит нашему требованию «только бинарник» в части состава — оставляем как есть).
- Не вводим новые USE-флаги и не меняем зависимости, пока сборка/запуск не покажет обратное.

## Decisions

1. **Одна версия в оверлее, старую удаляем.** Хранить обе версии в оверлее не принято: SLOT=0, Portage сам выберет 0.2.20; старый эбилд только плодит поддержку Manifest. Альтернатива (оставить 0.2.17 рядом) отвергнута.
2. **LICENSE opencode: raw-файл репозитория на теге.** `SRC_URI` дополняется: `https://github.com/anomalyco/opencode/raw/v${PV}/LICENSE -> ${P}-LICENSE` (HEAD-запрос на этот путь для v2.4.1 отдаёт редирект на контент, т.е. файл существует). Альтернативы: LICENSE внутри tar.gz — непредсказуемо, ассета нет; лицензия без текста — нарушает текущий состав пакета (`newdoc LICENSE`).
3. **strata: копия эбилда с новым PV, без правок.** Layout paths проверяем на распакованном tarball до merge (см. риски); при поломке пути — правим эбилд точечно, это уже инцидент применения, не план.
4. **Версии — максимум upstream, а не ветка из guru.** opencode 2.4.1 (guru отстаёт: 2.2.7); имена ассетов linux-x64 для нашего SRC_URI-шаблона идентичны версии 1.x.

## Risks / Trade-offs

- [Strata 0.2.20 мог сдвинуть layout (cmake-цели `strata-gguf`/`strata-dequant`/`strata-plan`, `tools/packaging`, `terminal/tools/vision`)] → до merge проверить наличие путей в распакованном исходнике и `ebuild ... compile` с текущим набором USE (включая `hip` — машина с ROCm, и опционально `vision`).
- [Python-зависимости strata могли измениться в 0.2.18–0.2.20] → сравнить импорт-требования терминала после распаковки; при появлении новых — добавить в RDEPEND точечно.
- [opencode 2.x мог потребовать новые runtime-инструменты] → smoke-тест после merge: `opencode --version`, запуск сессии; при жалобах — разбор `strace`/сообщений, зависимость добавляется потом отдельной задачей.
- [raw.githubusercontent может отдавать LICENSE без redirect-ловушек для distfile] — `fetch` в Portage следует редиректам; digest фиксируется в Manifest.

## Migration Plan

1. Положить новые эбилды, удалить старые, `ebuild ... manifest` для обеих категорий.
2. `emerge -1av app-ai/strata app-ai/opencode-bin` на машине пользователя; дgest'ы из нового Manifest.
3. Smoke: `strata --help`, `systemctl status strata`, `opencode --version`.
4. Откат — `git revert` коммита оверлея + повторный emerge старых версий.

## Open Questions

(нет)
