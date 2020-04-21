#!/bin/bash
GIT_BRANCH=${1:-develop}

# check preconditions
if [ -z "${JAVA_HOME}" ]; then echo "JAVA_HOME not set. Run using JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-x.y.z.jdk/Contents/Home/ ./build.sh"; exit 1; fi
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
${JAVA_HOME}/bin/jlink \
    --verbose \
    --output runtimeImage \
    --module-path ${JAVA_HOME}/jmods \
    --add-modules java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop,jdk.unsupported,java.net.http,jdk.crypto.ec \
    --no-header-files \
    --no-man-pages \
    --strip-debug \
    --strip-native-commands \
    --compress=1

${JAVA_HOME}/bin/jpackage \
    --verbose \
    --type app-image \
    --runtime-image runtimeImage \
    --input buildkit/libs \
    --dest buildkit/app \
    --name Cryptomator \
    --vendor "Skymatic GmbH" \
    --copyright "(C) 2016 - 2020 Skymatic GmbH" \
    --app-version ${BUILD_VERSION} \
    --java-options "-Djava.library.path=\"\$APPDIR/app:\$APPDIR/MacOS:/usr/local/lib\"" \
    --java-options "-Dcryptomator.buildNumber=\"dmg-$COMMIT_COUNT.$INSTALLER_COMMIT_COUNT\"" \
    --java-options "-Dcryptomator.logDir=\"~/Library/Logs/Cryptomator\"" \
    --java-options "-Dcryptomator.settingsPath=\"~/Library/Application Support/Cryptomator/settings.json\"" \
    --java-options "-Dcryptomator.ipcPortPath=\"~/Library/Application Support/Cryptomator/ipcPort.bin\"" \
    --java-options "-Dcryptomator.mountPointsDir=\"/Volumes\"" \
    --java-options "-Xss2m" \
    --java-options "-Xmx512m" \
    --mac-package-identifier org.cryptomator \
    --resource-dir resources/app \
    --main-class org.cryptomator.launcher.Cryptomator \
    --main-jar launcher-${BUILD_VERSION}.jar 

# adjust .app
cp resources/app/Cryptomator-Vault.icns buildkit/app/Cryptomator.app/Contents/Resources/
cp libMacFunctions.dylib buildkit/app/Cryptomator.app/Contents/app/
sed -i '' "s|###BUNDLE_SHORT_VERSION_STRING###|${BUILD_VERSION}|g" buildkit/app/Cryptomator.app/Contents/Info.plist
sed -i '' "s|###BUNDLE_VERSION###|${COMMIT_COUNT}|g" buildkit/app/Cryptomator.app/Contents/Info.plist
