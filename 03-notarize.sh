#!/bin/bash
set -euo pipefail

# check preconditions
command -v ditto >/dev/null 2>&1 || { echo >&2 "ditto not found."; exit 1; }
command -v xcrun >/dev/null 2>&1 || { echo >&2 "xcrun not found."; exit 1; }

# ask for app store connect credentials
echo "Enter your App Store Connect credentials for notarization."
read -p "Username: " AC_USERNAME
read -s -p "Password: " AC_PASSWORD
echo ""

# create .zip archive suitable for notarization
echo "Creating zip for notarization..."
ditto -c -k --keepParent buildkit/app/Cryptomator.app Cryptomator.zip

# upload .zip to the notarization service
echo "Uploading zip to notarization service..."
NOTARIZATION_REQUEST_UUID=$(xcrun altool --notarize-app --primary-bundle-id "org.cryptomator" --username "${AC_USERNAME}" --password "${AC_PASSWORD}" --file Cryptomator.zip | grep 'RequestUUID' | awk '{print $3}')
echo "Upload finished. RequestUUID: ${NOTARIZATION_REQUEST_UUID}"

# wait for notarization to finish
while :; do
  echo "Querying notarization request status..."
  sleep 30
  NOTARIZATION_INFO=$(xcrun altool --notarization-info "${NOTARIZATION_REQUEST_UUID}" --username "${AC_USERNAME}" --password "${AC_PASSWORD}")
  if [[ "${NOTARIZATION_INFO}" =~ "in progress" ]]; then
    continue
  elif [[ "${NOTARIZATION_INFO}" =~ "success" ]]; then
    echo "Notarization successful, see notarization info:"
    echo "${NOTARIZATION_INFO}"
    break
  else
    echo "Notarization failed, see notarization info:"
    echo "${NOTARIZATION_INFO}"
    exit 1
  fi
done

# staple notarization ticket to .app
echo "Stapling notarization ticket to app..."
xcrun stapler staple "buildkit/app/Cryptomator.app"
