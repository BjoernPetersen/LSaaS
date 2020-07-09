import binascii
import datetime
import os
from typing import List

from CloudFlare import CloudFlare

_zone_id = os.getenv("CLOUDFLARE_ZONE_ID")
token = os.getenv('CLOUDFLARE_TOKEN')

_client = CloudFlare(token=token)

_zone_name = os.getenv("CLOUDFLARE_ZONE_NAME")
infix = os.getenv("CLOUDFLARE_INFIX")


def _get_domain_space(instance_id: str) -> str:
    return f'{instance_id}.{infix}'


def get_wildcard_domain(instance_id: str) -> str:
    return f'*.{_get_domain_space(instance_id)}.{_zone_name}'


def register_domain(instance_id: str, ip: str) -> str:
    encoded_ip = binascii.b2a_hex(ip.encode('ascii')).decode('ascii')
    name = f'{encoded_ip}.{_get_domain_space(instance_id)}'
    _client.zones.dns_records.post(_zone_id, data={
        'name': name,
        'type': 'A',
        'content': ip
    })
    return f'{name}.{_zone_name}'


def unregister_domain(record_id):
    _client.zones.dns_records.delete(_zone_id, record_id)


def _is_outdated(record: dict) -> bool:
    name: str = record['name']
    if not name.endswith(f'.{infix}.{_zone_name}'):
        return False
    iso_creation_time = record['created_on'][:-1]
    created_on = datetime.datetime.fromisoformat(iso_creation_time)
    expiration = created_on + datetime.timedelta(days=90)
    now = datetime.datetime.now()
    return now >= expiration


def get_outdated_entries() -> List[str]:
    records = _client.zones.dns_records.get(_zone_id)
    return list(map(lambda it: it['id'], filter(_is_outdated, records)))
