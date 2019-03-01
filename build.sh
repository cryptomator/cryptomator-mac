#!/bin/bash
TAG_VERSION=${1:-snapshot}

# check preconditions
if [ -z "${JAVA_HOME}" ]; then echo "JAVA_HOME not set. Run using JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-x.y.z.jdk/Contents/Home/ ./build.sh"; exit 1; fi
if [ ! -x ./tools/packager/jpackager ]; then echo "../tools/packager/jpackager not executable."; exit 1; fi
if [ ! -x ./tools/create-dmg/create-dmg.sh ]; then echo "./tools/create-dmg/create-dmg.sh not executable."; exit 1; fi
command -v jq >/dev/null 2>&1 || { echo >&2 "jq not found."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "curl not found."; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "unzip not found."; exit 1; }
command -v codesign >/dev/null 2>&1 || { echo >&2 "codesign not found. Fix by 'xcode-select --install'."; exit 1; }

# cleanup
rm -rf buildkit.zip libs app *.dmg

# download buildkit
curl -o buildkit.zip -L https://dl.bintray.com/cryptomator/cryptomator/${TAG_VERSION}/buildkit-mac.zip
unzip buildkit.zip
if [ $? -ne 0 ]; then
  echo >&2 "unzipping buildkit.zip failed.";
  exit 1;
fi

# setting variables
FIRST_COMMIT='b78ee8295df7f66055b9aaa504c0008aa51ee1d4'
LATEST_COMMIT=`curl -s "https://api.github.com/repos/cryptomator/cryptomator/git/refs/heads/master" | jq -r '.object.sha'`
COMMIT_COUNT=`curl -s "https://api.github.com/repos/cryptomator/cryptomator/compare/${FIRST_COMMIT}...${LATEST_COMMIT}" | jq -r '.total_commits'`
BUILD_VERSION=`cat libs/version.txt`
echo "Building Cryptomator ${BUILD_VERSION} (${COMMIT_COUNT})..."

# create .app
./tools/packager/jpackager create-image \
    --verbose \
    --echo-mode \
    --input libs \
    --main-jar launcher-${BUILD_VERSION}.jar  \
    --class org.cryptomator.launcher.Cryptomator \
    --jvm-args "-Dcryptomator.logDir=\"~/Library/Logs/Cryptomator\"" \
    --jvm-args "-Dcryptomator.settingsPath=\"~/Library/Application Support/Cryptomator/settings.json\"" \
    --jvm-args "-Dcryptomator.ipcPortPath=\"~/Library/Application Support/Cryptomator/ipcPort.bin\"" \
    --jvm-args "-Dcryptomator.mountPointsDir=\"/Volumes\"" \
    --jvm-args "-Xss2m" \
    --jvm-args "-Xmx512m" \
    --output app \
    --force \
    --identifier org.cryptomator \
    --name Cryptomator \
    --version ${BUILD_VERSION} \
    --module-path ${JAVA_HOME}/jmods\
    --add-modules java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop,jdk.unsupported \
    --strip-native-commands

# adjust .app
cp resources/app/Info.plist app/Cryptomator.app/Contents/
cp resources/app/Cryptomator.icns app/Cryptomator.app/Contents/Resources/
cp resources/app/Cryptomator-Vault.icns app/Cryptomator.app/Contents/Resources/
cp resources/app/libMacFunctions.dylib app/Cryptomator.app/Contents/Java/
sed -i '' "s|###BUILD_VERSION###|${BUILD_VERSION}|g" app/Cryptomator.app/Contents/Info.plist
sed -i '' "s|###COMMIT_COUNT###|${COMMIT_COUNT}|g" app/Cryptomator.app/Contents/Info.plist

# prepare .dmg
cp resources/dmg/FUSE\ for\ macOS.webloc app/

# codesign
codesign --force --deep -s 307EF36B2A2EF98EB0AC0D24603A201BBDD4798B app/Cryptomator.app
if [ $? -ne 0 ]; then
  echo >&2 "codesigning .app failed.";
  exit 1;
fi

# create .dmg
./tools/create-dmg/create-dmg.sh \
  --volname Cryptomator \
  --volicon "resources/dmg/Cryptomator-Volume.icns" \
  --background "resources/dmg/Cryptomator-background.tiff" \
  --window-pos 400 100 \
  --window-size 640 694 \
  --icon-size 128 \
  --icon "Cryptomator.app" 128 245 \
  --hide-extension "Cryptomator.app" \
  --icon "FUSE for macOS.webloc" 320 501 \
  --hide-extension "FUSE for macOS.webloc" \
  --app-drop-link 512 245 \
  --eula "resources/dmg/license.rtf" \
  Cryptomator-${BUILD_VERSION}.dmg app
