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
DEPEND="${RDEPEND} dev-lang/cmake"
BDEPEND="dev-util/cmake"

S="${WORKDIR}/${P}"

inherit cmake

src_unpack() {
    default
}

src_prepare() {
    default
}

src_configure() {
    cmake_src_configure
}

src_compile() {
    cmake_src_compile
}

src_install() {
    cmake_src_install
}

pkg_postinst() {
    elog "loggerlib ${PV} has been installed."
}