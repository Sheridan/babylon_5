# Spec Delta

## ADDED Requirements

### Requirement: Владение устанавливаемых файлов гарантировано зависимостью
Все группы и пользователи, передаваемые в `fowners`/`fperms` фазами установки, SHALL быть объявлены в `DEPEND` ebuild; для `root:strata` это означает наличие `acct-group/strata` в `DEPEND`.

#### Scenario: Владельцы после merge
- **WHEN** после установки проверить права файлов `/etc/strata/*` и `/var/lib/strata`
- **THEN** владельцем указанных файлов значится `root:strata`, группа `strata` существует на момент merge

#### Scenario: Порядок установки
- **WHEN** `app-ai/strata` merge-ится на системе, где `acct-group/strata` ещё не установлен
- **THEN** Portage устанавливает `acct-group/strata` до merge пакета strata, `fowners` не вызывает ошибку несуществующей группы
