#!/bin/bash
TAG_VERSION=${1:-snapshot}
GIT_BRANCH=${1:-develop}
CODESIGN_IDENTITY=${2:-307EF36B2A2EF98EB0AC0D24603A201BBDD4798B}

# check preconditions
command -v curl >/dev/null 2>&1 || { echo >&2 "curl not found."; exit 1; }
if [ ! -x ./01-create-app.sh ]; then echo "./01-create-app.sh not executable."; exit 1; fi
if [ ! -x ./02-codesign.sh ]; then echo "./02-codesign.sh not executable."; exit 1; fi
if [ ! -x ./03-notarize.sh ]; then echo "./03-notarize.sh not executable."; exit 1; fi
if [ ! -x ./04-create-dmg.sh ]; then echo "./04-create-dmg.sh not executable."; exit 1; fi

# cleanup
rm -rf buildkit.zip buildkit libMacFunctions.dylib Cryptomator.zip *.dmg

# download buildkit
echo "Downloading buildkit with version ${TAG_VERSION}..."
curl -o buildkit.zip -L https://dl.bintray.com/cryptomator/cryptomator/${TAG_VERSION}/buildkit-mac.zip

# build Cryptomator with all steps for production release
./01-create-app.sh ${GIT_BRANCH} || exit 1
./02-codesign.sh ${CODESIGN_IDENTITY} || exit 1
./03-notarize.sh || exit 1
./04-create-dmg.sh || exit 1
