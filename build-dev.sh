#!/bin/bash
set -euo pipefail

GIT_BRANCH=${1:-develop}
APP_VERSION=`echo "${1:-0.0.1}" | sed -rn 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/p'`
CODESIGN_IDENTITY=${2:-799C678CABFF99CD93DB2412E7C688CFB883A594}

# check preconditions
if [ ! -x ./01-create-app.sh ]; then echo "./01-create-app.sh not executable."; exit 1; fi
if [ ! -x ./02-codesign.sh ]; then echo "./02-codesign.sh not executable."; exit 1; fi

# cleanup
rm -rf buildkit runtimeImage

# build Cryptomator with all steps for production release
./01-create-app.sh ${GIT_BRANCH} ${APP_VERSION} || exit 1
./02-codesign.sh ${CODESIGN_IDENTITY} || exit 1
