#!/bin/bash
# Native release packaging. Signing/notarization credentials are provided by CI.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Scripts/Info.plist)
architecture=${STASH_RELEASE_ARCH:-$(uname -m)}
if [ "$architecture" = x86_64 ]; then architecture=x64; fi
case "$architecture" in arm64|x64) ;; *) echo 'Unsupported architecture' >&2; exit 1;; esac
if [ -n "${GITHUB_REF_NAME:-}" ] && [[ "$GITHUB_REF_NAME" == v* ]] && [ "$GITHUB_REF_NAME" != "v$version" ]; then
  echo 'Tag and native app version differ' >&2; exit 1
fi
sdk=$(xcrun --sdk macosx --show-sdk-version)
if [ "${sdk%%.*}" -lt 26 ]; then echo 'Release builds require macOS SDK 26 or later for Liquid Glass.' >&2; exit 1; fi
swift --version | python3 -c 'import re,sys; version=re.search(r"Swift version (\d+)\.(\d+)",sys.stdin.read()); sys.exit(0 if version and tuple(map(int,version.groups())) >= (6,2) else "Release builds require Swift 6.2 or later for Liquid Glass.")'
mode=${STASH_RELEASE_MODE:-verify}
if [ "$mode" = publish ]; then
  : "${STASH_SIGN_IDENTITY:?Developer ID identity required}"
  : "${STASH_NOTARY_KEY:?Notary API key path required}"
  : "${APPLE_API_KEY_ID:?}" "${APPLE_API_ISSUER:?}"
  if [[ "$STASH_SIGN_IDENTITY" != 'Developer ID Application:'* ]]; then echo 'Public releases require a Developer ID Application certificate.' >&2; exit 1; fi
  bash Scripts/build-app.sh --sign "$STASH_SIGN_IDENTITY"
else
  bash Scripts/build-app.sh --sign -
fi
app=build/Stash.app
actual=$(lipo -archs "$app/Contents/MacOS/Stash")
expected=$architecture
if [ "$expected" = x64 ]; then expected=x86_64; fi
[ "$actual" = "$expected" ] || { echo "Unexpected executable architecture: $actual" >&2; exit 1; }
[ "$(/usr/libexec/PlistBuddy -c 'Print :StashImplementation' "$app/Contents/Info.plist")" = swift ]
output=build/release
mkdir -p "$output"
zip="$output/Stash-$version-$architecture.zip"
dmg="$output/Stash-$version-$architecture.dmg"
notarize() {
  local archive=$1 report=$2
  xcrun notarytool submit "$archive" --key "$STASH_NOTARY_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER" --wait --timeout 20m --output-format json > "$report"
  python3 - "$report" <<'JSON'
import json,sys
x=json.load(open(sys.argv[1]));print('Notarization:',x.get('id'),x.get('status'))
if x.get('status')!='Accepted': raise SystemExit('Apple did not accept notarization')
JSON
}
/usr/bin/ditto -c -k --keepParent "$app" "$zip"
if [ "$mode" = publish ]; then
  notarize "$zip" "$output/notary-app-$architecture.json"
  xcrun stapler staple "$app"
  xcrun stapler validate "$app"
  codesign --verify --deep --strict "$app"
  spctl --assess --type execute --verbose "$app"
  rm "$zip"
  /usr/bin/ditto -c -k --keepParent "$app" "$zip"
fi
stage=$(mktemp -d "${TMPDIR:-/tmp}/stash-dmg.XXXXXX")
trap 'rm -rf "$stage"' EXIT
/usr/bin/ditto "$app" "$stage/Stash.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "Stash $version" -srcfolder "$stage" -ov -format UDZO "$dmg"
if [ "$mode" = publish ]; then
  codesign --force --timestamp --sign "$STASH_SIGN_IDENTITY" "$dmg"
  notarize "$dmg" "$output/notary-dmg-$architecture.json"
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
fi
python3 - "$version" "$architecture" "$sdk" "$mode" <<'JSON'
from pathlib import Path
import hashlib,json,sys
version,arch,sdk,mode=sys.argv[1:]
root=Path('build/release');files=[]
for suffix in ['zip','dmg']:
 p=root/f'Stash-{version}-{arch}.{suffix}'
 files.append(dict(name=p.name,bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
(root/f'manifest-{arch}.json').write_text(json.dumps(dict(version=version,architecture=arch,implementation='swift',sdk=sdk,notarized=mode=='publish',files=files),indent=2)+'\n')
print(json.dumps(dict(version=version,architecture=arch,files=files),indent=2))
JSON
