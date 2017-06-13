#!/usr/bin/env bash

## We use this script to compile Python wheels for IPA
## These are compiled using the buildroot host but installed into the target
##
## We use pip from get-pip.py, not Buildroot

# We want to know if anything fails
set -xue
set -o pipefail

# Path to target is always first argument, as per Buildroot
BR2_TARGET_DIR="${1}"

# Logs don't work cause /var/log is linked to /tmp which gets mounted over the top of
# NOTE: Do we want to write logs anyway, given we send to stdout?
# Disable for now, also see overlay journald.conf which sets logs to "none"
#[[ -L "${BR2_TARGET_DIR}/var/log" ]] && unlink "${BR2_TARGET_DIR}/var/log"

# IPA and Requirements Git URLs and versions
# If no repos are specified, default to upstream
# If no branches are specified, set nothing (use remote default/HEAD)
# Don't change these here, they should be set using Buildroot config
# These are passed through as arguments to this script
OPENSTACK_IPA_GIT_URL="${2:-https://git.openstack.org/openstack/ironic-python-agent}"
OPENSTACK_IPA_RELEASE="${3:-}"
OPENSTACK_REQUIREMENTS_GIT_URL="${4:-https://git.openstack.org/openstack/requirements}"
OPENSTACK_REQUIREMENTS_RELEASE="${5:-}"

# Where to build and store the Python wheelhouse (compiled binary packages)
PIP_DL_DIR="${BR2_EXTERNAL_IPA_PATH}/../dl/pip"
PIP_WHEELHOUSE="${BR2_EXTERNAL_IPA_PATH}/../dl/wheelhouse"
# Remove any old source and build dirs (we keep successful binary wheels only)
rm -Rf "${PIP_DL_DIR}"/{src,build}
# Make sure it exists for first time builds
mkdir -p "${PIP_DL_DIR}"/{src,build}

# Location to clone IPA and requirements locally for bundling
OPENSTACK_IPA_GIT_DIR="${PIP_DL_DIR}/src/ironic-python-agent"
OPENSTACK_REQUIREMENTS_GIT_DIR="${PIP_DL_DIR}/src/requirements"

# Python version, to make it easier to update
PYTHON_VERSION="python2.7"

# Get pip and install deps for creating Python wheels for IPA
rm -f "${PIP_DL_DIR}/get-pip.py"
wget https://bootstrap.pypa.io/get-pip.py -O "${PIP_DL_DIR}/get-pip.py"

# Force reinstall pip and install deps for building
"${HOST_DIR}/usr/bin/python" "${PIP_DL_DIR}/get-pip.py" --force-reinstall
"${HOST_DIR}/usr/bin/pip" install --upgrade pip
"${HOST_DIR}/usr/bin/pip" --cache-dir "${PIP_DL_DIR}" install appdirs packaging pbr setuptools wheel

# Git clone IPA source, wheel will build from this directory
rm -Rf "${OPENSTACK_IPA_GIT_DIR}"
git clone --depth 1 ${OPENSTACK_IPA_RELEASE:+--branch ${OPENSTACK_IPA_RELEASE}} "${OPENSTACK_IPA_GIT_URL}" "${OPENSTACK_IPA_GIT_DIR}"

# Git clone Requirements to get specified upper-constraints.txt
rm -Rf "${OPENSTACK_REQUIREMENTS_GIT_DIR}"
git clone --depth 1 ${OPENSTACK_REQUIREMENTS_RELEASE:+--branch ${OPENSTACK_REQUIREMENTS_RELEASE}} "${OPENSTACK_REQUIREMENTS_GIT_URL}" "${OPENSTACK_REQUIREMENTS_GIT_DIR}"

# Variables for Python builds for target
# HACK this needs cleaning up
_python_sysroot="$(find "${HOST_DIR}" -type d -name sysroot)"
export _python_sysroot
export _python_prefix=/usr
export _python_exec_prefix=/usr
export PYTHONPATH="${BR2_TARGET_DIR}/usr/lib/${PYTHON_VERSION}/sysconfigdata/:${BR2_TARGET_DIR}/usr/lib/${PYTHON_VERSION}/site-packages/"
export PATH="${HOST_DIR}"/bin:"${HOST_DIR}"/sbin:"${HOST_DIR}"/usr/bin:"${HOST_DIR}"/usr/sbin:${PATH}
export AR="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-ar
export AS="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-as
export LD="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-ld
export NM="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-nm
export CC="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-gcc
export GCC="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-gcc
export CPP="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-cpp
export CXX="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-g++
export FC="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-gfortran
export F77="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-gfortran
export RANLIB="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-ranlib
export READELF="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-readelf
export STRIP="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-strip
export OBJCOPY="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-objcopy
export OBJDUMP="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-objdump
export AR_FOR_BUILD=/usr/bin/ar
export AS_FOR_BUILD=/usr/bin/as
export CC_FOR_BUILD="${HOST_DIR}/usr/bin/ccache /usr/lib64/ccache/gcc"
export GCC_FOR_BUILD="${HOST_DIR}/usr/bin/ccache /usr/lib64/ccache/gcc"
export CXX_FOR_BUILD="${HOST_DIR}/usr/bin/ccache /usr/lib64/ccache/g++"
export LD_FOR_BUILD=/usr/bin/ld
export CPPFLAGS_FOR_BUILD="-I${HOST_DIR}/usr/include"
export CFLAGS_FOR_BUILD="-O2 -I${HOST_DIR}/usr/include"
export CXXFLAGS_FOR_BUILD="-O2 -I${HOST_DIR}/usr/include"
export LDFLAGS_FOR_BUILD="-L${HOST_DIR}/lib -L${HOST_DIR}/usr/lib -Wl,-rpath,${HOST_DIR}/usr/lib"
export FCFLAGS_FOR_BUILD=""
export DEFAULT_ASSEMBLER="${HOST_DIR}/usr/bin/x86_64-buildroot-linux-gnu-as"
export DEFAULT_LINKER="${HOST_DIR}/usr/bin/x86_64-buildroot-linux-gnu -ld"
export CPPFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64"
export CFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os "
export CXXFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os "
export LDFLAGS=""
export FCFLAGS=" -Os "
export FFLAGS=" -Os "
export PKG_CONFIG="${HOST_DIR}"/usr/bin/pkg-config
export STAGING_DIR="${HOST_DIR}"/usr/x86_64-buildroot-linux-gnu/sysroot
export INTLTOOL_PERL=/usr/bin/perl
export PIP_TARGET="${BR2_TARGET_DIR}/usr/lib/${PYTHON_VERSION}/site-packages"
export CC="${HOST_DIR}"/usr/bin/x86_64-buildroot-linux-gnu-gcc
export CFLAGS="-D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64 -Os "
export LDSHARED="${HOST_DIR}/usr/bin/x86_64-buildroot-linux-gnu-gcc -shared "
export LDFLAGS=""

# Build ironic-python-agent dependency wheels
"${HOST_DIR}/usr/bin/pip" wheel \
--src "${PIP_DL_DIR}/src/" \
--build "${PIP_DL_DIR}/build/" \
--wheel-dir "${PIP_WHEELHOUSE}" \
--constraint "${OPENSTACK_REQUIREMENTS_GIT_DIR}/upper-constraints.txt" \
--requirement "${OPENSTACK_IPA_GIT_DIR}/requirements.txt"

# Build ironic-python-agent from Git repo path
"${HOST_DIR}/usr/bin/pip" wheel \
--no-index \
--find-links="${PIP_WHEELHOUSE}" \
--src "${PIP_DL_DIR}/src/" \
--build "${PIP_DL_DIR}/build/" \
--wheel-dir "${PIP_WHEELHOUSE}" \
--constraint "${OPENSTACK_REQUIREMENTS_GIT_DIR}/upper-constraints.txt" \
--requirement "${OPENSTACK_IPA_GIT_DIR}/requirements.txt" \
"${OPENSTACK_IPA_GIT_DIR}"

# Install ironic-python-agent from our compiled wheels
"${HOST_DIR}/usr/bin/pip" install \
--no-compile \
--upgrade \
--force-reinstall \
--no-index \
--find-links="${PIP_WHEELHOUSE}" \
--constraint "${OPENSTACK_REQUIREMENTS_GIT_DIR}/upper-constraints.txt" \
--requirement "${OPENSTACK_IPA_GIT_DIR}/requirements.txt" \
ironic-python-agent

# Compile wheels for pip, setuptools and wheel for target
"${HOST_DIR}/usr/bin/pip" wheel \
--src "${PIP_DL_DIR}/src/" \
--build "${PIP_DL_DIR}/build/" \
--wheel-dir "${PIP_WHEELHOUSE}" \
pip setuptools wheel

# Install pip, setuptools and wheel for target to generate ironic-python-agent executable on boot
"${HOST_DIR}/usr/bin/pip" install \
--no-compile \
--upgrade \
--no-index \
--find-links="${PIP_WHEELHOUSE}" \
pip setuptools wheel

# Remove ensurepip to save space as we already installed pip and setuptools
rm -Rf "${BR2_TARGET_DIR}/usr/lib/${PYTHON_VERSION}/ensurepip"

# Optimise python and remove .py files except for IPA related (so we can modify if needed)
# HACK disabled for now, because we can rebuild the image it breaks things
# Might need to just use Buildroot's ability to use pyc instead
# Currently eventlet/green/http/client.py fails to compile, too
#"${HOST_DIR}/usr/bin/python" -OO -m compileall "${BR2_TARGET_DIR}/usr/lib/${PYTHON_VERSION}"
#find "${BR2_TARGET_DIR}/usr/lib/${PYTHON_VERSION}" -name '*.py' -regextype posix-egrep -not -regex ".*(eventlet|ironic_python_agent|ironic_lib)/.*" -not -empty -exec rm -v {} \;

# Copy target ldconfig in from build dir so we can create ld.so.cache for pyudev
install -m 755 -p -D "${BUILD_DIR}"/glibc*/*/*/ldconfig "${BR2_TARGET_DIR}/sbin/"
#find "${BUILD_DIR}"/glibc* -type f -name ldconfig -exec cp {} "${BR2_TARGET_DIR}/sbin/" \;
#chmod 755 "${BR2_TARGET_DIR}/sbin/ldconfig"

# Copy in ldconfig.service file from systemd, it will be enabled in post-fakeroot.sh
install -m 644 -p -D "${BUILD_DIR}"/systemd*/units/ldconfig.service "${BR2_TARGET_DIR}/usr/lib/systemd/system/"
#find "${BUILD_DIR}"/systemd*/units/ -type f -name ldconfig.service -exec cp {} "${BR2_TARGET_DIR}/usr/lib/systemd/system/" \;
#chmod 644 "${BR2_TARGET_DIR}/usr/lib/systemd/system/ldconfig.service"

# Ensure any SSH keys and configs have appropriate permissions,
# else it may fail to start and that would make life hard
# (Commands are separated out for clarity)
# System keys and configs
if [[ -d "${BR2_TARGET_DIR}/etc/ssh" ]]; then
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name ssh_config -exec chmod 0644 {} \;
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name "*pub" -exec chmod 0644 {} \;
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name sshd_config -exec chmod 0600 {} \;
	find "${BR2_TARGET_DIR}/etc/ssh" -type f -name "*key" -exec chmod 0600 {} \;
fi
# Fix root's keys and config
find "${BR2_TARGET_DIR}/root" -type f -name .rhosts -exec chmod 0600 {} \;
find "${BR2_TARGET_DIR}/root" -type f -name .shosts -exec chmod 0600 {} \;
if [[ -d "${BR2_TARGET_DIR}/root/.ssh" ]]; then
	# Enable root logins via ssh keys only, if we detect a public key
	# This hack is for convenience, it's better to provide new sshd_config in overlay
	if [[ -f "${BR2_TARGET_DIR}/root/.ssh/authorized_keys" ]]; then
		sed -i 's/^#PermitRootLogin.*/PermitRootLogin\ prohibit-password/g' "${BR2_TARGET_DIR}/etc/ssh/sshd_config"
	fi
	# Ensure root's home directory and other SSH related files are restricted
	chmod 0700 "${BR2_TARGET_DIR}/root"
	chmod 0700 "${BR2_TARGET_DIR}/root/.ssh"
	find "${BR2_TARGET_DIR}/root/.ssh" -type f -exec chmod 0600 {} \;
fi

## This file will get clobbered by Git.
## Add your own commands to $(BR2_EXTERNAL_IPA_PATH)/../scripts/post-build.sh
