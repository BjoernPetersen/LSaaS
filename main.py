import hashlib
import json
import os
import secrets
from base64 import b64decode, b64encode
from ipaddress import ip_address, IPv4Address, IPv6Address
from typing import Optional, Set, Union, FrozenSet

import boto3
import sentry_sdk
from sewer.client import Client as SewerClient
from sewer.dns_providers import CloudFlareDns

import cloudflare

allowed_key_formats = ['pem', 'p12', 'jks']

_lambda_name_retrieve = os.getenv("LAMBDA_NAME_RETRIEVE")
_lambda_name_convert_p12 = os.getenv("LAMBDA_NAME_CONVERT_P12")
_lambda_name_convert_jks = os.getenv("LAMBDA_NAME_CONVERT_JKS")
_bucket_name = os.getenv("S3_BUCKET_NAME")


def _setup_sentry():
    dsn = os.getenv("SENTRY_DSN")
    sentry_sdk.init(
        dsn=dsn,
    )


def cleanup(event, context):
    _setup_sentry()
    outdated_ids = cloudflare.get_outdated_entries()
    for outdated_id in outdated_ids:
        cloudflare.unregister_domain(outdated_id)


def _get_format(event):
    try:
        result = event['keyFormat']
        if result in allowed_key_formats:
            return result
        else:
            raise ValueError(f'Invalid key format. Allowed values: {allowed_key_formats}')
    except KeyError:
        return 'pem'


def post_request(event, context):
    _setup_sentry()
    instance_id = context.aws_request_id
    ips = event['ips']
    unique_ip_sets: Set[FrozenSet[Union[IPv4Address, IPv6Address]]] = set()

    for ip_set in ips:
        if isinstance(ip_set, list):
            unique_ip_set = set()
            for ip in ip_set:
                ip_add = _parse_ip(ip)
                if not ip_add:
                    raise ValueError(f'Invalid IP supplied: {ip}')
                unique_ip_set.add(ip_add)
            unique_ip_sets.add(frozenset(unique_ip_set))
        else:
            ip: str = ip_set
            ip_add = _parse_ip(ip)
            unique_ip_sets.add(frozenset([ip_add]))

    domains = []
    for unique_ip_set in unique_ip_sets:
        print(f'Registering: {unique_ip_set}')
        domain_name = cloudflare.register_domain(instance_id, unique_ip_set)
        domains.append({
            'ips': list(map(lambda x: x.exploded, unique_ip_set)),
            'domain': domain_name
        })

    key_format = _get_format(event)
    token = secrets.token_hex(64)
    wildcard_domain = cloudflare.get_wildcard_domain(instance_id)

    result = {
        'wildcardDomain': wildcard_domain,
        'domains': domains,
        'keyFormat': key_format,
        'token': token
    }

    _invoke_lambda(_lambda_name_retrieve, result)

    return result


def _invoke_lambda(name, payload, sync=False):
    lamb = boto3.client('lambda')
    return lamb.invoke(
        FunctionName=name,
        InvocationType='RequestResponse' if sync else 'Event',
        Payload=json.dumps(payload)
    )


def process_request(event, context):
    _setup_sentry()
    wildcard_domain = event['wildcardDomain']
    token = event['token']
    key_format = event['keyFormat']
    folder = f'{token}/{key_format}'
    crt, key = _get_cert(wildcard_domain)
    crt = crt.encode(encoding='ascii')
    key = key.encode(encoding='ascii')
    if key_format == 'pem':
        # We're done here
        _store_object(crt, folder, 'crt')
        _store_object(key, folder, 'key')
    else:
        # We need the p12 format as an intermediate format for JKS too
        payload = {
            'pass': token,
            'crt': _encode_string(crt),
            'key': _encode_string(key),
        }
        response = _invoke_lambda(_lambda_name_convert_p12, payload, sync=True)
        data = _read_lambda_response(response)
        p12 = data['result']
        if key_format == 'p12':
            _store_object(_decode_string(p12), folder, 'p12')
        elif key_format == 'jks':
            payload = {
                'pass': token,
                'p12': p12,
            }
            response = _invoke_lambda(_lambda_name_convert_jks, payload, sync=True)
            data = _read_lambda_response(response)
            jks = data['result']
            _store_object(_decode_string(jks), folder, 'jks')
        else:
            raise ValueError(f'Unexpected key format: {key_format}')


def _read_lambda_response(response) -> dict:
    raw_bytes: bytes = response['Payload'].read()
    raw = raw_bytes.decode('utf-8')
    return json.loads(raw)


def _store_object(content: bytes, folder, name):
    key = f'{folder}/{name}'
    md5 = hashlib.md5()
    md5.update(content)
    hashed = b64encode(md5.digest()).decode('ascii')
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(_bucket_name)
    bucket.put_object(
        Key=key,
        ContentMD5=hashed,
        Body=content
    )


def _list_objects(token) -> list:
    s3 = boto3.client('s3')
    response = s3.list_objects_v2(
        Bucket=_bucket_name,
        Prefix=token
    )
    try:
        contents = response['Contents']
    except KeyError:
        return []
    result = []
    for obj in contents:
        result.append(obj['Key'])
    return result


def _extract_key_format(object_keys: list) -> Optional[str]:
    if not object_keys:
        return None
    else:
        first: str = object_keys[0]
        key_format = first.split('/')[1]
        if key_format == 'pem' and len(object_keys) != 2:
            return None
        else:
            return key_format


def _get_file_name(object_key: str) -> str:
    return object_key.split('/')[-1]


def get_result(event, context):
    _setup_sentry()
    token = event['token']

    object_keys = _list_objects(token)
    key_format = _extract_key_format(object_keys)
    if not key_format:
        return {
            'hasCertificate': False
        }

    s3 = boto3.resource('s3')
    bucket = s3.Bucket(_bucket_name)

    result_data = dict()
    for key in object_keys:
        file_name = _get_file_name(key)
        path = f'/tmp/{token}.{file_name}'
        bucket.download_file(key, path)
        with open(path, 'rb') as file:
            content = file.read()
        encoded = _encode_string(content)
        result_data[file_name] = encoded

    bucket.delete_objects(
        Delete={
            'Objects': [{'Key': key} for key in object_keys],
        },
    )

    return {
        'hasCertificate': True,
        key_format: result_data
    }


def _encode_string(s: bytes) -> str:
    return b64encode(s).decode('ascii')


def _decode_string(s: str) -> bytes:
    return b64decode(s.encode('ascii'))


def _parse_ip(ip: str) -> Optional[Union[IPv4Address, IPv6Address]]:
    try:
        address: Union[IPv4Address, IPv6Address] = ip_address(ip)
    except ValueError:
        return None
    if not address.is_private or address.is_reserved:
        return None
    return address


def _get_cert(domain_name: str):
    dns = CloudFlareDns(CLOUDFLARE_TOKEN=cloudflare.token)

    client = SewerClient(domain_name=domain_name, dns_class=dns, account_key=_get_account_key())
    certificate = client.cert()
    key = client.certificate_key

    return certificate, key


def _get_account_key() -> str:
    encoded = os.getenv('LE_ACCOUNT_KEY')
    decoded: bytes = b64decode(encoded)
    return decoded.decode(encoding='ascii')
