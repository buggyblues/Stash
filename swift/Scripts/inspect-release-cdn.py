#!/usr/bin/env python3
"""Inspect release TLS or bind an existing valid matching certificate.

Never retrieves private keys; activation changes only the certificate ID of
the existing HTTPS configuration for the fixed release domain.
"""
from datetime import datetime, timedelta, timezone
import json
import os

DOMAIN = 'release.zyb.world'


def covers_release(cert):
    names = [cert.get('Domain'), *(cert.get('SubjectAltName') or [])]
    return DOMAIN in names or '*.zyb.world' in names


def usable(cert):
    if not covers_release(cert) or cert.get('Status') != 1 or cert.get('Deployable') is not True:
        return False
    # Tencent SSL dates default to Beijing time. Fail closed for missing dates.
    zone = timezone(timedelta(hours=8))
    try:
        start = datetime.fromisoformat(cert['CertBeginTime']).replace(tzinfo=zone)
        end = datetime.fromisoformat(cert['CertEndTime']).replace(tzinfo=zone)
    except (KeyError, TypeError, ValueError):
        return False
    return start <= datetime.now(timezone.utc) < end


def main():
    from tencentcloud.common import credential
    from tencentcloud.cdn.v20180606 import cdn_client, models as cdn_models
    from tencentcloud.ssl.v20191205 import ssl_client, models as ssl_models

    credentials = credential.Credential(os.environ['TENCENT_SECRET_ID'], os.environ['TENCENT_SECRET_KEY'])
    cdn = cdn_client.CdnClient(credentials, '')
    request = cdn_models.DescribeDomainsConfigRequest()
    request.from_json_string(json.dumps({'Filters': [{'Name': 'domain', 'Value': [DOMAIN]}], 'Limit': 100}))
    response = json.loads(cdn.DescribeDomainsConfig(request).to_json_string())
    domain = next((x for x in response.get('Domains', []) if x.get('Domain') == DOMAIN), None)
    if domain is None or (domain.get('Https') or {}).get('Switch') != 'on':
        raise SystemExit('Expected existing release domain with HTTPS enabled')
    cert_info = domain['Https'].get('CertInfo') or {}
    print(json.dumps({'domain': DOMAIN, 'certificate': {
        key: cert_info.get(key) for key in ('CertId', 'CertName', 'ExpireTime', 'DeployTime')
    }}))

    request = ssl_models.DescribeCertificatesRequest()
    request.from_json_string(json.dumps({'SearchKey': 'zyb.world', 'Limit': 100, 'Offset': 0}))
    response = json.loads(ssl_client.SslClient(credentials, '').DescribeCertificates(request).to_json_string())
    certificates = [x for x in response.get('Certificates', []) if covers_release(x)]
    for cert in certificates:
        print(json.dumps({'matchingCertificate': {key: cert.get(key) for key in (
            'CertificateId', 'Domain', 'SubjectAltName', 'Status', 'CertBeginTime', 'CertEndTime', 'Deployable'
        )}}))

    selected_id = os.environ.get('CERTIFICATE_ID', '')
    if not selected_id:
        return
    selected = next((x for x in certificates if x.get('CertificateId') == selected_id), None)
    if selected is None or not usable(selected):
        raise SystemExit('Selected certificate is not currently valid, deployable and matched to release domain')
    if cert_info.get('CertId') == selected_id:
        print('Release domain already uses the selected certificate')
        return
    request = cdn_models.ModifyDomainConfigRequest()
    request.from_json_string(json.dumps({
        'Domain': DOMAIN, 'Route': 'Https.CertInfo.CertId', 'Value': json.dumps({'update': selected_id})
    }))
    result = cdn.ModifyDomainConfig(request)
    print(json.dumps({'certificateActivationRequested': selected_id, 'requestId': result.RequestId}))


if __name__ == '__main__':
    main()
