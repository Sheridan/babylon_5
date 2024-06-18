# Copyright 1999-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Eclipse Paho MQTT C++ Client Library"
HOMEPAGE="https://www.eclipse.org/paho/"

SRC_URI="https://github.com/eclipse/paho.mqtt.cpp/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
LICENSE="EPL-2.0"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

DEPEND=">=net-libs/paho-mqtt-c-1.3.8"
RDEPEND="${DEPEND}"

S="${WORKDIR}/paho.mqtt.cpp-${PV}"

inherit cmake

src_unpack() {
    default
}

src_prepare() {
    cmake_src_prepare
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
