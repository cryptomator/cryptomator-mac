#!/bin/bash
set -euo pipefail

BUILD_VERSION=`cat buildkit/libs/version.txt`

# check preconditions
if [ ! -x ./tools/create-dmg/create-dmg.sh ]; then echo "./tools/create-dmg/create-dmg.sh not executable."; exit 1; fi

# prepare .dmg
cp resources/dmg/macFUSE.webloc buildkit/app/

# create .dmg
echo "Creating dmg..."
./tools/create-dmg/create-dmg.sh \
  --volname Cryptomator \
  --volicon "resources/dmg/Cryptomator-Volume.icns" \
  --background "resources/dmg/Cryptomator-background.tiff" \
  --window-pos 400 100 \
  --window-size 640 694 \
  --icon-size 128 \
  --icon "Cryptomator.app" 128 245 \
  --hide-extension "Cryptomator.app" \
  --icon "macFUSE.webloc" 320 501 \
  --hide-extension "macFUSE.webloc" \
  --app-drop-link 512 245 \
  --eula "resources/dmg/license.rtf" \
  --icon ".background" 128 758 \
  --icon ".fseventsd" 320 758 \
  --icon ".VolumeIcon.icns" 512 758 \
  Cryptomator-${BUILD_VERSION}.dmg buildkit/app
