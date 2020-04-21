#!/bin/bash
CODESIGN_IDENTITY=${1:-INVALID_IDENTITY}

# check preconditions
command -v unzip >/dev/null 2>&1 || { echo >&2 "unzip not found."; exit 1; }
command -v zip >/dev/null 2>&1 || { echo >&2 "zip not found."; exit 1; }
command -v codesign >/dev/null 2>&1 || { echo >&2 "codesign not found. Fix by 'xcode-select --install'."; exit 1; }
if [[ ! `security find-identity -v -p codesigning | grep -w "${CODESIGN_IDENTITY}"` ]]; then echo "Given codesign identity is invalid."; exit 1; fi

# codesign
echo "Codesigning libs in runtime..."
find buildkit/app/Cryptomator.app/Contents/runtime/Contents/MacOS -name '*.dylib' -exec codesign --force -s ${CODESIGN_IDENTITY} {} \;
for JAR_PATH in buildkit/app/Cryptomator.app/Contents/app/*.jar; do
  if [[ `unzip -l ${JAR_PATH} | grep '.dylib\|.jnilib'` ]]; then
    JAR_FILENAME=$(basename ${JAR_PATH})
    OUTPUT_PATH=${JAR_PATH%.*}
    echo "Codesigning libs in ${JAR_FILENAME}..."
    unzip -q ${JAR_PATH} -d ${OUTPUT_PATH}
    find ${OUTPUT_PATH} -name '*.dylib' -exec codesign -s ${CODESIGN_IDENTITY} {} \;
    find ${OUTPUT_PATH} -name '*.jnilib' -exec codesign -s ${CODESIGN_IDENTITY} {} \;
    rm ${JAR_PATH}
    pushd ${OUTPUT_PATH} > /dev/null
    zip -qr ../${JAR_FILENAME} *
    popd > /dev/null
    rm -r ${OUTPUT_PATH}
  fi
done
echo "Codesigning libMacFunctions.dylib..."
codesign -s ${CODESIGN_IDENTITY} buildkit/app/Cryptomator.app/Contents/app/libMacFunctions.dylib
echo "Codesigning Cryptomator.app..."
codesign --force --deep --entitlements resources/app/Cryptomator.entitlements -o runtime -s ${CODESIGN_IDENTITY} buildkit/app/Cryptomator.app
