# Local network security as a service (LSaaS)

This free service allows you to obtain a publicly trusted TLS certificate for your
[MusicBot](https://github.com/BjoernPetersen/MusicBot) instance in the local network.

It works by creating a subdomain pointing to the local IP you supplied, solving a `DNS-01` challenge
and giving you the certificate signed by Let's Encrypt.

## Requesting an instance certificate

Send a request containing up to 20 IP address groups with up to 5 ip addresses each and
the desired key format to the service:

```
POST https://instance.kiu.party

{
    "ips": [
        "192.168.178.42",
        // These three will be associated with the same domain
        ["192.168.0.142", "10.0.0.2", "fde4:8dba:82e1::"]
    ],
    // Can be "pem", "p12" or "jks". Defaults to "pem" if missing.
    "keyFormat": "pem"
}
```

The IP addresses must be a private/local. Publicly available IP addresses will be rejected.

You'll get a response containing your new subdomains and a token to retrieve your certificate:

```json
{
    "wildcardDomain": "*.your-random-subdomain.instance.kiu.party",
    "domains": [
      {
        "domain": "first.your-random-subdomain.instance.kiu.party",
        "ips": ["192.168.178.42"]
      },
      {
        "domain": "second.your-random-subdomain.instance.kiu.party",
        "ip": ["192.168.0.142", "10.0.0.2", "fde4:8dba:82e1:0000:0000:0000:0000:0000"]
      }
    ],
    "token": "your-super-secret-token",
    "keyFormat": "pem"
}
```

## Retrieving your certificate

Solving the ACME-Challenge to get a certificate from Let's Encrypt might take a few minutes.
You'll have to check whether the certificate is ready yet until the process is done. The recommended
checking interval is 10 seconds.

Your request body should contain the token from the previous step:

```json
GET https://instance.kiu.party/your-super-secret-token
```

While the certificate is still being requested, the response will be:

```json
{
    "hasCertificate": false
}
```

When the process is done, you'll get a response containing the certificate for your subdomain.
You'll **only get a successful response once**, afterwards the certificate and private key are
deleted from the server and you are the only one who has it.
Keep your private key secret as it allows any holder of it to impersonate you.

Depending on the requested key format, exactly one of the keys `pem`, `p12` or `jks` will
be present. For `p12` and `jks` keys, your token will be the keystore passphrase.

```json
{
    "hasCertificate": true,
    "pem": {
        "crt": "Base64-encoded-certificate",
        "key": "Base64-encoded-private-key"
    },
    "p12": {
        "p12": "Base64-encoded-p12-file"
    },
    "jks": {
        "jks": "Base64-encoded-jks-file"
    }
}
```

## Certificate expiration

The certificate you'll receive is valid for 90 days and cannot be renewed. When your certificate
expires, your subdomain DNS records will be deleted and you'll have to request a new domain and
certificate.
