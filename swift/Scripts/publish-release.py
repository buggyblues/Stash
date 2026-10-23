#!/usr/bin/env python3
"""Publish both notarized native architectures and verify their public bytes."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import sys
import time
from urllib.request import urlopen


def digest_file(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def validate(root, version):
    files = []
    for arch in ('arm64', 'x64'):
        manifest_path = root / f'manifest-{arch}.json'
        manifest = json.loads(manifest_path.read_text())
        if (manifest.get('version') != version or manifest.get('architecture') != arch
                or manifest.get('implementation') != 'swift' or manifest.get('notarized') is not True):
            raise ValueError(f'Invalid native release manifest: {manifest_path.name}')
        expected = {f'Stash-{version}-{arch}.{suffix}' for suffix in ('zip', 'dmg')}
        if {entry['name'] for entry in manifest['files']} != expected:
            raise ValueError(f'Unexpected package list for {arch}')
        for entry in manifest['files']:
            path = root / entry['name']
            if path.stat().st_size != entry['bytes'] or digest_file(path) != entry['sha256']:
                raise ValueError(f'Package checksum mismatch: {path.name}')
            files.append(path)
        files.append(manifest_path)
    checksums = root / 'SHA256SUMS'
    checksums.write_text(''.join(f'{digest_file(path)}  {path.name}\n' for path in files))
    return [*files, checksums]


def verify_public(url, path):
    for attempt in range(5):
        try:
            digest = hashlib.sha256()
            size = 0
            with urlopen(url, timeout=120) as response:
                for block in iter(lambda: response.read(1024 * 1024), b''):
                    digest.update(block)
                    size += len(block)
            if size != path.stat().st_size or digest.hexdigest() != digest_file(path):
                raise ValueError(f'Public artifact mismatch: {path.name}')
            print(f'CDN verified: {url} ({size} bytes)')
            return
        except Exception:
            if attempt == 4:
                raise
            time.sleep(5 * (attempt + 1))


def upload(client, bucket, key, path, content_type):
    # Native packages are only a few MB. Avoid the SDK's default 1 MB multipart
    # uploads, which failed repeatedly between GitHub runners and COS.
    for attempt in range(3):
        try:
            client.upload_file(
                Bucket=bucket, Key=key, LocalFilePath=str(path),
                PartSize=16, MAXThread=1, EnableMD5=True,
                ContentType=content_type,
                CacheControl='public,max-age=31536000,immutable')
            print(f'COS uploaded: {path.name}', flush=True)
            return
        except Exception as error:
            # SDK exceptions can include request details; keep credentials out of logs.
            print(f'Upload retry {attempt + 1}/3: {path.name} ({type(error).__name__})', flush=True)
            if attempt == 2:
                raise RuntimeError(f'COS upload failed: {path.name}') from None
            time.sleep(5 * (attempt + 1))


def main():
    from qcloud_cos import CosConfig, CosS3Client
    root = Path(sys.argv[1]).resolve()
    version = plistlib.loads((Path(__file__).parent / 'Info.plist').read_bytes())['CFBundleShortVersionString']
    files = validate(root, version)
    client = CosS3Client(CosConfig(
        Region=os.environ['COS_REGION'], SecretId=os.environ['TENCENT_SECRET_ID'],
        SecretKey=os.environ['TENCENT_SECRET_KEY'], Scheme='https'))
    bucket = os.environ['COS_BUCKET']
    prefix = f'Stash/releases/v{version}'
    for path in files:
        key = f'{prefix}/{path.name}'
        content_type = ('application/json' if path.suffix == '.json' else
                        'text/plain' if path.name == 'SHA256SUMS' else 'application/octet-stream')
        upload(client, bucket, key, path, content_type)
        verify_public(f'https://release.zyb.world/{key}', path)


if __name__ == '__main__':
    main()
