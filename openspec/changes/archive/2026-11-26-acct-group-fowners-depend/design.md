# Design

## Context

`strata-0.2.20.ebuild`: `RDEPEND` содержит `acct-user/strata acct-group/strata`; `src_install` — `fowners -R root:strata /var/lib/strata` и точечные `fowners root:strata` для конфигов. `acct-group/strata` создаёт группу на своей фазе установки; без `DEPEND`-гарантии вызов `fowners` опирается на невнятный порядок merge.

## Goals / Non-Goals

**Goals:** формальная корректность владения; pkgcheck-чистота.
**Non-Goals:** не менять `acct-*` пакеты.

## Decisions

- `DEPEND="acct-group/strata"` (плюс `acct-user/strata` туда же не добавляем — не требуется для fowners; оставляем RDEPEND). Альтернатива — перенести обоих в DEPEND — не вредна, но шире необходимого.

## Risks / Trade-offs

- Крайне узкий риск: цикл зависимостей невозможен (acct не зависит от strata).
