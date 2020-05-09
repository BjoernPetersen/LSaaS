import datetime
import os
from typing import List

from CloudFlare import CloudFlare

_zone_id = os.getenv("CLOUDFLARE_ZONE_ID")
token = os.getenv('CLOUDFLARE_TOKEN')

_client = CloudFlare(token=token)


def register_domain(instance_id: str, ip: str) -> str:
    name = f'{instance_id}.instance'
    _client.zones.dns_records.post(_zone_id, data={
        'name': name,
        'type': 'A',
        'content': ip
    })
    return f'{name}.kiu.party'


def unregister_domain(record_id):
    _client.zones.dns_records.delete(_zone_id, record_id)


def _is_outdated(record: dict) -> bool:
    name: str = record['name']
    if not name.endswith('.instance.kiu.party'):
        return False
    iso_creation_time = record['created_on'][:-1]
    created_on = datetime.datetime.fromisoformat(iso_creation_time)
    expiration = created_on + datetime.timedelta(days=90)
    now = datetime.datetime.now()
    return now >= expiration


def get_outdated_entries() -> List[str]:
    records = _client.zones.dns_records.get(_zone_id)
    return list(map(lambda it: it['id'], filter(_is_outdated, records)))

