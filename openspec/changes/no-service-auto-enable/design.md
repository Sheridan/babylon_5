# Design

## Context

Gentoo-политика: ebuild не должен сам включать сервисы (в отличие от ряда дистрибутивов). Текущая реализация к тому же крива: ручной симлинк в `multi-user.target.wants` до `systemctl enable` не создаёт требуемых алиасов/силинков initramfs-безопасно и не работает без systemd.

## Goals / Non-Goals

**Goals:** соответствие политике; честный elog.
**Non-Goals:** не удалять сам юнит и конфиги; не трогать `daemon-reload` при наличии systemd (перечитать изменённый unit-файл полезно).

## Decisions

- Убрать `ln -sfn ... wants/`; вызов `systemctl daemon-reload` оставить в текущем виде (он нужен, чтобы перечитать изменённый unit-файл).
- elog: «Start with: systemctl enable --now strata». Альтернатива — `eselect rc`-подсказка для openrc — не нужна, пакет systemd-центричен (README).

## Risks / Trade-offs

- Установленные системы, полагавшиеся на автовключение: после апгрейда сервис останется включённым (симлинки не удаляем) — деградации нет.
