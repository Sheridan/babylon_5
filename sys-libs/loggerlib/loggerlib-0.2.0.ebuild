# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Some simple methos for working with strings, networking, filesystem, etc..."
HOMEPAGE="https://github.com/Sheridan/cpptoolslib"
SRC_URI="https://github.com/Sheridan/cpptoolslib/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND=""
DEPEND="${RDEPEND} >=sys-libs/cpptoolslib-0.2.0"
BDEPEND=">=dev-build/cmake-3.28"

S="${WORKDIR}/${P}"

inherit cmake
