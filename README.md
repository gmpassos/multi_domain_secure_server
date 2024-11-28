# multi_domain_secure_server

[![pub package](https://img.shields.io/pub/v/multi_domain_secure_server.svg?logo=dart&logoColor=00b9fc)](https://pub.dev/packages/multi_domain_secure_server)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Codecov](https://img.shields.io/codecov/c/github/gmpassos/multi_domain_secure_server)](https://app.codecov.io/gh/gmpassos/multi_domain_secure_server)
[![Dart CI](https://github.com/gmpassos/multi_domain_secure_server/actions/workflows/dart.yml/badge.svg?branch=master)](https://github.com/gmpassos/multi_domain_secure_server/actions/workflows/dart.yml)
[![GitHub Tag](https://img.shields.io/github/v/tag/gmpassos/multi_domain_secure_server?logo=git&logoColor=white)](https://github.com/gmpassos/multi_domain_secure_server/releases)
[![New Commits](https://img.shields.io/github/commits-since/gmpassos/multi_domain_secure_server/latest?logo=git&logoColor=white)](https://github.com/gmpassos/multi_domain_secure_server/network)
[![Last Commits](https://img.shields.io/github/last-commit/gmpassos/multi_domain_secure_server?logo=git&logoColor=white)](https://github.com/gmpassos/multi_domain_secure_server/commits/master)
[![Pull Requests](https://img.shields.io/github/issues-pr/gmpassos/multi_domain_secure_server?logo=github&logoColor=white)](https://github.com/gmpassos/multi_domain_secure_server/pulls)
[![Code size](https://img.shields.io/github/languages/code-size/gmpassos/multi_domain_secure_server?logo=github&logoColor=white)](https://github.com/gmpassos/multi_domain_secure_server)
[![License](https://img.shields.io/github/license/gmpassos/multi_domain_secure_server?logo=open-source-initiative&logoColor=green)](https://github.com/gmpassos/multi_domain_secure_server/blob/master/LICENSE)

`multi_domain_secure_server` is a SecureServerSocket that supports multiple domains with dynamic SecurityContext resolution.

## Usage

```dart
import 'dart:io';

import 'package:multi_domain_secure_server/multi_domain_secure_server.dart';

/// Example of a [MultiDomainSecureServer].
///
/// You can test it (on port 8443) with:
/// ```bash
///  curl -v -k --resolve example.com:8443:127.0.0.1 https://example.com:8443/foo
/// ```
void main() async {
  // Define `SecurityContext` for each hostname:
  var hostnamesSecurityContexts = {
    'example.com': SecurityContext().configure(
      certificateChainFile: '/path/to/example.com/cert.pem',
      privateKeyFile: '/path/to/example.com/private-key.pem',
    ),
    'foo.com': SecurityContext().configure(
      certificateChainFile: '/path/to/foo.com/cert.pem',
      privateKeyFile: '/path/to/foo.com/private-key.pem',
    ),
  };

  // Create the Secure Server at `config.port`:
  var server = await MultiDomainSecureServer.bind(
    InternetAddress.anyIPv4,
    8443,
    securityContextResolver: (hostname) {
      print('-- Resolving `SecurityContext` for hostname: $hostname');
      return hostnamesSecurityContexts[hostname];
    },
  );

  print('** Secure Server running: $server');

  server.onAccept.listen((acceptedSocket) {
    print(
        '-- Accepted Socket: ${acceptedSocket.remoteAddress.address}:${acceptedSocket.remotePort}');
  });
}
```

## Source

The official source code is [hosted @ GitHub][github_multi_domain_secure_server]:

- https://github.com/gmpassos/multi_domain_secure_server

[github_multi_domain_secure_server]: https://github.com/gmpassos/multi_domain_secure_server

# Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/gmpassos/multi_domain_secure_server/issues

# Contribution

Any help from the open-source community is always welcome and needed:

- Found an issue?
    - Please fill a bug report with details.
- Wish a feature?
    - Open a feature request with use cases.
- Are you using and liking the project?
    - Promote the project: create an article, do a post or make a donation.
- Are you a developer?
    - Fix a bug and send a pull request.
    - Implement a new feature.
    - Improve the Unit Tests.
- Have you already helped in any way?
    - **Many thanks from me, the contributors and everybody that uses this project!**

*If you donate 1 hour of your time, you can contribute a lot,
because others will do the same, just be part and start with your 1 hour.*

# Author

Graciliano M. Passos: [gmpassos@GitHub][github].

[github]: https://github.com/gmpassos

## License

[Apache License - Version 2.0][apache_license]

[apache_license]: https://www.apache.org/licenses/LICENSE-2.0.txt
