## 1.0.14

- `MultiDomainSecureServer`:
  - `extractSNIHostname`:
    - Optimize bytes buffer merge between loops. 
    - Avoid infinity loop.

- test: ^1.26.3
- dependency_validator: ^5.0.3

## 1.0.13

- `MultiDomainSecureServer`:
  - Added field `validatePublicDomainFormat`.
  - `isValidHostname`: improve validation.
  - Added `isValidPublicDomainName`.

## 1.0.12

- `HttpServerSecureMultiDomain`:
  - `close`: improve `_multiDomainSecureServer.close`.

- `RawSocketAsSocket`:
  - `RawSocketEvent.readClosed`: call `close` to fully close the socket.

- async_benchmark: ^1.0.3

## 1.0.11

- test: ^1.25.12
- dependency_validator: ^4.1.2

## 1.0.10

- Tools:
  - New `HostResolver`, `SocketConnector` and `HttpConnectorWithCachedAddresses`.

- New library: `multi_domain_secure_server_tools.dart`

- Improved `shelf_benchmark.dart`: using `HttpConnectorWithCachedAddresses`.

- async_benchmark: ^1.0.2

## 1.0.9

- `MultiDomainSecureServer`:
  - Optimize `_accept`.
  - Optimize `extractSNIHostname`.
  - Added `parseSNIHostnameSafe`.
  - Improve `parseSNIHostname`.

- Moved `localhost` private key and certificate
  from `benchmark/shelf_benchmark.dart` to `test/localhost_cert.dart`.

- Improve tests.

- test: ^1.25.10

## 1.0.8

- `MultiDomainSecureServer`:
  - `extractSNIHostname`: optimize using `available` and reducing calls to `read`.

## 1.0.7

- `MultiDomainSecureServer`:
  - Added field `_acceptSubscription`.
  - Added `asHttpServer`.
    - New class `_HttpServerSecureMultiDomain`.

- `RawSocketAsSocket`:
  - Improve `close` and `destroy`.

- New `benchmark/shelf_benchmark.dart`.

- async_benchmark: ^1.0.1

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
