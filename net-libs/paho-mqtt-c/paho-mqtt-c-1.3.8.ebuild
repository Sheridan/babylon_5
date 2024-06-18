EAPI=8

DESCRIPTION="Eclipse Paho MQTT C Client Library"
HOMEPAGE="https://www.eclipse.org/paho/"

SRC_URI="https://github.com/eclipse/paho.mqtt.c/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
LICENSE="EPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="ssl"

DEPEND="ssl? ( dev-libs/openssl:0= )"
RDEPEND="${DEPEND}"

S="${WORKDIR}/paho.mqtt.c-${PV}"

inherit cmake

src_prepare() {
    cmake_src_prepare
    default  # Всегда полезно выполнять действия по умолчанию, если они не конфликтуют.
}

src_configure() {
    local mycmakeargs=(
        $(usex ssl "-DPAHO_WITH_SSL=ON" "-DPAHO_WITH_SSL=OFF")
    )
    cmake_src_configure
}

src_compile() {
    cmake_src_compile
}

src_install() {
    cmake_src_install
}
