EAPI=8

# python3_13/14 only: dev-python/textual (USE=monitor) supports nothing else,
# and both targets are the profile default on amd64.
PYTHON_COMPAT=( python3_{13..14} )
inherit cmake multiprocessing python-single-r1 systemd

DESCRIPTION="Local-first LLM workstation: C++ inference engine, CLI and local web server"
HOMEPAGE="https://github.com/Niko1221/Strata"
SRC_URI="https://github.com/Niko1221/Strata/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Strata-${PV}"

# The engine component folder embeds runtime libraries copied from the GPU
# toolkits. The NVIDIA ones are prebuilt binaries under the CUDA EULA, hence
# the NVIDIA-CUDA license; dev-util/nvidia-cuda-toolkit declares the same.
# The ROCm side (dev-util/hip and friends) builds from source and is MIT
# licensed, already covered by the unconditional MIT, so the HIP side needs
# no extra license identifier (AMD-GPU-PRO-EULA would be wrong: it covers
# AMD's binary PRO distribution, not these packages).
LICENSE="MIT cuda? ( NVIDIA-CUDA )"
SLOT="0"
KEYWORDS="~amd64"
# monitor is enabled by default through profiles/package.use of this overlay
# (EAPI 8 has no IUSE_DEFAULTS).
IUSE="cuda hip vision monitor"
# The EULA licensed CUDA runtime libraries the component folder embeds
# forbid binary redistribution and distfile mirroring; the MIT ROCm side
# carries no such restriction.
RESTRICT="cuda? ( bindist mirror )"
REQUIRED_USE="
	?? ( cuda hip )
	${PYTHON_REQUIRED_USE}
"

DEPEND="
	${PYTHON_DEPS}
	acct-group/strata
	cuda? ( >=dev-util/nvidia-cuda-toolkit-12.8 sys-devel/gcc:14= )
	hip? ( >=dev-util/hip-6 )
"
RDEPEND="
	${PYTHON_DEPS}
	$(python_gen_cond_dep '
		dev-python/jinja2[${PYTHON_USEDEP}]
		dev-python/numpy[${PYTHON_USEDEP}]
		dev-python/pillow[${PYTHON_USEDEP}]
		dev-python/psutil[${PYTHON_USEDEP}]
		dev-python/pyyaml[${PYTHON_USEDEP}]
		dev-python/regex[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
		dev-python/tqdm[${PYTHON_USEDEP}]
	')
	monitor? ( $(python_gen_cond_dep 'dev-python/textual[${PYTHON_USEDEP}]') )
	acct-user/strata
"

CMAKE_USE_DIR="${S}/engine"
VISION_BUILD="${WORKDIR}/${P}_vision_build"

strata_hip_archs_space() {
	local a="${STRATA_HIP_ARCHS:-gfx1100 gfx1201}"
	echo "${a//;/ }"
}

strata_cuda_archs_setup() {
	# writes ${T}/cuda-arch (one value per line: numeric archs; first line
	# carries "native" when CMake should pick the local GPU itself)
	if [[ -n ${STRATA_CUDA_ARCHS:-} ]]; then
		local a
		for a in ${STRATA_CUDA_ARCHS//;/ }; do echo "${a#compute_}"; done \
			> "${T}/cuda-arch" || die
	elif command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
		echo native > "${T}/cuda-arch" || die
		nvidia-smi --query-gpu=compute_cap --format=csv,noheader \
			| tr -d '. \r' >> "${T}/cuda-arch" || die
	else
		ewarn "STRATA_CUDA_ARCHS is unset and no NVIDIA GPU is visible to the build;"
		ewarn "compiling for the list 80;86;89;120 without PTX."
		ewarn "Override via /etc/portage/package.env (STRATA_CUDA_ARCHS) if needed."
		printf '80\n86\n89\n120\n' > "${T}/cuda-arch" || die
	fi
}

src_configure() {
	local cuda_cmake="" cuda_host=""
	if use cuda; then
		# CUDA 12.9 refuses host compilers newer than gcc 14
		local host_gcc="${STRATA_CUDA_HOST_GCC:-14}"
		local cuda_host="${CHOST}-gcc-${host_gcc}"
		command -v "${cuda_host}" >/dev/null 2>&1 \
			|| die "nvcc host compiler ${cuda_host} not found (set STRATA_CUDA_HOST_GCC)"
		# build the whole tree with the same gcc nvcc hosts to, so that
		# libstdc++ symbols line up at link time (cmake.eclass takes CC/CXX
		# from tc-getCC/tc-getCXX which honour these exports)
		export CC="${cuda_host}"
		export CXX="${CHOST}-g++-${host_gcc}"
		strata_cuda_archs_setup
		if [[ "$(head -n 1 "${T}/cuda-arch")" == native ]]; then
			cuda_cmake="native"
		else
			cuda_cmake="$(tr '\n' ';' < "${T}/cuda-arch" | sed 's/;$//')"
		fi
	fi

	local mycmakeargs=(
		-DSTRATA_BUILD_TESTS=OFF
		-DSTRATA_PORTABLE=ON
		-DSTRATA_ENABLE_CUDA="$(usex cuda ON OFF)"
		-DSTRATA_ENABLE_HIP="$(usex hip ON OFF)"
		# $ORIGIN travels into the engine folder so the bundled libraries resolve
		# without LD_LIBRARY_PATH; it must cover shared objects and modules too,
		# not just the executable — the copied .so files import each other
		"-DCMAKE_EXE_LINKER_FLAGS=${LDFLAGS} -Wl,-rpath,'\$ORIGIN' -Wl,--enable-new-dtags"
		"-DCMAKE_SHARED_LINKER_FLAGS=${LDFLAGS} -Wl,-rpath,'\$ORIGIN' -Wl,--enable-new-dtags"
		"-DCMAKE_MODULE_LINKER_FLAGS=${LDFLAGS} -Wl,-rpath,'\$ORIGIN' -Wl,--enable-new-dtags"
	)
	use cuda && mycmakeargs+=(
		"-DCMAKE_CUDA_ARCHITECTURES=${cuda_cmake}"
		"-DCMAKE_CUDA_HOST_COMPILER=${cuda_host}"
	)

	if use hip; then
		local hip_archs
		hip_archs="$(strata_hip_archs_space)"
		hip_archs="${hip_archs// /;}"
		mycmakeargs+=( "-DCMAKE_HIP_ARCHITECTURES=${hip_archs}" )
		local rocm="${EPREFIX}/usr/lib/llvm/roc"
		if [[ -x "${rocm}/bin/clang++" ]]; then
			mycmakeargs+=(
				"-DCMAKE_HIP_COMPILER=${rocm}/bin/clang++"
				"-DCMAKE_HIP_COMPILER_ROCM_ROOT=${EPREFIX}/usr"
				"-DCMAKE_HIP_FLAGS=--rocm-path=${EPREFIX}/usr --rocm-device-lib-path=${rocm}/lib/llvm/amdgcn/bitcode"
			)
		fi
	fi

	cmake_src_configure

	if use vision; then
		mkdir -p "${VISION_BUILD}" || die
		local vargs=(
			-S "${S}/terminal/tools/vision"
			-B "${VISION_BUILD}"
			-G Ninja
			-DCMAKE_BUILD_TYPE=Release
			-DCMAKE_INSTALL_PREFIX="${EPREFIX}/usr"
			-DCMAKE_C_FLAGS="${CFLAGS}"
			-DCMAKE_CXX_FLAGS="${CXXFLAGS}"
			-DCMAKE_EXE_LINKER_FLAGS="${LDFLAGS} -Wl,-rpath,\$ORIGIN -Wl,--enable-new-dtags"
			-DCMAKE_SHARED_LINKER_FLAGS="${LDFLAGS} -Wl,-rpath,\$ORIGIN -Wl,--enable-new-dtags"
			-DCMAKE_MODULE_LINKER_FLAGS="${LDFLAGS} -Wl,-rpath,\$ORIGIN -Wl,--enable-new-dtags"
			-DSTRATA_PORTABLE=ON
			-DSTRATA_VISION_METAL=OFF
			-DSTRATA_VISION_ORACLES=OFF
			-DSTRATA_VISION_CUDA="$(usex cuda ON OFF)"
			-DSTRATA_VISION_HIP="$(usex hip ON OFF)"
		)
		use cuda && vargs+=(
			"-DCMAKE_CUDA_ARCHITECTURES=${cuda_cmake}"
			"-DCMAKE_CUDA_HOST_COMPILER=${cuda_host}"
		)
		use hip && vargs+=( "-DSTRATA_VISION_HIP_ARCHS=${hip_archs}" )
		cmake "${vargs[@]}" || die "vision configure failed"
	fi
}

src_compile() {
	# only the shipped targets, not the bench/parity programs
	local targets=( strata-gguf strata-dequant strata-plan )
	if use cuda || use hip; then
		targets+=( strata )
	fi
	cmake_src_compile "${targets[@]}"

	if use vision; then
		local vtarget=strata-vision
		use hip && vtarget=strata-vision-hip
		# the main engine goes through cmake_src_compile which honours MAKEOPTS;
		# this manual second build needs --parallel or CMake compiles one file at a time
		cmake --build "${VISION_BUILD}" --parallel "$(makeopts_jobs)" \
			--target "${vtarget}" || die "vision build failed"
	fi
}

src_install() {
	# the Terminal: CLI, Control, the API server and its web assets.
	# The whole tree ships: strata.py and serve/ reach into tools/ and
	# data/ at runtime, so trimming needs upstream guarantees we lack.
	insinto /usr/share/strata
	doins -r "${S}"/terminal/.
	fperms 0755 /usr/share/strata/bin/strata

	cat > "${T}/strata" <<EOF || die
#!/bin/sh
# Gentoo wrapper for Strata's launcher: pin the interpreter to the one
# selected by PYTHON_TARGETS unless the user overrides STRATA_PYTHON.
STRATA_PYTHON="\${STRATA_PYTHON:-${PYTHON}}"
export STRATA_PYTHON
exec "${EPREFIX}/usr/share/strata/bin/strata" "\$@"
EOF
	dobin "${T}/strata"

	# engine-side utilities, built in every configuration
	local u found
	for u in strata-gguf strata-dequant strata-plan; do
		found="$(find "${BUILD_DIR}" -maxdepth 2 -name "${u}" -type f -perm -u+x | head -n 1)"
		[[ -n ${found} ]] && dobin "${found}"
	done

	if use cuda || use hip; then
		local engine_pv
		engine_pv="$(sed -n 's/^project(strata VERSION \([0-9.]*\).*/\1/p' "${S}/engine/CMakeLists.txt")"
		[[ -n ${engine_pv} ]] || die "could not read the engine version from engine/CMakeLists.txt"

		local src="${T}/engine-component-src"
		mkdir -p "${src}" || die
		local engine_bin
		engine_bin="$(find "${BUILD_DIR}" -maxdepth 2 -name strata -type f -perm -u+x | head -n 1)"
		[[ -n ${engine_bin} ]] || die "engine binary 'strata' not found in ${BUILD_DIR}"
		cp "${engine_bin}" "${src}/strata" || die
		# bundle shared objects the build produced (rpath $ORIGIN resolves them)
		find "${BUILD_DIR}" -maxdepth 2 \( -name '*.so' -o -name '*.so.*' \) -type f \
			-exec cp -t "${src}/" {} + 2>/dev/null

		local vision_field=none
		if use vision; then
			local vtarget=strata-vision vbin
			use hip && vtarget=strata-vision-hip
			vbin="$(find "${VISION_BUILD}" -maxdepth 2 -name "${vtarget}" -type f -perm -u+x | head -n 1)"
			[[ -n ${vbin} ]] || die "strata-vision binary not found in ${VISION_BUILD}"
			cp "${vbin}" "${src}/" || die
			find "${VISION_BUILD}" -maxdepth 2 \( -name '*.so' -o -name '*.so.*' \) -type f \
				-exec cp -t "${src}/" {} + 2>/dev/null
			vision_field="$(usex cuda gpu "$(usex hip gpu cpu)")"
		fi

		# binary_deps only accepts glibc/libstdc++ and driver libraries as "OS
		# provided", so every other imported runtime (CUDA/ROCm) must travel
		# inside the component; copy the transitive closure from the toolkits.
		local -a lib_roots=( )
		use cuda && lib_roots+=( "/opt/cuda/targets/${CHOST%%-*}-linux/lib" /opt/cuda/lib64 )
		use hip && lib_roots+=( /opt/rocm/lib /opt/rocm/lib/llvm/lib )
		local missing name dir round
		for round in 1 2 3 4 5 6 7 8; do
			missing="$( "${PYTHON}" "${FILESDIR}/library_check.py" "${S}/tools/packaging" "${src}" )" \
				|| die "library coverage check failed"
			[[ -z ${missing} ]] && break
			while IFS= read -r name; do
				[[ -n ${name} ]] || continue
				local hit=""
				for dir in "${lib_roots[@]}"; do
					[[ -e ${dir}/${name} ]] && { hit="${dir}/${name}"; break; }
				done
				[[ -n ${hit} ]] || die "cannot bundle ${name}: not under ${lib_roots[*]}"
				cp -L --remove-destination "${hit}" "${src}/${name}" || die
			done <<< "${missing}"
			[[ ${round} -eq 8 ]] && die "library closure did not converge"
		done

		# License paperwork. The closure copied EULA/MIT runtime libraries
		# into the component, and package_engine.py packages top-level
		# LICENSE* files, so the texts travel inside the component folder
		# (it may be copied to other machines). ${src}/LICENSE-BUNDLED.txt
		# inventories every .so: built in-tree (MIT) or copied from a
		# toolkit (its license group).
		cp "${S}/LICENSE" "${src}/LICENSE.txt" || die
		local -a notice_stems=( )
		local notice stem
		for notice in "${S}"/tools/packaging/notices/*.txt; do
			stem="$(basename "${notice}" .txt)"
			# upstream notice only when that library is actually bundled
			local -a notice_hits=( "${src}/${stem}".so* )
			if [[ -e ${notice_hits[0]} ]]; then
				cp "${notice}" "${src}/LICENSE-${stem}.txt" || die
				notice_stems+=( "${stem}" )
			fi
		done
		local -a bundled_own=( ) bundled_cuda=( ) bundled_rocm=( ) bundled_notice=( )
		local so origin name hit
		for so in "${src}"/*.so*; do
			# *.so* also matches versioned SONAMEs such as libcublas.so.13
			[[ -e ${so} ]] || continue
			name="$(basename "${so}")"
			origin=""
			for dir in "${lib_roots[@]}"; do
				[[ -e ${dir}/${name} ]] && { origin="${dir}"; break; }
			done
			hit=""
			for stem in "${notice_stems[@]}"; do
				[[ ${name} == "${stem}".so* ]] && { hit=${stem}; break; }
			done
			if [[ -n ${hit} ]]; then
				bundled_notice+=( "${name} (see LICENSE-${hit}.txt)" )
			elif [[ -z ${origin} ]]; then
				bundled_own+=( "${name}" )
			elif use cuda; then
				bundled_cuda+=( "${name} (from ${origin})" )
			else
				bundled_rocm+=( "${name} (from ${origin})" )
			fi
		done
		{
			echo "Contents of this Strata engine component folder:"
			echo
			echo "Strata engine, helpers and own shared libraries - MIT license"
			# one printf: with an empty array a bare format would print a tab
			printf '\t%s\n' 'LICENSE.txt' "${bundled_own[@]}"
			if [[ ${#bundled_cuda[@]} -gt 0 ]]; then
				echo
				echo "Shared libraries copied from dev-util/nvidia-cuda-toolkit -"
				echo "NVIDIA CUDA EULA (license group NVIDIA-CUDA), full text in"
				echo "LICENSE-CUDA-EULA.txt:"
				printf '\t%s\n' "${bundled_cuda[@]}"
			fi
			if [[ ${#bundled_rocm[@]} -gt 0 ]]; then
				echo
				echo "Shared libraries copied from the ROCm packages (dev-util/hip"
				echo "and friends), built from source and MIT licensed:"
				printf '\t%s\n' "${bundled_rocm[@]}"
			fi
			if [[ ${#bundled_notice[@]} -gt 0 ]]; then
				echo
				echo "System libraries bundled for portability, carrying their"
				echo "upstream notices (written by the toolkit's packaging tools):"
				printf '\t%s\n' "${bundled_notice[@]}"
			fi
		} > "${src}/LICENSE-BUNDLED.txt" || die
		if use cuda; then
			# the EULA text of the very toolkit that built the libraries; the
			# fallback keeps the component carrying a pointer if a toolkit
			# variant ever stops shipping the file
			if [[ -r /opt/cuda/EULA.txt ]]; then
				cp /opt/cuda/EULA.txt "${src}/LICENSE-CUDA-EULA.txt" || die
			else
				ewarn "dev-util/nvidia-cuda-toolkit shipped no /opt/cuda/EULA.txt;"
				ewarn "the component only carries a reference to the NVIDIA-CUDA"
				ewarn "license text managed by the license-tools eclasses."
				{
					echo 'The bundled CUDA runtime libraries are licensed under the'
					echo 'NVIDIA CUDA EULA, license group "NVIDIA-CUDA" of the Gentoo'
					echo 'license manager; the full text ships with the Gentoo'
					echo 'repository under licenses/NVIDIA-CUDA.'
				} > "${src}/LICENSE-CUDA-EULA.txt" || die
			fi
		fi

		local -a arch_args=( ) min_driver=( )
		local backend=cuda archs_json="" a
		if use cuda; then
			local -a num_archs=( )
			# cuda-arch starts with "native" only when CMake probes the GPU;
			# otherwise every line is an arch
			if [[ "$(head -n 1 "${T}/cuda-arch")" == native ]]; then
				num_archs=( $(tail -n +2 "${T}/cuda-arch") )
			fi
			[[ ${#num_archs[@]} -gt 0 ]] || num_archs=( $(cat "${T}/cuda-arch") )
			for a in "${num_archs[@]}"; do
				arch_args+=( --arch "sm_${a}" )
				archs_json+="${archs_json:+,}${a}"
			done
			local cuda_ver
			cuda_ver="$(nvcc --version | sed -n 's/.*release \([0-9.]*\).*/\1/p')"
			# the reader ships built for the very archs the engine was
			# compiled for; package_engine.py refuses the pair otherwise
			local vision_archs_json=""
			use vision && vision_archs_json="${archs_json//,/;}"
			cat > "${src}/BUILD.json" <<EOF || die
{
"version": "${engine_pv}",
"source": "portage",
"archs": [${archs_json}],
"ptx": false,
"cuda": "${cuda_ver}",
"vision": "${vision_field}",
"vision_archs": "${vision_archs_json}",
"portable": true
}
EOF
			# floor for the NVIDIA driver the component needs; override per
			# machine with STRATA_NVIDIA_DRIVER (e.g. in /etc/portage/env/) when
			# the component is built against a newer CUDA userland than default
			min_driver=( --min-driver "nvidia=${STRATA_NVIDIA_DRIVER:-570.124.06}" )
		else
			backend=hip
			local gfx_json=""
			for a in $(strata_hip_archs_space); do
				arch_args+=( --arch "${a}" )
				gfx_json+="${gfx_json:+,}\"${a}\""
			done
			cat > "${src}/BUILD.json" <<EOF || die
{
"version": "${engine_pv}",
"source": "portage",
"archs": [${gfx_json}],
"vision": "${vision_field}",
"portable": true
}
EOF
		fi

		local -a search_args=()
		use cuda && search_args+=( --search "/opt/cuda/targets/${CHOST%%-*}-linux/lib" --search /opt/cuda/lib64 )
		use hip && search_args+=( --search /opt/rocm/lib )

		"${PYTHON}" "${S}/tools/packaging/package_engine.py" \
			--src "${src}" \
			--backend "${backend}" \
			--version "${engine_pv}" \
			"${arch_args[@]}" \
			"${min_driver[@]}" \
			"${search_args[@]}" \
			--out "${ED}/usr/lib/strata/engine" || die "package_engine.py failed"
		local comp
		for comp in "${ED}"/usr/lib/strata/engine/*/; do
			"${PYTHON}" "${S}/tools/packaging/package_engine.py" --verify "${comp%/}" \
				|| die "engine component verification failed"
		done

		# Gentoo convention: the license texts of everything the package
		# installs live under /usr/share/licenses/${PF}; the component folder
		# carries the same files for machines it gets copied to.
		dodir /usr/share/licenses/${PF}
		cp "${src}"/LICENSE* "${ED}/usr/share/licenses/${PF}/" || die
	elif use vision; then
		# no engine folder would carry the picture reader, so ship it to a
		# documented system location; copy it into an engine folder to use it
		local vbin
		vbin="$(find "${VISION_BUILD}" -maxdepth 2 -name strata-vision -type f -perm -u+x | head -n 1)"
		[[ -n ${vbin} ]] || die "strata-vision binary not found in ${VISION_BUILD}"
		into /usr/lib/strata/vision
		dobin "${vbin}"
	fi

	# System service: a templated unit (one unit per model instance, started
	# explicitly - the template has no [Install] section), the env file the
	# per-instance copies are made from, and the host-facing model tools.
	# Engine registration is the helper's job (runtime decision), so the unit
	# needs no build-time templating. Deliberately no static strata.service
	# and no /etc/strata/strata.json: which model serves the host is a host
	# decision, and the one host port (8080 by default) can only be held by
	# one instance at a time.
	if use cuda || use hip; then
		# The helper runs as an ExecStartPre of strata@.service, i.e. under
		# User=strata - a sandboxed non-root user cannot execute files under
		# /usr/bin in this configuration (the same reason the engine folder
		# lives under /usr/lib), so it belongs to the libdir, not the bindir.
		exeinto /usr/lib/strata
		newexe "${FILESDIR}/strata-engine-register" engine-register
	fi

	# The catalog helper is what the /usr/bin model tools ask their questions
	# to; administrators do not run it directly, so it sits in the libdir
	# beside the engine helper. Its plain '#!/usr/bin/env python3' shebang is
	# fine: it only parses source files with the stdlib ast module.
	exeinto /usr/lib/strata
	doexe "${FILESDIR}/strata-catalog"
	# pkgcheck bans '@' in files/ names, so the packaged template unit is
	# stored without it and installed under the name systemd expects.
	systemd_newunit "${FILESDIR}/strata.template.service" strata@.service

	# The model tools are run by an administrator directly, so they live in
	# /usr/bin like the other CLIs.
	exeinto /usr/bin
	doexe "${FILESDIR}/strata-list-available"
	doexe "${FILESDIR}/strata-download-model"
	doexe "${FILESDIR}/strata-list-installed"
	doexe "${FILESDIR}/strata-models-inspect"
	doexe "${FILESDIR}/strata-rm-model"

	# The packaged env file is a default, world-readable because it holds no
	# secrets; a copy that gets credentials must be tightened to 0640
	# root:strata - the tools refuse to use or ship anything else.
	insinto /etc/strata/instances.d
	doins "${FILESDIR}/strata-model-instance.conf"
	fperms 0644 /etc/strata/instances.d/model-instance.conf

	dodoc "${S}/README.md" "${FILESDIR}/README.gentoo"
}

pkg_postinst() {
	if use cuda || use hip; then
		elog "Strata's engine was installed as a component folder under"
		elog "  ${EPREFIX}/usr/lib/strata/engine/"
		elog "strata@.service registers it before every instance starts"
		elog "(helper /usr/lib/strata/engine-register); other users can"
		elog "register it with:"
		elog "  strata components add-build ${EPREFIX}/usr/lib/strata/engine/<folder>"
	else
		elog "Built without the cuda or hip USE flag: Strata has no CPU-only"
		elog "engine upstream. Enable USE=cuda or USE=hip for the local engine,"
		elog "or let 'strata setup' fetch one."
	fi
	if ! use monitor; then
		ewarn "USE=-monitor: 'strata monitor' needs dev-python/textual."
	fi
	elog "The web server is packaged as the strata@.service template - one"
	elog "unit per model instance, and nothing is enabled or started"
	elog "automatically: serving the host is a three-step act of explicit"
	elog "consent (exposure, resource use):"
	elog "  1. strata-list-available [family]    - what can be installed"
	elog "  2. strata-download-model <family>/<model>"
	elog "     (downloads the model and prepares its config and state dir)"
	elog "  3. systemctl start strata@<model>    - logs: journalctl -u strata@<model>"
	elog "Address and port live in"
	elog "  ${EPREFIX}/etc/strata/<model>/daemon.conf"
	elog "(default port 8080 - one port, one instance at a time; set"
	elog "STRATA_PORT for the next one). Installed instances:"
	elog "strata-list-installed; details: strata-models-inspect <model>;"
	elog "remove again: strata-rm-model <model>. Models are not shipped with"
	elog "the package; see ${EPREFIX}/usr/share/doc/${PF}/README.gentoo"
	ewarn "This update drops the static strata.service and the config"
	ewarn "template /etc/strata/strata.json. Configs you edited yourself are"
	ewarn "kept by portage, but if the old service was enabled its enablement"
	ewarn "now points at a removed unit:"
	ewarn "  systemctl disable strata && systemctl daemon-reload"
	ewarn "and serve a model through strata@<model> instead."
	# the manager must notice a replaced unit file; the guarded call degrades
	# to a warning when the sandbox blocks the D-Bus/private-socket hop
	if [[ -d ${ROOT}/run/systemd/system ]]; then
		systemctl daemon-reload -q 2>/dev/null \
			|| ewarn "could not reach systemd; run: systemctl daemon-reload"
	fi
	systemd_update_catalog
}
