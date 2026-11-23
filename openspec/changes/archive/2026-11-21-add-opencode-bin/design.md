# Design

## Context

Оверлей `babylon_5` (Gentoo) должен поставлять AI-агент opencode как готовый бинарник: upstream релизует self-contained ELF (сборка `bun build --compile`) на GitHub Releases, исходники (Bun/TypeScript) в Portage не собираются практично. Заказчик использует opencode локально (`opencode serve` / `opencode web` + браузер) и запускает сервер вручную по мере надобности.

Хронология объёма: первоначально change включал per-user systemd user-юнит с env-файлом и документацию; 2026-11-21 заказчик отказался от автозапуска — юнит, `README.gentoo` и `pkg_postinst` удалены из пакета, остаточный объём — только бинарная поставка.

## Decisions

### D1. Бинарная поставка, варианты ассетов
`EAPI=8`, SRC_URI из `https://github.com/anomalyco/opencode/releases/download/v${PV}` под переименованные distfiles `${P}-linux-x64[-baseline][-musl].tar.gz`; выбор варианта: `amd64?` × `elibc_glibc/elibc_musl` × `IUSE="baseline"`. Архив плоский (бинарник `opencode` в корне) — `dobin opencode`. `RESTRICT="strip"` (bun-ELF нельзя стрипать). Отдельный distfile `LICENSE` с тега — `newdoc`.

### D2. Никакой системной интеграции (скоуп-редукция 2026-11-21)
Нет acct-user, `/var/lib/opencode`, `/etc/opencode`, systemd-юнитов, env-файлов, postinst-сообщений. Модель: пользователь сам решает, когда и в каком каталоге проекта запускать `opencode`/`opencode web`. Пакет на это не влияет. (Реализованный ранее user-юнит с `EnvironmentFile=%h/.config/opencode/server.env` удалён; при возвращении запроса на автозапуск — отдельный change.)

### D3. Зависимости
Только `RDEPEND="dev-vcs/git sys-apps/ripgrep"` (агент вызывает в рантайме). Собственных libc/bun-зависимостей у статически упакованного ELF нет.

### D4. QA оверлея
`KEYWORDS="~amd64"` (принят через `/etc/portage/package.accept_keywords/app-ai`). `metadata.xml` по образцу `app-ai/strata` (maintainer проекта, upstream-remote-id `github.com/anomalyco/opencode`, описание флага `baseline`). `repoman` в системе отсутствует — QA-гейт: `pkgcheck scan`; Manifest — `ebuild … digest`.

## Risks / Trade-offs

- [R1] Upstream может менять имена ассетов между версиями → digest-проверка ловит проблему на bump; имена зафиксированы в SRC_URI.
- [R2] Ручная установка opencode (`/usr/local/bin/opencode`) затеняет пакетную в PATH — без postinst-предупреждения; устраняется удалением ручной установки (follow-up заказчикa).
- [R3] `~arm64` не keyworded — ассеты arm64 у релиза есть, добавляется при первом bump по запросу.

## Migration Plan

1. `emerge app-ai/opencode-bin` → `/usr/bin/opencode`.
2. Заказчик удаляет ручную установку (`/usr/local/bin/opencode` → `~/software/AI/opencode`), после чего в PATH побеждает пакет.
3. Откат: `emerge -C app-ai/opencode-bin`; пакет ничего пользовательского не создавал, чистить нечего.

## Open Questions

- Нет (вопрос юнита закрыт отказом заказчика).
