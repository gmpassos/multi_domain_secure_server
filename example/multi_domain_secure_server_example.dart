import 'dart:io';

import 'package:logging/logging.dart' as logging;
import 'package:multi_domain_secure_server/multi_domain_secure_server.dart';

/// Example of a [MultiDomainSecureServer].
///
/// You can test it (on port 8443) with:
/// ```bash
///  curl -v -k --resolve example.com:8443:127.0.0.1 https://example.com:8443/foo
/// ```
void main(List<String> args) async {
  _logToConsole();

  var config = _parseArgs(args);

  // Define a `SecurityContext` for each hostname:
  // - NOTE: Replace the file paths with your own certificate and
  //   private key files for the respective domains to run this example.
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

  print('** Hostnames:');
  for (var domain in hostnamesSecurityContexts.keys) {
    print('  -- $domain');
  }

  // Create the Secure Server at `config.port`:
  var server = await MultiDomainSecureServer.bind(
    config.address,
    config.port,
    securityContextResolver: (hostname) {
      print('-- Resolving `SecurityContext` for hostname: $hostname');
      return hostnamesSecurityContexts[hostname];
    },
  );

  print('** Secure Server running: $server');

  server.onAccept.listen((acceptedSocket) {
    print(
        '-- Accepted Socket: ${acceptedSocket.remoteAddress.address}:${acceptedSocket.remotePort}');
    // Handle the `acceptedSocket`...
  });
}

/// Parse [main] `args`. Default port: 8443
({Object address, int port}) _parseArgs(List<String> args) {
  Object address = args.isNotEmpty ? args[0] : '*';
  int port = args.length > 1 ? int.parse(args[1]) : 8443;

  if (address == '*') {
    address = InternetAddress.anyIPv4;
  }

  return (address: address, port: port);
}

/// Log all to console ([print]):
void _logToConsole() {
  logging.Logger.root.level = logging.Level.ALL;
  logging.Logger.root.onRecord.listen(print);
}
