# Tasks

> Объём сужен 2026-11-21: systemd user-юнит, `README.gentoo` и `pkg_postinst`, реализованные ранее, удалены из пакета по решению заказчикa (запуск сервера — вручную). Задачи ниже отражают итоговый объём.

## 1. Пакет

- [x] 1.1 Скачать ассеты релиза `v1.19.6` (`opencode-linux-x64.tar.gz`, `-baseline`, `-musl`-варианты), проверить структуру архива через `tar tzf` и сверить sha256 с GitHub API; критерий: путь бинарника зафиксирован (плоский, в корне), `./opencode --version` из распакованного native-архива печатает `1.19.6`
- [x] 1.2 Создать `app-ai/opencode-bin/opencode-bin-1.19.6.ebuild`: EAPI=8, SRC_URI по `amd64` × `elibc_glibc/elibc_musl` × `IUSE="baseline"` + отдельный distfile `LICENSE`, `RESTRICT="strip"`, `RDEPEND="dev-vcs/git sys-apps/ripgrep"`, `LICENSE=MIT`, `KEYWORDS="~amd64"`, `src_install` = `dobin opencode` + `newdoc LICENSE`, без юнитов/postinst; критерий: `ebuild … digest` без ошибок
- [x] 1.3 Создать `metadata.xml` (longdescription, `upstream-remote-id` `github.com/anomalyco/opencode`, maintainer по образцу `app-ai/strata`, описание `baseline`); критерий: `xmllint --noout` проходит

## 2. QA оверлея

- [x] 2.1 Сгенерировать Manifest (`ebuild … digest`); критерий: четыре DIST entries ассетов + LICENSE, AUX entries отсутствуют (`files/` в пакете нет)
- [x] 2.2 Прогнать `pkgcheck scan app-ai/opencode-bin` (repoman в системе отсутствует — задокументировано в design D4); критерий: замечаний нет

## 3. Системная проверка

- [x] 3.1 Установить `emerge =app-ai/opencode-bin-1.19.6`; критерий: `qlist` показывает только `/usr/bin/opencode` и `/usr/share/doc/${PF}/LICENSE`; `/usr/bin/opencode --version` = `1.19.6`; `git` и `rg` в системе
- [x] 3.2 Проверить отсутствие системной интеграции: `getent passwd opencode` пусто, `/var/lib/opencode`, `/etc/opencode`, `opencode.service` (system и user каталоги) отсутствуют; после удаления ранее ставившихся юнита/README повторный merge не оставляет «хвостов»
- [x] 3.3 Заказчик удаляет ручную установку (`rm /usr/local/bin/opencode`, каталог `~/software/AI/opencode`) и подтверждает работу пакетного CLI; критерий: `which opencode` → `/usr/bin/opencode`

## Workflow follow-up

- После ревью — архивация change (`openspec archive`), delta перейдёт в `openspec/specs/opencode-packaging/`.
- Отдельный последующий change: интеграция openspec с opencode (packaging openspec-bin сделан в рамках этой же работы, оформляется отдельно).
