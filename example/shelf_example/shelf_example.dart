import 'dart:io';

import 'package:multi_domain_secure_server/multi_domain_secure_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

void main() async {
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

  // Create the Secure Server at port 8443:
  var server = await MultiDomainSecureServer.bind(
    InternetAddress.anyIPv4,
    8443,
    securityContextResolver: (hostname) {
      print('-- Resolving `SecurityContext` for hostname: $hostname');
      return hostnamesSecurityContexts[hostname];
    },
  );

  // Starts the HTTP server and listens for incoming
  // connections on the provided ServerSocket:
  var httpServer = HttpServer.listenOn(server.asServerSocket());

  // Create a handler for incoming requests:
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(
    (request) {
      return Response.ok('Hello, Secure World!');
    },
  );

  // Serve Shelf handler:
  shelf_io.serveRequests(httpServer, handler);

  print(
      'Secure server listening on https://${httpServer.address.host}:${httpServer.port}');
}
