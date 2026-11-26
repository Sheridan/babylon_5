# Spec Delta

## MODIFIED Requirements

### Requirement: Пакет доступен из оверлея как бинарная поставка
Оверлей `babylon_5` SHALL предоставлять пакет `app-ai/opencode-bin` (версия 2.4.1, тег `v2.4.1`) с корректным Manifest, лицензией MIT и KEYWORDS `~amd64`: исполняемый файл берётся из готового архива GitHub Releases по SRC_URI с проверкой digest, без компиляции; текст лицензии MIT SHALL входить в пакет и получается из репозитория на теге релиза (релизы 2.x не поставляют LICENSE ассетом).

#### Scenario: Установка из оверлея
- **WHEN** пользователь с подключённым оверлеем `babylon_5` выполняет `emerge app-ai/opencode-bin`
- **THEN** Portage находит пакет, скачивает архив релиза, проверяет хеши и завершает установку без ошибок

#### Scenario: Версия установленного CLI
- **WHEN** сразу после установки выполнить `/usr/bin/opencode --version`
- **THEN** CLI печатает `2.4.1` и завершается кодом 0

#### Scenario: Текст лицензии в пакете
- **WHEN** после установки выполнить `qlist app-ai/opencode-bin`
- **THEN** в составе пакета есть файл `/usr/share/doc/${PF}/LICENSE` с текстом MIT-лицензии
