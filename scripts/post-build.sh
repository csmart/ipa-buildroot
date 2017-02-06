#!/usr/bin/env bash

# This post-build.sh script is for user customisations
# It is executed after the board's post-build script so
# can be used to undo anything there, or add new changes

# We want to know if anything fails
set -xue
set -o pipefail

# Path to target is always first argument
BR2_TARGET_DIR="${1}"

## Add any commands below to be run after the build,
## before both fakeroot and image creation

