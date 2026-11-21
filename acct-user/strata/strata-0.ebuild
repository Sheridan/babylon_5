# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

DESCRIPTION="User for the Strata server service"
KEYWORDS="~amd64"
ACCT_USER_ID=-1
ACCT_USER_GROUPS=( strata video render )
ACCT_USER_HOME=/var/lib/strata
ACCT_USER_SHELL=/sbin/nologin

acct-user_add_deps
