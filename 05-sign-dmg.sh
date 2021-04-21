#!/bin/bash
set -euo pipefail

GPG_IDENTITY=${1:-INVALID_IDENTITY}
BUILD_VERSION=`cat buildkit/libs/version.txt`

# output sha-256
shasum -a 256 Cryptomator-${BUILD_VERSION}.dmg

# sign via gpg
gpg -u ${GPG_IDENTITY} --detach-sign -a Cryptomator-${BUILD_VERSION}.dmg
