import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:async_benchmark/async_benchmark.dart';
import 'package:multi_domain_secure_server/multi_domain_secure_server.dart';
import 'package:multi_domain_secure_server/multi_domain_secure_server_tools.dart';
import 'package:multi_domain_secure_server/src/connector_tools.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../test/localhost_cert.dart';

const profileNormal2000 = BenchmarkProfile(
  'normal:2000',
  warmup: 100,
  interactions: 2000,
  rounds: 3,
);

void main() async {
  // Avoid `localhost` lookup, since we don't want to measure that:
  HttpConnectorWithCachedAddresses(onBadCertificate: (cert) => true).register();

  // final profile = BenchmarkProfile.fast;

  // Use custom profile:
  final profile = profileNormal2000;

  final textLength = 1024;
  print('textLength: $textLength');

  var benchmarks = [
    ShelfBenchmarkHTTP(textLength: textLength, ipv6: false),
    ShelfBenchmarkHTTP(textLength: textLength, ipv6: true),
    ShelfBenchmarkHTTPS(
        textLength: textLength, ipv6: false, multiDomain: false),
    ShelfBenchmarkHTTPS(textLength: textLength, ipv6: false, multiDomain: true),
    ShelfBenchmarkHTTPS(textLength: textLength, ipv6: true, multiDomain: false),
    ShelfBenchmarkHTTPS(textLength: textLength, ipv6: true, multiDomain: true),
  ];

  await benchmarks.runAll(
      profile: profile, setupOnIsolate: true, verbose: true);

  exit(0);
}

class ShelfBenchmarkHTTP extends ShelfBenchmark {
  ShelfBenchmarkHTTP({required super.textLength, required super.ipv6})
      : super('HTTP');

  @override
  Future<BenchmarkSetupResult<JobSetup, HttpServer>> setup() =>
      setupServer(textLength, ipv6);
}

class ShelfBenchmarkHTTPS extends ShelfBenchmark {
  final bool multiDomain;

  ShelfBenchmarkHTTPS(
      {required super.textLength,
      required super.ipv6,
      required this.multiDomain})
      : super('HTTPS${multiDomain ? '+multi' : ''}');

  @override
  Future<BenchmarkSetupResult<JobSetup, HttpServer>> setup() =>
      setupSecureServer(textLength, ipv6, multiDomain);
}

typedef JobSetup = ({int port, String serverText, Uri requestUri});

abstract class ShelfBenchmark extends Benchmark<JobSetup, HttpServer> {
  final int textLength;
  final bool ipv6;

  ShelfBenchmark(String type, {required this.textLength, required this.ipv6})
      : super('shelf ($type){${ipv6 ? 'IPv6' : 'IPv4'}}');

  @override
  Future<BenchmarkSetupResult<JobSetup, HttpServer>> setup();

  final List<HttpClient> _httpClients = [];

  @override
  Future<void> job(JobSetup setup, HttpServer? service) async {
    var httpClient = HttpClient()
      ..badCertificateCallback = _badCertificateCallback;

    // List of clients to close on [teardown]:
    _httpClients.add(httpClient);

    try {
      var request = await httpClient.getUrl(setup.requestUri);
      var response = await request.close();

      final responseText = await response.transform(utf8.decoder).join();
      if (responseText != setup.serverText) {
        throw StateError(
            "Invalid response text:\n<<$responseText>>\n!=\n<<${setup.serverText}>>");
      }
    } catch (e) {
      print("** Error requestiong: ${setup.requestUri}");
      print(e);

      // Abort benchmark:
      exit(100);
    }
  }

  bool _badCertificateCallback(cert, host, port) {
    //print('badCertificateCallback[$host:$port]> $cert');
    return true;
  }

  @override
  void teardown(JobSetup setup, HttpServer? service) {
    print('-- Closing `HttpClient`s: ${_httpClients.length}');

    for (var httpClient in _httpClients) {
      httpClient.close();
    }

    _httpClients.clear();
  }

  @override
  Future<void> shutdown(JobSetup setup, HttpServer? server) async {
    if (server != null) {
      print(
          '${Isolate.current.debugName} -- Closing `HttpServer`: ${server.address}:${server.port}');
      await server.close(force: true);
    }
  }
}

Future<BenchmarkSetupResult<JobSetup, HttpServer>> setupServer(
    int textLength, bool ipv6) async {
  var port = 9081;
  var (server, serverText) = await createServer(port, textLength, ipv6);
  var requestUri = Uri.parse("http://localhost:$port/http");

  return (
    setup: (port: port, serverText: serverText, requestUri: requestUri),
    service: server
  );
}

Future<BenchmarkSetupResult<JobSetup, HttpServer>> setupSecureServer(
    int textLength, bool ipv6, bool multiDomain) async {
  var port = 9443;
  var (server, serverText) =
      await createSecureServer(port, textLength, ipv6, multiDomain);
  var requestUri = Uri.parse("https://localhost:$port/https");

  return (
    setup: (port: port, serverText: serverText, requestUri: requestUri),
    service: server
  );
}

Future<(HttpServer, String)> createServer(
    int port, int responseLength, bool ipv6) async {
  final responseText = generateText(responseLength);

  final handler = createHandler(responseText);

  var address =
      ipv6 ? InternetAddress.loopbackIPv6 : InternetAddress.loopbackIPv4;

  var server = await shelf_io.serve(handler, address, port);

  return (server, responseText);
}

Future<(HttpServer, String)> createSecureServer(
    int port, int responseLength, bool ipv6, bool multiDomain) async {
  var defaultSecureContext = loadLocalhostSecurityContext();

  final responseText = generateText(responseLength);

  final handler = createHandler(responseText);

  var address =
      ipv6 ? InternetAddress.loopbackIPv6 : InternetAddress.loopbackIPv4;

  HttpServer httpServer;
  if (multiDomain) {
    var server = await MultiDomainSecureServer.bind(
      address,
      port,
      defaultSecureContext: defaultSecureContext,
    );

    httpServer = server.asHttpServer();
    shelf_io.serveRequests(httpServer, handler);
  } else {
    httpServer = await shelf_io.serve(handler, address, port,
        securityContext: defaultSecureContext);
  }

  return (httpServer, responseText);
}

Handler createHandler(String responseText) {
  return Pipeline()
      .addHandler((request) => handleRequest(request, responseText));
}

Response handleRequest(Request request, String responseText) {
  //print('» ${request.requestedUri}');
  return Response.ok(responseText, headers: {'Content-Type': 'text/plain'});
}

String generateText(int length) {
  const String chars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ";
  return List.generate(length, (i) => chars[i % chars.length]).join();
}
