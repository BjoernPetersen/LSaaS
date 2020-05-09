import hashlib
import json
import os
import secrets
from base64 import b64decode, b64encode
from ipaddress import ip_address, IPv4Address

import boto3
import sewer

import cloudflare


def cleanup(event, context):
    outdated_ids = cloudflare.get_outdated_entries()
    for outdated_id in outdated_ids:
        cloudflare.unregister_domain(outdated_id)


def post_request(event, context):
    instance_id = context.aws_request_id
    ip = event['ip']
    if not _is_valid_ip(ip):
        raise ValueError()
    domain_name = cloudflare.register_domain(instance_id, ip)

    token = secrets.token_hex(64)

    result = {
        'domain': domain_name,
        'token': token
    }

    lamb = boto3.client('lambda')
    lamb.invoke(
        FunctionName='LSaaS-GetCert',
        InvocationType='Event',
        Payload=json.dumps(result)
    )

    return result


def process_request(event, context):
    domain_name = event['domain']
    token = event['token']
    crt, key = _get_cert(domain_name)
    _store_object(crt, token, 'crt')
    _store_object(key, token, 'key')


def _store_object(content: str, folder, name):
    key = f'{folder}/{name}'
    encoded = content.encode(encoding='ascii')
    md5 = hashlib.md5()
    md5.update(encoded)
    hash = b64encode(md5.digest()).decode('ascii')
    s3 = boto3.resource('s3')
    bucket = s3.Bucket('lsaas')
    bucket.put_object(
        Key=key,
        ContentMD5=hash,
        Body=encoded
    )


def get_result(event, context):
    token = event['token']

    s3 = boto3.resource('s3')
    bucket = s3.Bucket('lsaas')

    cert_key = f'{token}/crt'
    key_key = f'{token}/key'
    cert_file = f'/tmp/{token}.crt'
    key_file = f'/tmp/{token}.key'
    try:
        bucket.download_file(cert_key, cert_file)
        bucket.download_file(key_key, key_file)
    except:
        return {
            'hasCertificate': False
        }

    bucket.delete_objects(
        Delete={
            'Objects': [
                {'Key': cert_key},
                {'Key': key_key}
            ],
        },
    )

    with open(cert_file, 'r') as file:
        crt = file.read()

    with open(key_file, 'r') as file:
        key = file.read()

    return {
        'hasCertificate': True,
        'certificate': {
            'crt': _encode_string(crt),
            'key': _encode_string(key)
        }
    }


def _encode_string(s: str) -> str:
    return b64encode(s.encode('ascii')).decode('ascii')


def _is_valid_ip(ip: str) -> bool:
    # TODO handle invalid IP error
    address: IPv4Address = ip_address(ip)
    return address.is_private and not address.is_reserved


def _get_cert(domain_name: str):
    dns = sewer.CloudFlareDns(CLOUDFLARE_TOKEN=cloudflare.token)

    client = sewer.Client(domain_name=domain_name, dns_class=dns, account_key=_get_account_key())
    certificate = client.cert()
    key = client.certificate_key

    return certificate, key


def _get_account_key() -> str:
    encoded = os.getenv('LE_ACCOUNT_KEY')
    decoded: bytes = b64decode(encoded)
    return decoded.decode(encoding='ascii')
