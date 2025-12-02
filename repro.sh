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
            rm -rfv ${TMP_CMAKE}
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

BINPATH=${ONEAPI_PREFIX}/compiler/${ONEAPI_VERSION}/linux/bin
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
