# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="The open source AI coding agent (prebuilt binary)"
HOMEPAGE="https://opencode.ai https://github.com/anomalyco/opencode"
UPSTREAM_URI="https://github.com/anomalyco/opencode/releases/download/v${PV}"
# Releases 2.x no longer ship a LICENSE asset; take it from the tagged tree.
LICENSE_URI="https://github.com/anomalyco/opencode/raw/v${PV}/LICENSE"

SRC_URI="
	amd64? (
		elibc_glibc? (
			baseline? ( ${UPSTREAM_URI}/opencode-linux-x64-baseline.tar.gz -> ${P}-linux-x64-baseline.tar.gz )
			!baseline? ( ${UPSTREAM_URI}/opencode-linux-x64.tar.gz -> ${P}-linux-x64.tar.gz )
		)
		elibc_musl? (
			baseline? ( ${UPSTREAM_URI}/opencode-linux-x64-baseline-musl.tar.gz -> ${P}-linux-x64-baseline-musl.tar.gz )
			!baseline? ( ${UPSTREAM_URI}/opencode-linux-x64-musl.tar.gz -> ${P}-linux-x64-musl.tar.gz )
		)
	)
	${LICENSE_URI} -> ${P}-LICENSE
"
S="${WORKDIR}"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="baseline"

RDEPEND="
	dev-vcs/git
	sys-apps/ripgrep
"

# Ships a Bun-compiled ELF binary; must not be stripped or rebuilt
RESTRICT="strip"

src_install() {
	dobin opencode

	newdoc "${DISTDIR}/${P}-LICENSE" LICENSE
}
