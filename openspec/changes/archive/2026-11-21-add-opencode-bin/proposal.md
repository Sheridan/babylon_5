# Proposal: add-opencode-bin

## Why

Заказчик использует AI-агент opencode (https://opencode.ai) с вручную скачанным бинарником (`~/software/AI/opencode/opencode` + symlink в `/usr/local/bin`) — без версионирования, без контроля зависимостей, обновления «на глаз». Нужен пакет в оверлее `babylon_5`, чтобы установка/обновление шли штатными средствами Portage.

Исходники opencode (Bun/TypeScript, самосборный bun-ELF) в Gentoo не компилируются практично — upstream сам поставляет готовые релизные бинарники под все нужные профили, поэтому поставка бинарная (`-bin`).

## What Changes

- Новый пакет `app-ai/opencode-bin` в оверлее `babylon_5`: установка self-contained бинарника `opencode` из GitHub Releases (версия 1.19.6), KEYWORDS `~amd64`, варианты glibc/musl и x64 baseline/native (`IUSE="baseline"`).
- Runtime-зависимости: `sys-apps/ripgrep`, `dev-vcs/git` (вызываются агентом в рантайме).
- Состав установки ограничен `/usr/bin/opencode` + LICENSE в `/usr/share/doc`: никаких systemd-юнитов, системных пользователей, конфигов и postinst-интеграции — сервер (`opencode serve`/`opencode web`) пользователь запускает вручную.
- Out of scope: автозапуск/systemd-юнит (реализовывался в рамках change и удалён по решению заказчикa 2026-11-21), интеграция openspec (будет отдельный change), `~arm64`.

## Capabilities

### New Capabilities
- `opencode-packaging`: поведение пакета `app-ai/opencode-bin` в оверлее `babylon_5` — состав бинарной поставки, варианты ассетов, зависимости и отсутствие системной интеграции.

## Impact

- **Overlay**: новый `app-ai/opencode-bin/` (ebuild, metadata.xml, Manifest); `profiles/categories` не меняется (`app-ai` уже есть).
- **Система**: `/usr/bin/opencode` + документация; ACCEPT_KEYWORDS-запись `/etc/portage/package.accept_keywords/app-ai` (добавлена на apply).
- **Ручная установка заказчикa**: требует удаления `/usr/local/bin/opencode`, иначе она затеняет пакетную копию в PATH (follow-up).
- **Риски**: переименование релизных ассетов upstream'ом ловится digest-проверкой на bump.
