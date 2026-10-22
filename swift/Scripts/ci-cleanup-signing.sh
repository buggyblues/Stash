#!/bin/bash
set -euo pipefail
folder="${RUNNER_TEMP:?}/stash-signing"
if [ -f "$folder/keychains-before.txt" ]; then
  python3 - "$folder/keychains-before.txt" <<'PYTHON'
import shlex,subprocess,sys
paths=shlex.split(open(sys.argv[1]).read())
subprocess.run(['security','list-keychains','-d','user','-s',*paths],check=True)
PYTHON
fi
if [ -f "$folder/release.keychain-db" ]; then security delete-keychain "$folder/release.keychain-db"; fi
rm -rf "$folder"
