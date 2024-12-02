import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:async_benchmark/async_benchmark.dart';
import 'package:multi_domain_secure_server/multi_domain_secure_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../test/localhost_cert.dart';

void main() async {
  final profile = BenchmarkProfile.normal;

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

  @override
  Future<void> job(JobSetup setup, HttpServer? service) async {
    var httpClient = HttpClient();

    httpClient.badCertificateCallback = _badCertificateCallback;

    var request = await httpClient.getUrl(setup.requestUri);
    var response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (responseText != setup.serverText) {
      throw StateError(
          "Invalid response text:\n<<$responseText>>\n!=\n<<${setup.serverText}>>");
    }
  }

  bool _badCertificateCallback(cert, host, port) {
    //print('badCertificateCallback[$host:$port]> $cert');
    return true;
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

  var server = await shelf_io.serve(handler,
      ipv6 ? InternetAddress.loopbackIPv6 : InternetAddress.loopbackIPv4, port);
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
