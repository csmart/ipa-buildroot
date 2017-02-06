#!/usr/bin/env bash

set -xue
set -o pipefail

BR2_TARGET_DIR="${1}"

## Enable ironic-python-agent
mkdir -p "${BR2_TARGET_DIR}/etc/systemd/system/multi-user.target.wants"
ln -sf /etc/systemd/system/ironic-python-agent.service "${BR2_TARGET_DIR}/etc/systemd/system/multi-user.target.wants/"

## Enable ldconfig service, required by pyudev to load c library
ln -sf /usr/lib/systemd/system/ldconfig.service "${BR2_TARGET_DIR}/usr/lib/systemd/system/sysinit.target.wants/"

## This file will get clobbered by Git.
## Add your own commands to $(BR2_EXTERNAL_IPA_PATH)/../scripts/post-fakeroot.sh
