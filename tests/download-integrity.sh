#!/bin/bash
# Verify the download trust boundary without network access or executing a payload.
set -e
umask 077
[ "$EUID" = 0 ] || { echo 'Run as root'; exit 1; }
SOURCE=$(cd -- "$(dirname -- "$0")/.." && pwd -P)
TEST_DIR=$(mktemp -d /tmp/sb-download-test.XXXXXXXX)
awk '/^check_cdn$/{exit} {print}' "$SOURCE/sing-box.sh" > "$TEST_DIR/functions.sh"
set +e
source "$TEST_DIR/functions.sh"
set -e
trap 'rm -rf -- "$TEMP_DIR" "$TEST_DIR"' EXIT
CURL_CALLS=0
curl() {
  CURL_CALLS=$((CURL_CALLS+1))
  local output
  while [ "$#" -gt 0 ]; do
    if [ "$1" = -o ]; then output=$2; break; fi
    shift
  done
  printf 'test release bytes\n' > "$output"
  return "${CURL_RESULT:-0}"
}
URL=https://github.com/SagerNet/sing-box/releases/download/vtest/test.tar.gz
GOOD=$(printf 'test release bytes\n' | sha256sum)
GOOD=${GOOD%% *}
download_verified "$URL" "$GOOD" "$TEST_DIR/result"
grep -qx 'test release bytes' "$TEST_DIR/result"
printf 'existing verified file\n' > "$TEST_DIR/result"
if download_verified "$URL" "${GOOD/??/00}" "$TEST_DIR/result" 2>/dev/null; then
  echo 'FAIL: checksum mismatch accepted'; exit 1
fi
grep -qx 'existing verified file' "$TEST_DIR/result"
[ ! -e "$TEST_DIR/result.part" ]
CURL_RESULT=22
if download_verified "$URL" "$GOOD" "$TEST_DIR/result"; then
  echo 'FAIL: failed download accepted'; exit 1
fi
grep -qx 'existing verified file' "$TEST_DIR/result"
[ ! -e "$TEST_DIR/result.part" ]
BEFORE_CALLS=$CURL_CALLS
if download_verified https://example.com/unknown "$GOOD" "$TEST_DIR/result"; then exit 1; fi
[ "$BEFORE_CALLS" -eq "$CURL_CALLS" ]
printf 'PASS: valid checksum accepted; tampered/failed/unapproved downloads rejected; existing file preserved.\n'
