# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Spec-driven development (SDD) CLI for AI coding assistants (prebuilt binary)"
HOMEPAGE="https://openspec.dev https://github.com/Fission-AI/OpenSpec"
UPSTREAM_URI="https://github.com/Fission-AI/OpenSpec/releases/download/v${PV}"

SRC_URI="
	amd64? (
		elibc_glibc? ( ${UPSTREAM_URI}/openspec-linux-x64.tar.gz -> ${P}-linux-x64.tar.gz )
		elibc_musl? ( ${UPSTREAM_URI}/openspec-linux-x64-musl.tar.gz -> ${P}-linux-x64-musl.tar.gz )
	)
	https://raw.githubusercontent.com/Fission-AI/OpenSpec/v${PV}/LICENSE -> ${P}-LICENSE
"
S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"

# Ships a Bun-compiled ELF binary; must not be stripped or rebuilt
RESTRICT="strip"

src_install() {
	dobin openspec

	newdoc "${DISTDIR}/${P}-LICENSE" LICENSE
}
