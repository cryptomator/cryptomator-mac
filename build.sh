#!/bin/bash
BUILD_VERSION=${1:-continuous}

# cleanup
rm -r antkit.tar.gz antbuild build.xml libs app *.dmg

# download ant-kit
curl -o antkit.tar.gz -L https://github.com/cryptomator/cryptomator/releases/download/${BUILD_VERSION}/antkit.tar.gz
tar -xzf antkit.tar.gz

# build .app
ant \
  -Dantbuild.logback.configurationFile="logback.xml" \
  -Dantbuild.cryptomator.settingsPath="~/Library/Application Support/Cryptomator/settings.json" \
  -Dantbuild.cryptomator.ipcPortPath="~/Library/Application Support/Cryptomator/ipcPort.bin" \
  -Dantbuild.cryptomator.keychainPath="" \
  -Dantbuild.dropinResourcesRoot="resources/app" \
  image
  
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
  --add-modules java.base,java.logging,java.xml,java.sql,java.management,java.security.sasl,java.naming,java.datatransfer,java.security.jgss,java.rmi,java.scripting,java.prefs,java.desktop,jdk.incubator.httpclient,javafx.fxml,javafx.controls,jdk.incubator.httpclient \
  --verbose

# adjust .app
cp resources/app/logback.xml antbuild/Cryptomator.app/Contents/Java/
cp resources/app/Cryptomator-Vault.icns antbuild/Cryptomator.app/Contents/Java/
cp resources/app/libMacFunctions.dylib antbuild/Cryptomator.app/Contents/Java/

# codesign
codesign --force --deep -s 307EF36B2A2EF98EB0AC0D24603A201BBDD4798B antbuild/Cryptomator.app

# print resulting .app to stdout
echo "Resulting App:"
find antbuild/Cryptomator.app
echo "--------"

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
