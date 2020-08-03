# Local network security as a service (LSaaS)

This free service allows you to obtain a publicly trusted TLS certificate for your
local network service (e.g. a [MusicBot](https://github.com/BjoernPetersen/MusicBot) instance).

It works by creating a subdomain pointing to the local IP you supplied, solving a `DNS-01` challenge
and giving you the certificate signed by Let's Encrypt.

## Motivation

Imagine you want to distribute a network service that's deployed in the respective local network of 
your users. Let's say the service is now available at the IP `192.168.1.52`. To properly encrypt
connections to that service, you'll want to use HTTPS. The problem is: HTTPS relies on your server
serving a trusted certificate. To achieve that, you have two options:

1. Create a self-signed certificate and install it on every single client device.
2. Create a DNS entry for some domain pointing to the local IP and obtain a publicly trusted
certificate for that domain (e.g. through LetsEncrypt).

Using option 1 is easy to set up server-side, but requires access to every client device and may be
unreasonably cumbersome on some devices. It's essentially deferring the setup to every single end
user.

Using option 2 requires your user – that's the one who sets up the server software – to set up his
own (sub-)domain. It's unreasonable to expect your users to own a domain to deploy your software in
their local network. Obtaining a certificate for that domain would then require solving a `DNS-01`
challenge, as the domain isn't available from outside the local network. Solving that either
requires your user to obtain the certificate themselves or giving your software access to modify the
domain's DNS entries, which requires more trust from the user than should be required to use your
software. It also adds another pile of complexity to your local software because it has to access
different DNS registrar APIs.

## How LSaaS works

This project provides a public API that receives a list of your local IP addresses (e.g. `10.0.0.42`,
`192.168.178.14`) and then performs all steps necessary to serve your local service at those IP
addresses using a unique subdomain with a valid TLS certificate (equivalent of option 2 above).
To achieve that it performs the following steps:

- Create a new subdomain as your namespace: `request-id.kiu.party`
- Obtain a wildcard certificate for that subdomain (`*.request-id.kiu.party`) from LetsEncrypt
- Create DNS `A` and/or `AAAA` records for your supplied IPs (`encoded-ip.request-id.kiu.party`)
- Give you the certificate and the names of the created domains
- Delete the certificate so you're the only one in possession of it

Using this service of course requires you to trust this service not to create more certificates
for "your" domain and not to delete the DNS records before expiration. That's because the created
subdomains are technically still under full control of the domain owner, who's also the service
provider.

### Self-hosting the service

The infrastructure for this service is described as code in the
[`terraform directory`](./terraform), so it's theoretically possible to easily host the service
yourself. The code is geared towards a very specific setup though: It assumes you're
hosting the service itself on AWS (using API Gateway + Lambda), and use Cloudflare for DNS
management.

## Requesting an instance certificate

Send a request containing up to 20 IP address groups with up to 5 IP addresses each and
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
