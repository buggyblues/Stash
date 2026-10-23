#!/usr/bin/env python3
import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import Mock, patch


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(f'{name}.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


publisher = load('publish-release')
recovery = load('resume-release')


class PublicationTests(unittest.TestCase):
    def test_upload_retries_same_file_without_multipart_defaults(self):
        client = Mock()
        client.upload_file.side_effect = [TimeoutError('private request'), None]
        with patch.object(publisher.time, 'sleep'):
            publisher.upload(client, 'bucket', 'version/file', Path('file'), 'application/octet-stream')
        self.assertEqual(client.upload_file.call_count, 2)
        first, second = client.upload_file.call_args_list
        self.assertEqual(first, second)
        self.assertEqual(first.kwargs['PartSize'], 16)
        self.assertEqual(first.kwargs['MAXThread'], 1)
        self.assertTrue(first.kwargs['EnableMD5'])

    def test_upload_has_bounded_retries_and_sanitized_error(self):
        client = Mock()
        client.upload_file.side_effect = TimeoutError('secret-request')
        with patch.object(publisher.time, 'sleep'):
            with self.assertRaisesRegex(RuntimeError, '^COS upload failed: file$'):
                publisher.upload(client, 'bucket', 'version/file', Path('file'), 'text/plain')
        self.assertEqual(client.upload_file.call_count, 3)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.run = {'repository': {'full_name': 'buggyblues/Stash'},
                    'path': '.github/workflows/release.yml', 'event': 'workflow_dispatch',
                    'status': 'completed', 'head_sha': 'tested', 'head_branch': 'main'}
        self.jobs = [{'name': name, 'conclusion': 'success'} for name in (
            'native-tests', 'mini-tests', 'package (macos-26, arm64)', 'package (macos-26-intel, x64)')]
        self.artifacts = [{'name': f'native-{arch}', 'expired': False} for arch in ('arm64', 'x64')]

    def verify(self):
        recovery.validate_source(self.run, self.jobs, 'tested', self.artifacts)

    def test_accepts_original_tested_artifacts(self):
        self.verify()

    def test_rejects_untested_tag_commit(self):
        self.run['head_sha'] = 'different'
        with self.assertRaises(ValueError): self.verify()

    def test_rejects_pull_request_and_untrusted_branch(self):
        original = copy.deepcopy(self.run)
        for key, value in [('event', 'pull_request'), ('head_branch', 'feature'),
                           ('status', 'in_progress'), ('path', 'other.yml')]:
            with self.subTest(key=key):
                self.run = {**original, key: value}
                with self.assertRaises(ValueError): self.verify()

    def test_requires_every_test_and_architecture_gate(self):
        for job in self.jobs:
            job['conclusion'] = 'failure'
            with self.subTest(name=job['name']):
                with self.assertRaises(ValueError): self.verify()
            job['conclusion'] = 'success'

    def test_rejects_expired_missing_or_duplicate_artifacts(self):
        original = copy.deepcopy(self.artifacts)
        for artifacts in ([{**original[0], 'expired': True}, original[1]],
                          original[:1], original + [original[0]]):
            self.artifacts = artifacts
            with self.assertRaises(ValueError): self.verify()


if __name__ == '__main__':
    unittest.main()
