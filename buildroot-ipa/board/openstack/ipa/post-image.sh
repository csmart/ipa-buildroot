#!/usr/bin/env bash

set -xue
set -o pipefail

BR2_TARGET_DIR="${1}"

## This file will get clobbered by Git.
## Add your own commands to $(BR2_EXTERNAL_IPA_PATH)/../scripts/post-image.sh
