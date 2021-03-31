#!/bin/bash
set -euo pipefail

TAG_VERSION=${1:-snapshot}
GIT_BRANCH=${1:-develop}
APP_VERSION=`echo "${1:-0.0.1}" | sed -rn 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'`
CODESIGN_IDENTITY=${2:-799C678CABFF99CD93DB2412E7C688CFB883A594}

# check preconditions
command -v curl >/dev/null 2>&1 || { echo >&2 "curl not found."; exit 1; }
if [ ! -x ./01-create-app.sh ]; then echo "./01-create-app.sh not executable."; exit 1; fi
if [ ! -x ./02-codesign.sh ]; then echo "./02-codesign.sh not executable."; exit 1; fi
if [ ! -x ./03-notarize.sh ]; then echo "./03-notarize.sh not executable."; exit 1; fi
if [ ! -x ./04-create-dmg.sh ]; then echo "./04-create-dmg.sh not executable."; exit 1; fi

# cleanup
rm -rf buildkit.zip buildkit runtimeImage Cryptomator.zip *.dmg

# download buildkit
echo "Downloading buildkit with version ${TAG_VERSION}..."
curl -o buildkit.zip -L https://github.com/cryptomator/cryptomator/releases/download/${TAG_VERSION}/buildkit-mac.zip

# build Cryptomator with all steps for production release
./01-create-app.sh ${GIT_BRANCH} ${APP_VERSION} || exit 1
./02-codesign.sh ${CODESIGN_IDENTITY} || exit 1
./03-notarize.sh || exit 1
./04-create-dmg.sh || exit 1
