import 'dart:io';

class HostResolver {
  HostResolver();

  final Map<String, List<InternetAddress>> _addressesCache = {};

  DateTime _addressesCacheCleanTime = DateTime.now();

  void clearAddressesCache() {
    _addressesCache.clear();
    _addressesCacheCleanTime = DateTime.now();
  }

  bool checkAddressesCacheTimeout(Duration cacheTimeout) {
    var elapsedTime = DateTime.now().difference(_addressesCacheCleanTime);
    if (elapsedTime > cacheTimeout) {
      clearAddressesCache();
      return true;
    }
    return false;
  }

  Future<List<InternetAddress>> lookupAddress(String host) async =>
      _addressesCache[host] ??= await lookupAddressImpl(host);

  Future<List<InternetAddress>> lookupAddressImpl(String host) =>
      InternetAddress.lookup(host, type: InternetAddressType.any);
}

class SocketConnector extends HostResolver {
  bool Function(X509Certificate certificate)? onBadCertificate;

  SocketConnector({this.onBadCertificate});

  Future<Socket> openSocket(String host, int port,
      {bool secure = false, SecurityContext? context}) async {
    var addresses = _addressesCache[host] ??= await lookupAddress(host);

    Object? error;

    if (secure) {
      for (var i = 0; i < addresses.length; ++i) {
        var address = addresses[i];
        try {
          var socket = await connectSecureSocket(host, port, context);
          if (i > 0) {
            addresses.removeAt(i);
            addresses.insert(0, address);
          }

          return socket;
        } catch (e) {
          error = e;
        }
      }
    } else {
      for (var i = 0; i < addresses.length; ++i) {
        var address = addresses[i];
        try {
          var socket = await connectSocket(host, port);
          if (i > 0) {
            addresses.removeAt(i);
            addresses.insert(0, address);
          }

          return socket;
        } catch (e) {
          error = e;
        }
      }
    }

    throw error ?? StateError("Can't connect a socket to> $host:$port");
  }

  Future<Socket> connectSocket(String host, int port) =>
      Socket.connect(host, port);

  Future<SecureSocket> connectSecureSocket(
          String host, int port, SecurityContext? context) =>
      SecureSocket.connect(host, port,
          context: context, onBadCertificate: onBadCertificate);
}

class HttpConnectorWithCachedAddresses extends HttpOverrides {
  final bool Function(X509Certificate certificate)? onBadCertificate;

  HttpConnectorWithCachedAddresses({this.onBadCertificate});

  void register() {
    HttpOverrides.global = this;
  }

  late final SocketConnector _socketConnector =
      SocketConnector(onBadCertificate: onBadCertificate);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var httpClient = super.createHttpClient(context);

    httpClient.connectionFactory = (uri, String? proxyHost, int? proxyPort) =>
        connectionFactory(uri, proxyHost, proxyPort, context);

    return httpClient;
  }

  Future<ConnectionTask<Socket>> connectionFactory(
      uri, String? proxyHost, int? proxyPort, SecurityContext? context) {
    var socketAsync = _socketConnector.openSocket(
      uri.host,
      uri.port,
      secure: uri.scheme == 'https',
      context: context,
    );

    return Future.value(ConnectionTask.fromSocket(socketAsync, () {}));
  }
}
