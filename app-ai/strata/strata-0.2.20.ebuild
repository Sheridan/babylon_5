EAPI=8

# python3_13/14 only: dev-python/textual (USE=monitor) supports nothing else,
# and both targets are the profile default on amd64.
PYTHON_COMPAT=( python3_{13..14} )
inherit cmake multiprocessing python-single-r1 systemd

DESCRIPTION="Local-first LLM workstation: C++ inference engine, CLI and local web server"
HOMEPAGE="https://github.com/Niko1221/Strata"
SRC_URI="https://github.com/Niko1221/Strata/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Strata-${PV}"

LICENSE="MIT cuda? ( NVIDIA-CUDA ) hip? ( AMD-GPU-PRO-EULA )"
SLOT="0"
KEYWORDS="~amd64"
# monitor is enabled by default through profiles/package.use of this overlay
# (EAPI 8 has no IUSE_DEFAULTS).
IUSE="cuda hip vision monitor"
# Both GPU toolkits ship EULA licensed runtime libraries, which the engine
# component folder embeds, so no binary packages and no distfile mirroring.
RESTRICT="cuda? ( bindist mirror ) hip? ( bindist mirror )"
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
	elif use vision; then
		# no engine folder would carry the picture reader, so ship it to a
		# documented system location; copy it into an engine folder to use it
		local vbin
		vbin="$(find "${VISION_BUILD}" -maxdepth 2 -name strata-vision -type f -perm -u+x | head -n 1)"
		[[ -n ${vbin} ]] || die "strata-vision binary not found in ${VISION_BUILD}"
		into /usr/lib/strata/vision
		dobin "${vbin}"
	fi

	# system service: static unit, address/port env file and a server config
	# template the sysadmin fills in. Engine registration is the helper's job
	# (runtime decision), so the unit needs no build-time templating.
	if use cuda || use hip; then
		exeinto /usr/lib/strata
		newexe "${FILESDIR}/strata-engine-register" engine-register
	fi
	systemd_dounit "${FILESDIR}/strata.service"
	insinto /etc/strata
	doins "${FILESDIR}/daemon.conf" "${FILESDIR}/strata.json"
	fperms 0640 /etc/strata/strata.json
	fowners root:strata /etc/strata/strata.json

	dodoc "${S}/README.md" "${FILESDIR}/README.gentoo"
}

pkg_postinst() {
	if use cuda || use hip; then
		elog "Strata's engine was installed as a component folder under"
		elog "  ${EPREFIX}/usr/lib/strata/engine/"
		elog "strata.service registers it on first start (helper"
		elog "/usr/lib/strata/engine-register); other users can register it with:"
		elog "  strata components add-build ${EPREFIX}/usr/lib/strata/engine/<folder>"
	else
		elog "Built without the cuda or hip USE flag: Strata has no CPU-only"
		elog "engine upstream. Enable USE=cuda or USE=hip for the local engine,"
		elog "or let 'strata setup' fetch one."
	fi
	elog "Models are not shipped with the package; see"
	elog "  ${EPREFIX}/usr/share/doc/${PF}/README.gentoo"
	if ! use monitor; then
		ewarn "USE=-monitor: 'strata monitor' needs dev-python/textual."
	fi
	elog "The web server is packaged as strata.service but not enabled"
	elog "automatically - starting a server on every boot needs explicit"
	elog "consent (exposure, resource use):"
	elog "  systemctl enable --now strata"
	elog "Address/port: ${EPREFIX}/etc/strata/daemon.conf; the engine config"
	elog "${EPREFIX}/etc/strata/strata.json still holds REPLACE placeholders"
	elog "(model path, tokenizer) - fill them in and put models under"
	elog "${EPREFIX}/var/lib/strata (owned by user strata)."
	# the manager must notice a replaced unit file; the guarded call degrades
	# to a warning when the sandbox blocks the D-Bus/private-socket hop
	if [[ -d ${ROOT}/run/systemd/system ]]; then
		systemctl daemon-reload -q 2>/dev/null \
			|| ewarn "could not reach systemd; run: systemctl daemon-reload"
	fi
	systemd_update_catalog
}
