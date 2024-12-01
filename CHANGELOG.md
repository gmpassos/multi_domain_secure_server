## 1.0.6

- `MultiDomainSecureServer`:
  - Added field `requiresHandshakesWithHostname`.
  - `extractSNIHostname`: log any parsing exception/error.
  - `parseSNIHostname`: improve parsing.
  - Added `isValidHostname`.

- `RawSocketAsSocket`:
  - Implemented `_writeQueue` and `flush` using socket events (`RawSocketEvent.write`).

- New `RawSecureSocketAsSecureSocket`.
- New `RawServerSocketAsSecureServerSocket`.
- New `RawSecureServerSocketAsSecureServerSocket`.

- `RawServerSocketExtension`:
  - Added `asSecureServerSocket`.

- New `RawSecureSocketExtension`:
  - `asSecureSocket`

- New `RawSecureServerSocketExtension`:
  - `asSecureServerSocket`.

## 1.0.5

- `MultiDomainSecureServer.bind`:
  - Added parameters `backlog`, `v6Only` and `shared`.

## 1.0.4

- `MultiDomainSecureServer.parseSNIHostname`: fix offset computation.

## 1.0.3

- Improved documentation.

## 1.0.2

- Improved documentation.

## 1.0.1

- `RawSocketAsSocket`: finalize implementation.

- New `RawServerSocketAsServerSocket`: `asSocket`
- New `RawServerSocketExtension`: `asServerSocket`

- `MultiDomainSecureServer`:
  - Added `asServerSocket`.

- New `example/shelf_example`
- New `example/example.md`

## 1.0.0

- Initial version.
