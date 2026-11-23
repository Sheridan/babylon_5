# Spec Delta

## MODIFIED Requirements

### Requirement: Пакет доступен из оверлея
Оверлей `babylon_5` SHALL предоставлять пакет `app-ai/strata` версии 0.2.20 (исходный тег `v0.2.20`) с корректным Manifest, лицензией MIT и KEYWORDS `~amd64`, собираемый из исходников GitHub без бинарных поставок.

#### Scenario: Установка из оверлея
- **WHEN** пользователь с подключённым оверлеем `babylon_5` выполняет `emerge app-ai/strata`
- **THEN** Portage находит пакет `app-ai/strata-0.2.20`, скачивает исходный архив по SRC_URI и установка завершается без ошибок
