#!/bin/bash
GIT_BRANCH=${1:-develop}
CODESIGN_IDENTITY=${2:-307EF36B2A2EF98EB0AC0D24603A201BBDD4798B}

# check preconditions
if [ ! -x ./01-create-app.sh ]; then echo "./01-create-app.sh not executable."; exit 1; fi
if [ ! -x ./02-codesign.sh ]; then echo "./02-codesign.sh not executable."; exit 1; fi

# cleanup
rm -rf buildkit libMacFunctions.dylib

# build Cryptomator with all steps for production release
./01-create-app.sh ${GIT_BRANCH} || exit 1
./02-codesign.sh ${CODESIGN_IDENTITY} || exit 1
