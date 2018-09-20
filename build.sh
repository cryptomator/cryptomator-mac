#!/bin/bash
BUILD_VERSION=${1:-continuous}

# check preconditions
if [ -z "${JAVA_HOME}" ]; then echo "JAVA_HOME not set. Run using JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-x.y.z.jdk/Contents/Home/ ./build.sh"; exit 1; fi
if [ ! -x ${JAVA_HOME}/bin/jlink ]; then echo "${JAVA_HOME}/bin/jlink not executable."; exit 1; fi
command -v ant >/dev/null 2>&1 || { echo >&2 "ant not found. Fix by 'brew install ant'."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "curl not found."; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo >&2 "unzip not found."; exit 1; }
command -v codesign >/dev/null 2>&1 || { echo >&2 "codesign not found. Fix by 'xcode-select --install'."; exit 1; }

# cleanup
rm -rf antkit.zip antbuild build.xml libs app *.dmg

# download ant-kit
curl -o antkit.zip -L https://dl.bintray.com/cryptomator/cryptomator/antkit-${BUILD_VERSION}.zip
unzip antkit.zip
if [ $? -ne 0 ]; then
  echo >&2 "unzipping antkit.zip failed.";
  exit 1;
fi

# build .app
ant \
  -Dantbuild.logback.configurationFile="logback.xml" \
  -Dantbuild.cryptomator.settingsPath="~/Library/Application Support/Cryptomator/settings.json" \
  -Dantbuild.cryptomator.ipcPortPath="~/Library/Application Support/Cryptomator/ipcPort.bin" \
  -Dantbuild.cryptomator.keychainPath="" \
  -Dantbuild.dropinResourcesRoot="resources/app" \
  image
if [ $? -ne 0 ]; then
  echo >&2 "ant build failed.";
  exit 1;
fi
  
# replace jvm
rm -rf antbuild/Cryptomator.app/Contents/PlugIns/Java.runtime/Contents/Home
${JAVA_HOME}/bin/jlink \
  --module-path ${JAVA_HOME}/jmods \
  --compress 1 \
  --no-header-files \
  --strip-debug \
  --no-man-pages \
  --strip-native-commands \
  --output antbuild/Cryptomator.app/Contents/PlugIns/Java.runtime/Contents/Home \
  --add-modules java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop,javafx.fxml,javafx.controls \
  --verbose

# adjust .app
cp resources/app/logback.xml antbuild/Cryptomator.app/Contents/Java/
cp resources/app/Cryptomator-Vault.icns antbuild/Cryptomator.app/Contents/Java/
cp resources/app/libMacFunctions.dylib antbuild/Cryptomator.app/Contents/Java/

# codesign
codesign --force --deep -s 307EF36B2A2EF98EB0AC0D24603A201BBDD4798B antbuild/Cryptomator.app
if [ $? -ne 0 ]; then
  echo >&2 "codesigning .app failed.";
  exit 1;
fi

# create .dmg
mkdir app
cp -r antbuild/Cryptomator.app app/
cp resources/dmg/FUSE\ for\ macOS.webloc app/
create-dmg/create-dmg.sh \
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
