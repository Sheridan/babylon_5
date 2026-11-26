# Why

Строка 21 ebuild: `BDEPEND="dev-build/ninja"` — во-первых, категории `dev-build` не существует (ninja живёт в `dev-util`), во-вторых, присваивание затирает `BDEPEND`, которое выставляет `cmake.eclass` (`dev-util/ninja`, `>=dev-util/cmake-3.20.5`). Сейчас сборка случайно не ломается только из-за того, что Portage не падает на висячем слоте зависимости; любое изменение окружения обнажит битую ссылку, а ninja/cmake окажутся необъявленными.

## What Changes

- Удалить строку `BDEPEND="dev-build/ninja"` из `app-ai/strata/strata-0.2.20.ebuild`; зависимости фазы сборки для cmake/ninja целиком обеспечивает `cmake.eclass`.

## Capabilities

### New Capabilities

(нет)

### Modified Capabilities

- `strata-packaging`: новое требование — зависимости фазы сборки наследуются от eclass без перекрытия несуществующими пакетами.

## Impact

- Только `app-ai/strata/strata-0.2.20.ebuild` (удаление одной строки); пересборка, поведения не меняет.
