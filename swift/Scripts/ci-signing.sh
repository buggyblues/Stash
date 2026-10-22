#!/bin/bash
set -euo pipefail
: "${RUNNER_TEMP:?}" "${BUILD_CERTIFICATE_BASE64:?}" "${P12_PASSWORD:?}" "${APPLE_API_KEY_CONTENT:?}"
umask 077
folder="$RUNNER_TEMP/stash-signing"
mkdir -p "$folder"
security list-keychains -d user > "$folder/keychains-before.txt"
keychain="$folder/release.keychain-db"
password=$(openssl rand -hex 24)
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 7200 "$keychain"
security unlock-keychain -p "$password" "$keychain"
printf '%s' "$BUILD_CERTIFICATE_BASE64" | base64 --decode > "$folder/certificate.p12"
security import "$folder/certificate.p12" -P "$P12_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
rm "$folder/certificate.p12"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
python3 - "$keychain" "$folder/keychains-before.txt" <<'PYTHON'
import shlex,subprocess,sys
paths=shlex.split(open(sys.argv[2]).read())
subprocess.run(['security','list-keychains','-d','user','-s',sys.argv[1],*paths],check=True)
PYTHON
identity=$(security find-identity -v -p codesigning "$keychain" | sed -En 's/.*"(Developer ID Application:[^"]+)".*/\1/p' | head -1)
[ -n "$identity" ] || { echo 'Developer ID Application signing identity not found' >&2; exit 1; }
printf '%s' "$APPLE_API_KEY_CONTENT" | base64 --decode > "$folder/AuthKey.p8"
printf 'STASH_SIGN_IDENTITY=%s\nSTASH_NOTARY_KEY=%s\n' "$identity" "$folder/AuthKey.p8" >> "$GITHUB_ENV"
