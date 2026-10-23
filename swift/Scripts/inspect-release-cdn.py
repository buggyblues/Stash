#!/usr/bin/env python3
"""Read public certificate metadata only; never output keys or full config."""
import json
import os

from tencentcloud.common import credential
from tencentcloud.common.exception.tencent_cloud_sdk_exception import TencentCloudSDKException
from tencentcloud.cdn.v20180606 import cdn_client, models as cdn_models
from tencentcloud.ssl.v20191205 import ssl_client, models as ssl_models

DOMAIN = 'release.zyb.world'
credentials = credential.Credential(os.environ['TENCENT_SECRET_ID'], os.environ['TENCENT_SECRET_KEY'])

try:
    request = cdn_models.DescribeDomainsConfigRequest()
    request.from_json_string(json.dumps({'Filters': [{'Name': 'domain', 'Value': [DOMAIN]}], 'Limit': 100}))
    response = json.loads(cdn_client.CdnClient(credentials, '').DescribeDomainsConfig(request).to_json_string())
    for domain in response.get('Domains', []):
        if domain.get('Domain') != DOMAIN:
            continue
        https = domain.get('Https') or {}
        cert = https.get('CertInfo') or {}
        print(json.dumps({'domain': DOMAIN, 'https': https.get('Switch'), 'certificate': {
            key: cert.get(key) for key in ('CertId', 'CertName', 'ExpireTime', 'DeployTime')
        }}, ensure_ascii=False))
except TencentCloudSDKException as error:
    print('CDN metadata unavailable:', error.get_code())

try:
    request = ssl_models.DescribeCertificatesRequest()
    request.from_json_string(json.dumps({'SearchKey': 'zyb.world', 'Limit': 100, 'Offset': 0}))
    response = json.loads(ssl_client.SslClient(credentials, '').DescribeCertificates(request).to_json_string())
    for cert in response.get('Certificates', []):
        names = [cert.get('Domain'), *(cert.get('SubjectAltName') or [])]
        if DOMAIN not in names and '*.zyb.world' not in names:
            continue
        print(json.dumps({'matchingCertificate': {key: cert.get(key) for key in (
            'CertificateId', 'Domain', 'SubjectAltName', 'Status', 'CertBeginTime', 'CertEndTime', 'Deployable'
        )}}, ensure_ascii=False))
except TencentCloudSDKException as error:
    print('SSL metadata unavailable:', error.get_code())
