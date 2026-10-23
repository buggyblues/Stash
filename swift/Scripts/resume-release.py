#!/usr/bin/env python3
"""Authorize re-publication of unchanged artifacts from a trusted tested run."""
import base64
import json
import os
import plistlib
import re
import subprocess
from pathlib import Path


def validate_source(run, jobs, tag_commit, artifacts):
    if (run.get('repository', {}).get('full_name') != 'buggyblues/Stash'
            or run.get('path') != '.github/workflows/release.yml'
            or run.get('event') not in ('push', 'workflow_dispatch')
            or run.get('status') != 'completed'
            or run.get('head_sha') != tag_commit
            or run.get('head_branch') not in ('main', f'v{VERSION}')):
        raise ValueError('Source run is not a completed trusted release build for this tag')
    required = {'native-tests', 'mini-tests', 'package (macos-26, arm64)',
                'package (macos-26-intel, x64)'}
    passed = {job['name'] for job in jobs if job.get('conclusion') == 'success'}
    if not required <= passed:
        raise ValueError('Source run has not passed every native, mini and package gate')
    native = [item for item in artifacts if item['name'].startswith('native-')]
    if ({item['name'] for item in native} != {'native-arm64', 'native-x64'}
            or len(native) != 2 or any(item.get('expired', True) for item in native)):
        raise ValueError('Both original native artifacts must be available and unexpired')


def api(path):
    return json.loads(subprocess.run(
        ['gh', 'api', f'repos/buggyblues/Stash/{path}'],
        check=True, capture_output=True, text=True).stdout)


VERSION = plistlib.loads((Path(__file__).parent / 'Info.plist').read_bytes())['CFBundleShortVersionString']


def main():
    run_id = os.environ['SOURCE_RUN']
    if not re.fullmatch(r'[1-9][0-9]{0,19}', run_id):
        raise ValueError('Expected a numeric source run ID')
    run = api(f'actions/runs/{run_id}')
    jobs = api(f'actions/runs/{run_id}/jobs?per_page=100')['jobs']
    artifacts = api(f'actions/runs/{run_id}/artifacts?per_page=100')['artifacts']
    commit = api(f'commits/v{VERSION}')['sha']
    validate_source(run, jobs, commit, artifacts)
    source_plist = api(f'contents/swift/Scripts/Info.plist?ref={commit}')
    if plistlib.loads(base64.b64decode(source_plist['content']))['CFBundleShortVersionString'] != VERSION:
        raise ValueError('Version does not match original tested source')
    releases = api('releases?per_page=100')
    if any(item['tag_name'] == f'v{VERSION}' for item in releases):
        raise ValueError('Release already exists; do not overwrite published assets')
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write(f'version={VERSION}\ncommit={commit}\n')
    print(f'Authorized unchanged v{VERSION} artifacts from run {run_id}, commit {commit}')


if __name__ == '__main__':
    main()
