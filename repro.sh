#!/usr/bin/env bash
set -eu -o pipefail

##########################################################################################
## Settings
##########################################################################################
echo "## -- Settings"

HPCW_COMMIT=6f7f261feb6e6488a917b83d7884d5e5a925b77d
HPCW_REPO=https://gitlab.dkrz.de/hpcw/hpcw.git

##########################################################################################
## Logic
##########################################################################################
echo "## -- Start"

SCRIPT_DIR=$(dirname $(readlink -f $BASH_SOURCE))
TMP_DIR=${SCRIPT_DIR}/.tmp
CACHE_DIR=${SCRIPT_DIR}/.cache
ONEAPI_PREFIX=${SCRIPT_DIR}/oneapi
mkdir -p ${TMP_DIR} ${CACHE_DIR}

##########################################################################################
## Setup Recent CMake
##########################################################################################
CMAKE_PREFIX=${SCRIPT_DIR}/cmake

CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v4.2.0/cmake-4.2.0-linux-x86_64.tar.gz
CMAKE_CHECKSUM=bbcebd4c433eab3af03a8c80bb5d84e8dfc3ff8a4ab9d01547b21240c23f7c2c

[ ! -f ${CACHE_DIR}/$(basename ${CMAKE_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${CMAKE_URL}) -C - ${CMAKE_URL}
if [ ! -x ${CMAKE_PREFIX}/bin/cmake ]; then
    (
        echo "${CMAKE_CHECKSUM} ${CACHE_DIR}/$(basename ${CMAKE_URL})" | sha256sum -c
        export TMP_CMAKE=${TMP_DIR}/cmake
        mkdir -p $TMP_CMAKE
        cleanup() {
            rm -rf ${TMP_CMAKE}
        }
        trap -- cleanup TERM INT QUIT EXIT HUP
        [ ! -d ${TMP_CMAKE}/$(basename ${CMAKE_URL} .tar.gz) ] && tar xf ${CACHE_DIR}/$(basename ${CMAKE_URL}) -C ${TMP_CMAKE}
        mkdir -p ${CMAKE_PREFIX}
        mv ${TMP_CMAKE}/$(basename ${CMAKE_URL} .tar.gz)/* ${CMAKE_PREFIX}/
    )
else
    echo "## -- Skip CMake"
fi
export PATH=${CMAKE_PREFIX}/bin:${PATH}

##########################################################################################
## Setup HWLOC for binding
##########################################################################################
HWLOC_PREFIX=${SCRIPT_DIR}/hwloc

HWLOC_URL=https://download.open-mpi.org/release/hwloc/v2.12/hwloc-2.12.2.tar.bz2
HWLOC_CHECKSUM=563e61d70febb514138af0fac36b97621e01a4aacbca07b86e7bd95b85055ba0

[ ! -f ${CACHE_DIR}/$(basename ${HWLOC_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${HWLOC_URL}) -C - ${HWLOC_URL}
if [ ! -f ${HWLOC_PREFIX}/bin/hwloc-calc ]; then
(
    echo "${HWLOC_CHECKSUM} ${CACHE_DIR}/$(basename ${HWLOC_URL})" | sha256sum -c
    export TMP_HWLOC=${TMP_DIR}/hwloc
    mkdir -p $TMP_HWLOC
    cleanup() {
        rm -rf ${TMP_HWLOC}
    }
    trap -- cleanup TERM INT QUIT EXIT HUP
    [ ! -d ${TMP_HWLOC}/$(basename ${HWLOC_URL} .tar.gz) ] && tar xf ${CACHE_DIR}/$(basename ${HWLOC_URL}) -C ${TMP_HWLOC}
    cd ${TMP_HWLOC}/$(basename ${HWLOC_URL} .tar.bz2)
    [ ! -f Makefile ] && ./configure \
            --prefix=${HWLOC_PREFIX} \
            --enable-static \
            --disable-shared \
            --disable-cairo \
            --disable-cpuid \
            --disable-libxml2 \
            --disable-opencl \
            --disable-cuda \
            --disable-nvml \
            --disable-rsmi \
            --disable-levelzero \
            --disable-gl \
            --disable-pci
    make -j 8
    make install
)
else
    echo "## -- Skip HWloc"
fi
export PATH=${HWLOC_PREFIX}/bin:${PATH}

##########################################################################################
## Setup GCC 12.5.0 in case system GCC is too recen
##########################################################################################
GCC_PREFIX=${SCRIPT_DIR}/gcc-12.5.0

GNU_MIRROR=https://mirror.cyberbits.eu/gnu

GMP_URL=${GNU_MIRROR}/gmp/gmp-6.3.0.tar.xz
MPC_URL=${GNU_MIRROR}/mpc/mpc-1.3.1.tar.gz
MPFR_URL=${GNU_MIRROR}/mpfr/mpfr-4.2.1.tar.xz
GCC_URL=${GNU_MIRROR}/gcc/gcc-12.5.0/gcc-12.5.0.tar.gz

GMP_CHECKSUM="a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898"
MPFR_CHECKSUM="277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2"
MPC_CHECKSUM="ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8"
GCC_CHECKSUM="f2dfac9c026c58b04251732aa459db614ae1017d32a18a296b1ae5af3dcad927"

# if [ $(gcc -dumpfullversion -dumpversion | cut -d'.' -f1) -gt 12 ]; then
if true; then

[ ! -f ${CACHE_DIR}/$(basename ${GMP_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${GMP_URL}) -C - ${GMP_URL}
[ ! -f ${CACHE_DIR}/$(basename ${MPC_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${MPC_URL}) -C - ${MPC_URL}
[ ! -f ${CACHE_DIR}/$(basename ${MPFR_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${MPFR_URL}) -C - ${MPFR_URL}
[ ! -f ${CACHE_DIR}/$(basename ${GCC_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${GCC_URL}) -C - ${GCC_URL}

GMP_FOLDER=$(basename ${GMP_URL} .tar.xz)
MPC_FOLDER=$(basename ${MPC_URL} .tar.gz)
MPFR_FOLDER=$(basename ${MPFR_URL} .tar.xz)
GCC_FOLDER=$(basename ${GCC_URL} .tar.gz)

_SETUP_LIB_FOLDER=lib
TARGET="$(LANG=C ${CC:-gcc} -v |& grep Target | cut -d' ' -f2)"
mkdir -p ${GCC_PREFIX}/${_SETUP_LIB_FOLDER}
case ${_SETUP_LIB_FOLDER} in
    lib)   [ ! -d ${GCC_PREFIX}/lib64 ] && (cd ${GCC_PREFIX} && ln -s ${_SETUP_LIB_FOLDER} lib64) ;;
    lib64) [ ! -d ${GCC_PREFIX}/lib   ] && (cd ${GCC_PREFIX} && ln -s ${_SETUP_LIB_FOLDER} lib)   ;;
    *)     exit 1 ;;
esac

set +e
CURRENT_SETUP_LIBDIR="${GCC_PREFIX}/${_SETUP_LIB_FOLDER} "
SYSTEM_SEARCH_PATHS=$(gcc -Xlinker --verbose  2>/dev/null | grep SEARCH | sed 's/SEARCH_DIR("=\?\([^"]\+\)"); */\1\n/g'  | grep -vE '^$')
RUNTIME_LIBRARIES="asan atomic gcc_s gfortran gomp hwasan itm lsan quadmath ssp stdc++ tsan ubsan m pthread dl"
SYTEM_RUNTIME_LIB_DIR=$(for lib in $RUNTIME_LIBRARIES; do
    dirname $(readlink -f $(${CC:-cc} -print-file-name=lib${lib}.so)) 2> /dev/null
    dirname $(readlink -f $(${CC:-cc} -print-file-name=lib${lib}.a)) 2> /dev/null
done | grep -v $(pwd) | uniq | sort)
RPATH_SPECS="$CURRENT_SETUP_LIBDIR "
for libdir in $SYTEM_RUNTIME_LIB_DIR $SYSTEM_SEARCH_PATHS;  do
    if ! [[ "${RPATH_SPECS}" =~ " ${libdir} " ]]; then
        RPATH_SPECS+=" ${libdir} "
    fi
done
RPATH_SPECS=$(echo "$RPATH_SPECS" | sed -r 's/[ ]+$//g' | sed -r 's/[ ]+/:/g')
if [ "${LIBRARY_PATH:-}" == "" ]; then
    unset LIBRARY_PATH
fi
set -e

export TMP_GCC=${TMP_DIR}/gcc
mkdir -p $TMP_GCC
cleanup() {
    rm -rf ${TMP_GCC}
}
trap -- cleanup TERM INT QUIT EXIT HUP

if [ ! -f ${GCC_PREFIX}/${_SETUP_LIB_FOLDER}/libgmp.so ]; then
(
    echo "${GMP_CHECKSUM} ${CACHE_DIR}/$(basename ${GMP_URL})" | sha256sum -c
    [ ! -d ${TMP_GCC}/$(basename ${GMP_URL} .tar.xz) ] && tar xf ${CACHE_DIR}/$(basename ${GMP_URL}) -C ${TMP_GCC}
    cd ${TMP_GCC}/${GMP_FOLDER}
    if [ $(gcc -dumpfullversion -dumpversion | cut -d'.' -f1) -ge 15 ] ; then
        export CFLAGS="${CFLAGS:-} -Wno-implicit-function-declaration -std=gnu17"
    fi
    [ ! -f Makefile ] && \
        ./configure \
            --target=${TARGET} \
            --build=${TARGET} \
            --host=${TARGET} \
            --libdir=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --prefix=${GCC_PREFIX}
    make -j 8
    make install
)
else
    echo "## -- Skip GMP"
fi

if [ ! -f ${GCC_PREFIX}/${_SETUP_LIB_FOLDER}/libmpfr.so ]; then
(
    echo "${MPFR_CHECKSUM} ${CACHE_DIR}/$(basename ${MPFR_URL})" | sha256sum -c
    [ ! -d ${TMP_GCC}/$(basename ${MPFR_URL} .tar.xz) ] && tar xf ${CACHE_DIR}/$(basename ${MPFR_URL}) -C ${TMP_GCC}
    cd ${TMP_GCC}/${MPFR_FOLDER}
    [ ! -f Makefile ] && \
        ./configure \
            --target=${TARGET} \
            --build=${TARGET} \
            --host=${TARGET} \
            --with-gmp-include=${GCC_PREFIX}/include \
            --with-gmp-lib=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --libdir=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --prefix=${GCC_PREFIX}
    make -j 8
    make install
)
else
    echo "## -- Skip MPFR"
fi

if [ ! -f ${GCC_PREFIX}/${_SETUP_LIB_FOLDER}/libmpc.so ]; then
(
    echo "${MPC_CHECKSUM} ${CACHE_DIR}/$(basename ${MPC_URL})" | sha256sum -c
    [ ! -d ${TMP_GCC}/$(basename ${MPC_URL} .tar.gz) ] && tar xf ${CACHE_DIR}/$(basename ${MPC_URL}) -C ${TMP_GCC}
    cd ${TMP_GCC}/${MPC_FOLDER}
    [ ! -f Makefile ] && \
        ./configure \
            --target=${TARGET} \
            --build=${TARGET} \
            --host=${TARGET} \
            --with-gmp-include=${GCC_PREFIX}/include \
            --with-gmp-lib=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --with-mpfr-include=${GCC_PREFIX}/include \
            --with-mpfr-lib=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --libdir=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --prefix=${GCC_PREFIX}
    make -j 8
    make install
)
else
    echo  "## -- Skip MPC"
fi

if [ ! -f ${GCC_PREFIX}/bin/gcc ]; then
(
    echo "${GCC_CHECKSUM} ${CACHE_DIR}/$(basename ${GCC_URL})" | sha256sum -c
    [ ! -d ${TMP_GCC}/$(basename ${GCC_URL} .tar.gz) ] && tar xf ${CACHE_DIR}/$(basename ${GCC_URL}) -C ${TMP_GCC}

    # # need to export this otherwise some steps fail at finding ISL ... (if not already !)
    # if ! [[ "${LDFLAGS:-}" =~ "-Wl,-rpath,${GCC_PREFIX}/${_SETUP_LIB_FOLDER}/" ]]; then
    #     LDFLAGS="${LDFLAGS:-} -Wl,-rpath,${GCC_PREFIX}/${_SETUP_LIB_FOLDER}/"
    # fi
    # export LDFLAGS

    export CXXFLAGS="${CXXFLAGS:-} -fpermissive"
    GCC_BUILD_DIR=${TMP_GCC}/gcc_build
    mkdir -p ${GCC_BUILD_DIR}
    cd ${GCC_BUILD_DIR}
    [ ! -f /Makefile ] && \
        ${TMP_GCC}/${GCC_FOLDER}/configure \
            --target=${TARGET} \
            --build=${TARGET} \
            --host=${TARGET} \
            --disable-multilib \
            --disable-nls \
            --disable-canonical-system-headers \
            --with-system-zlib \
            --enable-bootstrap \
            --disable-libssp \
            --enable-checking=release \
            --enable-default-pie \
            --enable-default-ssp \
            --disable-install-libiberty \
            --with-stage1-ldflags="${LDFLAGS:-}" \
            --with-boot-ldflags="${LDFLAGS:-} -static-libstdc++ -static-libgcc" \
            --enable-lto \
            --with-gnu-ld \
            --with-gnu-as \
            --with-gmp-include=${GCC_PREFIX}/include \
            --with-gmp-lib=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --with-mpfr-include=${GCC_PREFIX}/include \
            --with-mpfr-lib=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --with-mpc-include=${GCC_PREFIX}/include \
            --with-mpc-lib=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --without-zstd \
            --disable-libjava \
            --enable-host-shared \
            --enable-versioned-jit \
            --enable-languages=c,c++,fortran,go,jit,lto,objc,obj-c++ \
            --disable-libsanitizer \
            --libdir=${GCC_PREFIX}/${_SETUP_LIB_FOLDER} \
            --prefix=${GCC_PREFIX}
    make -j $(nproc) MAKEINFO=true
    make install MAKEINFO=true
    # create cc & f95 links
    (
        cd ${GCC_PREFIX}/bin
        [ ! -f cc  ] && ln -s gcc cc
        [ ! -f f95 ] && ln -s gfortran f95
    )
)
else
    echo "## -- Skip GCC"
fi

SPECSFILE_PATH=${GCC_PREFIX}/${_SETUP_LIB_FOLDER}/gcc/${TARGET}/12.5.0/specs
# note: we strip the last (empty) line, otherwise this causes char reading error ...
mkdir -p $(dirname ${SPECSFILE_PATH})
gcc -dumpspecs | sed '$d' > ${SPECSFILE_PATH}
cat >> $SPECSFILE_PATH << EOF

*link_libgcc:
+ -rpath ${GCC_PREFIX}/${_SETUP_LIB_FOLDER}

*self_spec:
+ -B${GCC_PREFIX}/bin

EOF

fi

##########################################################################################
## Setup OneAPI & VTune
##########################################################################################

VTUNE_VERSION=2025.7.0
ONEAPI_VERSION=2023.2.4
VTUNE_URL=https://registrationcenter-download.intel.com/akdlm/IRC_NAS/a04c89ad-d663-4f70-bd3d-bb44f5c16d57/intel-vtune-2025.7.0.248_offline.sh
ONEAPI_CC_URL="https://registrationcenter-download.intel.com/akdlm/IRC_NAS/b00a4b0e-bd21-41fa-ab34-19e8e2a77c5a/l_dpcpp-cpp-compiler_p_2023.2.4.24_offline.sh"
ONEAPI_FC_URL="https://registrationcenter-download.intel.com/akdlm/IRC_NAS/5bfaa204-689d-4bf1-9656-e37e35ea3fc2/l_fortran-compiler_p_2023.2.4.31_offline.sh"
VTUNE_CHECKSUM=4bc06c56eab368ee0ff57e87ea0f563663db6c60ea3f9cf9badf16928e43e321
ONEAPI_CC_CHECKSUM=f143a764adba04a41e49ec405856ad781e5c3754812e90a7ffe06d08cd07f684
ONEAPI_FC_CHECKSUM=2f327d67cd207399b327df5b7c912baae800811d0180485ef5431f106686c94b

[ ! -f ${CACHE_DIR}/$(basename ${VTUNE_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${VTUNE_URL}) -C - ${VTUNE_URL}
[ ! -f ${CACHE_DIR}/$(basename ${ONEAPI_CC_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${ONEAPI_CC_URL}) -C - ${ONEAPI_CC_URL}
[ ! -f ${CACHE_DIR}/$(basename ${ONEAPI_FC_URL}) ] && curl -L -o ${CACHE_DIR}/$(basename ${ONEAPI_FC_URL}) -C - ${ONEAPI_FC_URL}

VTUNE_FOLDER=$(basename ${VTUNE_URL} .sh)
ONEAPI_CC_FOLDER=$(basename ${ONEAPI_CC_URL} .sh)
ONEAPI_FC_FOLDER=$(basename ${ONEAPI_FC_URL} .sh)

BINPATH=${ONEAPI_PREFIX}/compiler/${ONEAPI_VERSION}/linux/bin/intel64
if [ ! -x ${BINPATH}/icc ]; then
    (
        echo "${ONEAPI_CC_CHECKSUM} ${CACHE_DIR}/$(basename ${ONEAPI_CC_URL})" | sha256sum -c
        # Use temporary home folder to prevent intel package installer from poluting
        # home with ${HOME}/intel/{installercache,oneapi,packagemanager,swip}
        # note: also enables bypassing potential $HOME quotas
        export HOME=${TMP_DIR}/home
        export TMP=${TMP_DIR}
        mkdir -p $HOME
        cleanup() {
            rm -rf ${TMP_DIR}/home ${TMP_DIR}/${ONEAPI_CC_FOLDER}
        }
        trap -- cleanup TERM INT QUIT EXIT HUP
        cd $HOME
        [ ! -d ${TMP_DIR}/${ONEAPI_CC_FOLDER} ] && (bash ${CACHE_DIR}/$(basename ${ONEAPI_CC_URL}) --extract-folder ${TMP_DIR}/ -x -r no)
        ${TMP_DIR}/${ONEAPI_CC_FOLDER}/install.sh \
            --action install \
            --silent \
            --eula accept \
            --install-dir ${ONEAPI_PREFIX} \
             --ignore-errors
    # see https://www.intel.com/content/www/us/en/docs/cpp-compiler/developer-guide-reference/2021-10/gcc-name.html
    # see https://www.intel.com/content/www/us/en/docs/cpp-compiler/developer-guide-reference/2021-10/gxx-name.html
# specify gcc 12.5.0 or lower
# -gcc-name=${BASE_GCC_LOCATION}/prefix/bin/gcc
# -gxx-name=${BASE_GCC_LOCATION}/prefix/bin/g++
# -Wl,-rpath,${BASE_GCC_LOCATION}/prefix/lib

        (grep 'diag-disable=10441' ${BINPATH}/icc.cfg &> /dev/null) || echo "-diag-disable=10441 -diag-disable=10121" >> ${BINPATH}/icc.cfg
        (grep 'diag-disable=10441' ${BINPATH}/icpc.cfg &> /dev/null) || echo "-diag-disable=10441 -diag-disable=10121" >> ${BINPATH}/icpc.cfg
    )
else
    echo "## -- Skip CC toolkit"
fi
if [ ! -x ${BINPATH}/ifort ]; then
    (
        echo "${ONEAPI_FC_CHECKSUM} ${CACHE_DIR}/$(basename ${ONEAPI_FC_URL})" | sha256sum -c
        # Use temporary home folder to prevent intel package installer from poluting
        # home with ${HOME}/intel/{installercache,oneapi,packagemanager,swip}
        export HOME=${TMP_DIR}/home
        export TMP=${TMP_DIR}
        mkdir -p $HOME
        cleanup() {
            rm -rf ${TMP_DIR}/home ${TMP_DIR}/${ONEAPI_FC_FOLDER}
        }
        trap -- cleanup TERM INT QUIT EXIT HUP
        cd $HOME
        [ ! -d ${TMP_DIR}/${ONEAPI_FC_FOLDER} ] && (bash ${CACHE_DIR}/$(basename ${ONEAPI_FC_URL}) --extract-folder ${TMP_DIR}/ -x -r no)
        ${TMP_DIR}/${ONEAPI_FC_FOLDER}/install.sh \
            --action install \
            --silent \
            --eula accept \
            --install-dir ${ONEAPI_PREFIX} \
             --ignore-errors
        (grep 'diag-disable=10441' ${BINPATH}/ifort.cfg &> /dev/null) || echo "-diag-disable=10441 -diag-disable=10121" >> ${BINPATH}/ifort.cfg
    )
else
    echo "## -- Skip FC toolkit"
fi
if [ ! -x ${ONEAPI_PREFIX}/vtune/latest/bin64/vtune ]; then
    (
        echo "${VTUNE_CHECKSUM} ${CACHE_DIR}/$(basename ${VTUNE_URL})" | sha256sum -c
        # Use temporary home folder to prevent intel package installer from poluting
        # home with ${HOME}/intel/{installercache,oneapi,packagemanager,swip}
        export HOME=${TMP_DIR}/home
        export TMP=${TMP_DIR}
        mkdir -p $HOME
        cleanup() {
            rm -rf ${TMP_DIR}/home ${TMP_DIR}/${VTUNE_FOLDER}
        }
        trap -- cleanup TERM INT QUIT EXIT HUP
        cd $HOME
        [ ! -d ${TMP_DIR}/${VTUNE_FOLDER} ] && (bash ${CACHE_DIR}/$(basename ${VTUNE_URL}) --extract-folder ${TMP_DIR}/ -x -r no)
        ${TMP_DIR}/${VTUNE_FOLDER}/install.sh \
            --action install \
            --silent \
            --eula accept \
            --install-dir ${ONEAPI_PREFIX} \
             --ignore-errors
    )
else
    echo "## -- Skip vtune"
fi

##########################################################################################
## Setup HPCW
##########################################################################################
export HPCW_SOURCE_DIR=${SCRIPT_DIR}/hpcw

if [ ! -d ${HPCW_SOURCE_DIR} ]; then
    git clone https://gitlab.dkrz.de/hpcw/hpcw.git ${HPCW_SOURCE_DIR}
    mkdir -p ${CACHE_DIR}/hpcw-store
    ln -s ${CACHE_DIR}/hpcw-store ${HPCW_SOURCE_DIR}
else
    echo "## -- skip HPCW clone"
fi
(
    cd ${HPCW_SOURCE_DIR}
    case $(git rev-parse HEAD) in
        ${HPCW_COMMIT}) echo "## -- skip HPCW checkout" ;;
        *) git checkout ${HPCW_COMMIT} ;;
    esac
)

# Generate custom toolchain for local intel
cat > ${HPCW_SOURCE_DIR}/toolchains/interactive/intel-custom.env.sh << EOF
#!/usr/bin/env bash

export CC=icc
export CXX=icpc
export FC=ifort

export ENVRC=hpcw-custom-intel

set +eu
source ${ONEAPI_PREFIX}/setvars.sh
set -eu

cmakeFlags+=" -DCMAKE_TOOLCHAIN_FILE=\${HPCW_SOURCE_DIR}/toolchains/interactive/toolchain.cmake"
cmakeFlags+=" -DUSE_SYSTEM_mpi=ON"

command -v \$CC
command -v \$CXX
command -v \$FC

EOF

##########################################################################################
## Run ecRad
##########################################################################################

RUN_DIR=${SCRIPT_DIR}/rundir
HPCW_BUILD_DIR=${RUN_DIR}/ecrad_build
HPCW_INSTALL_DIR=${RUN_DIR}/ecrad_install
HPCW_LOG_DIR=${RUN_DIR}/ecrad_log.$(date +"%Y%m%dT%H%M%S")
mkdir -p ${HPCW_BUILD_DIR} ${HPCW_LOG_DIR}

# export ENABLE_VTUNE=true
# export HPCW_VTUNE_COLLECT_MODE="hotspots"

${HPCW_SOURCE_DIR}/toolchains/build-wrapper.sh ${HPCW_SOURCE_DIR} interactive/intel-custom.env.sh \
    --build-dir=${HPCW_BUILD_DIR} \
    --install-dir=${HPCW_INSTALL_DIR} \
    --log-dir=${HPCW_LOG_DIR} \
    --with=ecrad --reconfigure --rebuild \
    --test --ctest-flags="-R ecrad-small"

##########################################################################################
## Exit
##########################################################################################
echo "## -- Done"
exit 0
