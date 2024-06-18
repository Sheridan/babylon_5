# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Loggerlib is a simple logging library."
HOMEPAGE="https://github.com/Sheridan/loggerlib"
SRC_URI="https://github.com/Sheridan/loggerlib/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND=""
DEPEND="${RDEPEND}"
BDEPEND=">=dev-build/cmake-3.28"

S="${WORKDIR}/${P}"

inherit cmake
