import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('release_cdn', Path(__file__).with_name('inspect-release-cdn.py'))
cdn = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cdn)


class CertificateSelectionTests(unittest.TestCase):
    def certificate(self, **changes):
        return dict(Domain='release.zyb.world', Status=1, Deployable=True,
                    CertBeginTime='2020-01-01 00:00:00', CertEndTime='2100-01-01 00:00:00', **changes)

    def test_current_issued_release_and_wildcard_certificates_are_eligible(self):
        cert = self.certificate()
        self.assertTrue(cdn.usable(cert))
        cert['Domain'] = '*.zyb.world'
        self.assertTrue(cdn.usable(cert))

    def test_other_domains_and_revoked_certificates_cannot_be_activated(self):
        cert = self.certificate()
        cert['Domain'] = 'www.zyb.world'
        self.assertFalse(cdn.usable(cert))
        cert['SubjectAltName'] = ['release.zyb.world']
        self.assertTrue(cdn.usable(cert))
        cert['Status'] = 10
        self.assertFalse(cdn.usable(cert))

    def test_expired_future_missing_date_or_non_deployable_certificates_are_rejected(self):
        for changes in ({'CertEndTime': '2020-01-02 00:00:00'},
                        {'CertBeginTime': '2099-01-01 00:00:00'},
                        {'CertEndTime': None}, {'Deployable': False}):
            cert = self.certificate()
            cert.update(changes)
            self.assertFalse(cdn.usable(cert), changes)


if __name__ == '__main__':
    unittest.main()
