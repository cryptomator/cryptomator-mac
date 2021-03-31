#!/bin/bash
set -euo pipefail

GIT_BRANCH=${1:-develop}
APP_VERSION=${2:-0.0.1}

# check preconditions
if [ -z "${JAVA_HOME}" ]; then echo "JAVA_HOME not set. Run using JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-x.y.z.jdk/Contents/Home/ ./build.sh"; exit 1; fi
command -v jq >/dev/null 2>&1 || { echo >&2 "jq not found. Fix by 'brew install jq'."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "curl not found."; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "unzip not found."; exit 1; }

# unzip buildkit
echo "Unzipping buildkit..."
unzip -q buildkit.zip -d buildkit

# setting variables
COMMIT_COUNT=`curl -f -I "https://api.github.com/repos/cryptomator/cryptomator/commits?per_page=1&sha=${GIT_BRANCH}" | sed -rn '/^[Ll]ink:/s/.*page=([0-9]{4,}).*/\1/p'`
INSTALLER_COMMIT_COUNT=`git rev-list --count HEAD`
BUILD_VERSION=`cat buildkit/libs/version.txt`

# create .app
echo "Building Cryptomator ${BUILD_VERSION} (${COMMIT_COUNT})..."
${JAVA_HOME}/bin/jlink \
    --verbose \
    --output runtimeImage \
    --module-path ${JAVA_HOME}/jmods \
    --add-modules java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop,jdk.unsupported,java.net.http,jdk.crypto.ec,jdk.accessibility \
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
    --copyright "(C) 2016 - 2021 Skymatic GmbH" \
    --app-version ${APP_VERSION} \
    --java-options "-Djava.library.path=\"\$APPDIR:\$APPDIR/../MacOS:/usr/local/lib\"" \
    --java-options "-Dcryptomator.buildNumber=\"dmg-$COMMIT_COUNT.$INSTALLER_COMMIT_COUNT\"" \
    --java-options "-Dcryptomator.logDir=\"~/Library/Logs/Cryptomator\"" \
    --java-options "-Dcryptomator.settingsPath=\"~/Library/Application Support/Cryptomator/settings.json\"" \
    --java-options "-Dcryptomator.ipcPortPath=\"~/Library/Application Support/Cryptomator/ipcPort.bin\"" \
    --java-options "-Dcryptomator.showTrayIcon=true" \
    --java-options "-Xss2m" \
    --java-options "-Xmx512m" \
    --mac-package-identifier org.cryptomator \
    --resource-dir resources/app \
    --main-class org.cryptomator.launcher.Cryptomator \
    --main-jar launcher-${BUILD_VERSION}.jar 

# adjust .app
cp resources/app/Cryptomator-Vault.icns buildkit/app/Cryptomator.app/Contents/Resources/
sed -i '' "s|###BUNDLE_SHORT_VERSION_STRING###|${BUILD_VERSION}|g" buildkit/app/Cryptomator.app/Contents/Info.plist
sed -i '' "s|###BUNDLE_VERSION###|${COMMIT_COUNT}|g" buildkit/app/Cryptomator.app/Contents/Info.plist
