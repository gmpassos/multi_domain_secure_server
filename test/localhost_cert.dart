import 'dart:convert';
import 'dart:io';

/// A self certificate private key.
/// Generated with:
/// ```
///  openssl genpkey -algorithm RSA -out server.key
/// ```
const localhostPrivateKey = '''
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDlyma8RimEMjia
YxR4VLKsrXMy8RLMSpg9KM6qvqMHpx4fikU85E+j2zbLDn9PrMJtjo67Ez+EORa8
5YabAUEbVooP+wzNdt+gveqq74Vu3WJnGiHqPVwuzB8TmwTFUxHQUuO+W+gHvIfw
88e5CmDwkbsL8twQiIIGFydErcBsxyTLOucxGSlPI34J+IcAaCLWezZL9VvtwHrO
FkBXioDZvdXIjWw6mi11fp5Sy3HwP6+GTkjUotTxrgRn+qdij8K6HIRUEE7GZcjp
gB83avZk0+eqejLlR2VA8zUpBn/dyu/8yui8qbeji5/VdEu7wuOaesv+UK9XDIvK
CirOYkUzAgMBAAECggEAJZLlHfJftdYxFjbkRnwcTor6vsDXljW4/gB5sUavHsBk
obtOG1OpHWhqEGWO9ga621zc7tm0tZimJKi9TAQ2UqjhthToC4KytLRz4OkodC/Z
TXWNnSEqZ8aIawAalW9ssW0/AHCZGLFrDcBhjzATbigjdyPfeF6chYVsri4LvF1m
deSHv5OlPZxH8PeBhRsgQskLCbEST0kOuWufTs7GGDh9hoYQL0ZuEAgZWBsilomj
r7qahIV4qFwIl5SBTSwDV7GLePUIe7wPAc3/H2Z3ywyTVBFTaKluahbUlkFWuHRt
4g4mh8hktLVdxIXrHSAVptjxpq81U7up3sjmJdlX+QKBgQD3r/jDRobEVJ76RATa
jgSDNo7Ksb2gU1wsTRIDYFtRTT91ZPh1ur5kycNrSyl7GdJa2fYG5CT59igR3eg5
O+UWnhqBwOF7iZ5VBUzEpFcussyOzCB9xzf5dF/fENHwZiYKBJy8oZHjXNRfHSk/
82lzvzIAucNkz2knq9+LR5S1mwKBgQDtgKsAle9nONcDv9l0opkSGX79B6e8rXNY
OjV10smKLzBI9hycxY9xKW6aDgcJ23E9Pr8UGN9bzwl+fsESGBAa8S5pejPkHNim
rdMpdPmLj+PpGIdbMOeViXUGVap3QbTzo23JeiVTq6xwh1gFw/cG576GEd/dGVy6
gJA7tTU0SQKBgQCvAbVBNLnQSwIxTpInYqUpmQj3ivKzL3M3EhWiMRkUrwIhjoBH
nvUb/buIOglLI4mQC+VcJSNDQnw5c5O7rOhHPNr5xzEKusgWxrHhV0UKh+clFnH2
rSaNqX57/ER6GZLTDUM5vOd5wIOF2PLmbrSZxgQsoxS+TBa+oyBGJwOZ9QKBgD8Z
pFUvgL+n9lhkrF20pX6Nj5OiaQpT+wVB0dpP+oPgLa/0031Db+zc2SnM+EnCJ7/h
39pzEUTPKPKWsq0f/4do9K/Ja+f7UgRWwneNQI+31xGjFrM/twef0ZuxPu0YY/8n
OJADB8/HGLV9AAHoIsWO5KuyLAwOJPjYF3oFlvEhAoGAXWcUOmeEdMMiEsUXKZ9u
cA2RhBbvRp9fPDM7eTAGIPcuuDaIrOJAlJY91/T12fqaWVnkCK+4D6mP1drmwVsJ
OaCpv2Ead9fIOOKAlgDu9FpYrPdeYbwHfGIqyF2EHRXxTjjX6Qr/DyyxtwDi17FP
84WixMwNDGQyshGm0L7QK7A=
-----END PRIVATE KEY-----
''';

/// A self certificate for "localhost" (10 years).
/// Generated with:
/// ```
///  openssl req -new -x509 -key server.key -out server.crt -days 3650 -subj "/CN=localhost"
/// ```
const localhostCertificate = '''
-----BEGIN CERTIFICATE-----
MIIDCTCCAfGgAwIBAgIUCIiVKmniS6dSegTjwBjhsUdJ5ugwDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI0MTIwMjAwMTM0OFoXDTM0MTEz
MDAwMTM0OFowFDESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0BAQEF
AAOCAQ8AMIIBCgKCAQEA5cpmvEYphDI4mmMUeFSyrK1zMvESzEqYPSjOqr6jB6ce
H4pFPORPo9s2yw5/T6zCbY6OuxM/hDkWvOWGmwFBG1aKD/sMzXbfoL3qqu+Fbt1i
Zxoh6j1cLswfE5sExVMR0FLjvlvoB7yH8PPHuQpg8JG7C/LcEIiCBhcnRK3AbMck
yzrnMRkpTyN+CfiHAGgi1ns2S/Vb7cB6zhZAV4qA2b3VyI1sOpotdX6eUstx8D+v
hk5I1KLU8a4EZ/qnYo/CuhyEVBBOxmXI6YAfN2r2ZNPnqnoy5UdlQPM1KQZ/3crv
/MrovKm3o4uf1XRLu8LjmnrL/lCvVwyLygoqzmJFMwIDAQABo1MwUTAdBgNVHQ4E
FgQU/hal+AEScNf/CAys/eo/jLUVVmUwHwYDVR0jBBgwFoAU/hal+AEScNf/CAys
/eo/jLUVVmUwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAGcI2
k5XFbGPdVM/mGELJylpAdZ/9EOvgUdMa5YTvo6VgQ4/cbmMNnZ6ItJSj8IgqR0bW
BnV4SImxaRx5mgICRrmI6vCV8u8jUNZpHBR8Y8TqXNlFmoftfKZHMHzx6QGfns+B
mJ7Wti8mWEZbWtCldSEjdVo+0uo6f8soQtOlV2VTTdCbC6Kq/Y+G43J5OqUzMQQy
E46W0f3rbV14wn/0WxNSepfiWcdy4aBUFO7UqF/1erXRayJ9eLm/hpuOccEKeMVL
SzcPxH0xpeKHBa9smJwRvNyK+E1GxYycqqr8uI+wHwtBuZwCy2ho7/1p1jNlTUXQ
laZR9YK9boPB0KAh0w==
-----END CERTIFICATE-----
''';

SecurityContext loadLocalhostSecurityContext() {
  var secureContext = SecurityContext();
  secureContext.useCertificateChainBytes(latin1.encode(localhostCertificate));
  secureContext.usePrivateKeyBytes(latin1.encode(localhostPrivateKey));
  return secureContext;
}
