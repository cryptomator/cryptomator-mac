#!/bin/bash
GIT_BRANCH=${1:-develop}

# check preconditions
if [ -z "${JAVA_HOME}" ]; then echo "JAVA_HOME not set. Run using JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-x.y.z.jdk/Contents/Home/ ./build.sh"; exit 1; fi
if [ ! -x ./tools/packager/jpackager ]; then echo "../tools/packager/jpackager not executable."; exit 1; fi
command -v jq >/dev/null 2>&1 || { echo >&2 "jq not found. Fix by 'brew install jq'."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "curl not found."; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "unzip not found."; exit 1; }

# unzip buildkit
echo "Unzipping buildkit..."
unzip -q buildkit.zip -d buildkit
if [ $? -ne 0 ]; then
  echo >&2 "Unzipping buildkit failed.";
  exit 1;
fi

# setting variables
FIRST_COMMIT='b78ee8295df7f66055b9aaa504c0008aa51ee1d4'
COMMIT_COUNT=$((`curl -s "https://api.github.com/repos/cryptomator/cryptomator/compare/${FIRST_COMMIT}...${GIT_BRANCH}" | jq -r '.total_commits'` + 1))
INSTALLER_COMMIT_COUNT=`git rev-list --count HEAD`
BUILD_VERSION=`cat buildkit/libs/version.txt`
FFI_VERSION=`cat buildkit/libs/ffi-version.txt`

# download libMacFunctions.dylib
echo "Downloading libMacFunctions.dylib with version ${FFI_VERSION}..."
curl -o libMacFunctions.dylib -L https://github.com/cryptomator/native-functions/releases/download/${FFI_VERSION}/libMacFunctions.dylib

# create .app
echo "Building Cryptomator ${BUILD_VERSION} (${COMMIT_COUNT})..."
./tools/packager/jpackager create-image \
    --verbose \
    --echo-mode \
    --input buildkit/libs \
    --main-jar launcher-${BUILD_VERSION}.jar  \
    --class org.cryptomator.launcher.Cryptomator \
    --jvm-args "-Djava.library.path=\"\$APPDIR/Java:\$APPDIR/MacOS:/usr/local/lib\"" \
    --jvm-args "-Dcryptomator.buildNumber=\"dmg-$COMMIT_COUNT.$INSTALLER_COMMIT_COUNT\"" \
    --jvm-args "-Dcryptomator.logDir=\"~/Library/Logs/Cryptomator\"" \
    --jvm-args "-Dcryptomator.settingsPath=\"~/Library/Application Support/Cryptomator/settings.json\"" \
    --jvm-args "-Dcryptomator.ipcPortPath=\"~/Library/Application Support/Cryptomator/ipcPort.bin\"" \
    --jvm-args "-Dcryptomator.mountPointsDir=\"/Volumes\"" \
    --jvm-args "-Xss2m" \
    --jvm-args "-Xmx512m" \
    --output buildkit/app \
    --force \
    --identifier org.cryptomator \
    --name Cryptomator \
    --version ${BUILD_VERSION} \
    --module-path ${JAVA_HOME}/jmods\
    --add-modules java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop,jdk.unsupported,java.net.http,jdk.crypto.ec \
    --strip-native-commands

# adjust .app
cp resources/app/Info.plist buildkit/app/Cryptomator.app/Contents/
cp resources/app/Cryptomator.icns buildkit/app/Cryptomator.app/Contents/Resources/
cp resources/app/Cryptomator-Vault.icns buildkit/app/Cryptomator.app/Contents/Resources/
cp libMacFunctions.dylib buildkit/app/Cryptomator.app/Contents/Java/
sed -i '' "s|###BUNDLE_SHORT_VERSION_STRING###|${BUILD_VERSION}|g" buildkit/app/Cryptomator.app/Contents/Info.plist
sed -i '' "s|###BUNDLE_VERSION###|${COMMIT_COUNT}|g" buildkit/app/Cryptomator.app/Contents/Info.plist
