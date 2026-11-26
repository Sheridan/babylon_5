# Design

## Context

`cmake.eclass` (EAPI 8) в `src_prepare`/DEPEND выставляет `BDEPEND="... dev-util/ninja >=dev-util/cmake-3.20.5"`; ebuild присваиванием `BDEPEND="dev-build/ninja"` перекрывает это. `dev-build/ninja` в Portage нет (проверено: `ls /var/db/repos/gentoo/dev-build` отсутствует, ninja — `dev-util/ninja`).

## Goals / Non-Goals

**Goals:** корректные, необнуляемые зависимости фазы сборки.
**Non-Goals:** не переводить сборку с ninja на make.

## Decisions

- Удалить строку полностью: eclass сам добавит ninja и cmake. Альтернатива `BDEPEND+=" dev-util/ninja"` избыточна (дублирует eclass).

## Risks / Trade-offs

- Нет риска: набор фазы сборки только расширяется (cmake из eclass уже работал через кэш/окружение? нет — cmake и так в BDEPEND eclass не перекрывался бы, т.к. присваивание шло после наследования; удаление возвращает полный набор eclass).
