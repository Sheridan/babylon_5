# Copyright 2023
# Distributed under the terms of the GNU General Public License v2

EAPI=7

DESCRIPTION="QCacheGrind - Graphical Calltree/DAG browser for Valgrind's output"
HOMEPAGE="https://kcachegrind.github.io/"
SRC_URI="https://github.com/KDE/kcachegrind/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND="dev-qt/qtcore:5
        dev-qt/qtgui:5
        dev-qt/qtnetwork:5
        dev-qt/qtsql:5
        dev-qt/qtwidgets:5"
RDEPEND="${DEPEND}"

src_prepare() {
  default
}

src_configure() {
  eqmake5
}

src_compile() {
  emake
}

src_install() {
  emake INSTALL_ROOT="${D}" install
  dodoc README.md
}
