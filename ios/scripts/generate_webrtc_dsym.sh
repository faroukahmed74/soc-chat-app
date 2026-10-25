#!/bin/sh
# Generate a dSYM for the prebuilt WebRTC.framework so App Store Connect
# symbol upload succeeds, and so TestFlight/device launch does not fail when
# the Flutter engine initializes flutter_webrtc (see flutter-webrtc#1831).
set -e

FRAMEWORK_BIN="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/WebRTC.framework/WebRTC"

if [ ! -f "${FRAMEWORK_BIN}" ]; then
  echo "note: WebRTC.framework not found at ${FRAMEWORK_BIN}; skipping dSYM generation"
  exit 0
fi

case "${CONFIGURATION}" in
  Release|Profile) ;;
  *)
    echo "note: Skipping WebRTC dSYM generation for ${CONFIGURATION}"
    exit 0
    ;;
esac

echo "Generating WebRTC.framework.dSYM..."

# Archive dSYM folder (picked up by Organizer / symbol upload)
if [ -n "${DWARF_DSYM_FOLDER_PATH}" ]; then
  DSYM_PATH="${DWARF_DSYM_FOLDER_PATH}/WebRTC.framework.dSYM"
  rm -rf "${DSYM_PATH}"
  /usr/bin/dsymutil "${FRAMEWORK_BIN}" -o "${DSYM_PATH}"
  echo "WebRTC dSYM written to ${DSYM_PATH}"
  /usr/bin/dwarfdump --uuid "${DSYM_PATH}" || true
fi

# Also place next to build products (some Xcode flows expect this path)
if [ -n "${BUILT_PRODUCTS_DIR}" ]; then
  DSYM_PRODUCTS="${BUILT_PRODUCTS_DIR}/WebRTC.framework.dSYM"
  rm -rf "${DSYM_PRODUCTS}"
  /usr/bin/dsymutil "${FRAMEWORK_BIN}" -o "${DSYM_PRODUCTS}"
  echo "WebRTC dSYM also written to ${DSYM_PRODUCTS}"
fi
