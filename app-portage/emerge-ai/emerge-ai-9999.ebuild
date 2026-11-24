# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DISTUTILS_SINGLE_IMPL=1
DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{11..14} )
inherit distutils-r1 git-r3

DESCRIPTION="AI-assisted emerge wrapper for Gentoo (version-locked to sys-apps/portage)"
HOMEPAGE="https://github.com/Sheridan/emerge-ai"
EGIT_REPO_URI="https://github.com/Sheridan/emerge-ai.git"
EGIT_BRANCH="master"

LICENSE="GPL-3+"
SLOT="0"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="
	sys-apps/portage
	sys-apps/util-linux
"
BDEPEND="
	test? ( $(python_gen_cond_dep '>=dev-python/pytest-7[${PYTHON_USEDEP}]') )
"

DOCS=( README.md )

src_test() {
	python_test -- -m "not integration" || die
}

src_install() {
	distutils-r1_src_install
	insinto /usr/share/emerge-ai
	doins -r prompts
	doins "${S}/packaging/emerge-ai.json.default"
}

pkg_postinst() {
	local cfg="${ROOT}/etc/portage/emerge-ai.json"
	if [[ ! -e ${cfg} ]]; then
		if install -m 0600 -o root -g root \
			"${ROOT}/usr/share/emerge-ai/emerge-ai.json.default" "${cfg}"; then
			elog "Created /etc/portage/emerge-ai.json (0600) from the packaged default."
		else
			elog "Could not create /etc/portage/emerge-ai.json; copy"
			elog "  /usr/share/emerge-ai/emerge-ai.json.default manually (chmod 0600)."
		fi
	else
		elog "/etc/portage/emerge-ai.json already exists - left untouched."
	fi
	elog "Set \"endpoint\" (OpenAI-compatible base URL) and \"model\" there;"
	elog "without an endpoint every LLM call fails explicitly by design."
	elog
	elog "Run 'emerge-ai --help' for the wrapper flags: -p/--pretend and -a/--ask"
	elog "are intercepted (plan + digest), plus --changelog, --rollback, --resume,"
	elog "--noninteractive and --i-understand-the-risks (autonomy). Other arguments"
	elog "go to emerge verbatim."
	elog
	elog "Optional tools (not hard deps, features degrade without them):"
	elog "  sys-fs/btrfs-progs  - read-only snapshots for tier 1-4 merges"
	elog "  app-portage/genlop  - merge-time estimates in the plan digest"
	elog "  dev-vcs/git         - git_urls sources for emerge-ai --changelog"
}
