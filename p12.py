from base64 import b64decode, b64encode

from OpenSSL import crypto


def convert_p12(event, context):
    passphrase = event['pass']
    cert = _decode_string(event['crt'])
    key = _decode_string(event['key'])

    p12_bytes = _convert_pem_to_p12(passphrase, cert, key)
    encoded = _encode_bytes(p12_bytes)
    return {
        'result': encoded
    }


def _convert_pem_to_p12(passphrase, cert, key) -> bytes:
    cert = crypto.load_certificate(crypto.FILETYPE_PEM, cert)
    key = crypto.load_privatekey(crypto.FILETYPE_PEM, key)
    p12 = crypto.PKCS12()
    p12.set_certificate(cert)
    p12.set_privatekey(key)
    return p12.export(passphrase)


def _encode_bytes(b: bytes) -> str:
    return b64encode(b).decode('ascii')


def _decode_string(s: str) -> str:
    return b64decode(s.encode('ascii')).decode('ascii')
