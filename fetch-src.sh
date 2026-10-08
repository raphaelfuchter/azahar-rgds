#!/bin/bash
# Clones Azahar at the tested tag and applies the patches in ./patches.
set -e
cd "$(dirname "$0")"
TAG=2126.1.2
[ -d src ] || git clone --depth 1 --branch "$TAG" --recurse-submodules --shallow-submodules \
    https://github.com/azahar-emu/azahar.git src
for p in patches/*.patch; do git -C src apply "../$p"; echo "applied $p"; done
