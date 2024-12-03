import 'dart:async';
import 'dart:io';

/// A utility class to resolve and cache host addresses.
///
/// Provides caching of DNS lookups for improved performance and reduces redundant lookups.
class HostResolver {
  HostResolver();

  /// A cache for resolved host addresses.
  final Map<String, List<InternetAddress>> _addressesCache = {};

  /// The timestamp of the last cache clear operation.
  DateTime _addressesCacheCleanTime = DateTime.now();

  /// Clears the cached addresses and updates the cache timestamp.
  void clearAddressesCache() {
    _addressesCache.clear();
    _addressesCacheCleanTime = DateTime.now();
  }

  /// Checks if the address cache has exceeded the specified timeout.
  ///
  /// If the cache has expired, it clears the cache.
  ///
  /// - [cacheTimeout]: The duration after which the cache is considered expired.
  /// - Returns `true` if the cache was cleared; otherwise, `false`.
  bool checkAddressesCacheTimeout(Duration cacheTimeout) {
    var elapsedTime = DateTime.now().difference(_addressesCacheCleanTime);
    if (elapsedTime > cacheTimeout) {
      clearAddressesCache();
      return true;
    }
    return false;
  }

  /// Resolves the IP addresses for the given [hostname], using cache if available.
  ///
  /// - [hostname]: The hostname to resolve.
  /// - Returns a list of resolved [InternetAddress] objects.
  FutureOr<List<InternetAddress>> lookupAddress(String hostname) {
    var cached = _addressesCache[hostname];
    if (cached != null) return cached;

    return lookupAddressImpl(hostname).then((address) {
      return _addressesCache[hostname] ??= address;
    });
  }

  /// Performs the actual DNS lookup for the given [hostname].
  ///
  /// - [hostname]: The hostname to resolve.
  /// - Returns a list of resolved [InternetAddress] objects.
  Future<List<InternetAddress>> lookupAddressImpl(String hostname) =>
      InternetAddress.lookup(hostname, type: InternetAddressType.any);
}

/// A class for managing socket connections with address caching.
///
/// Supports secure and non-secure socket connections.
class SocketConnector extends HostResolver {
  /// A callback for handling invalid certificates in secure connections.
  ///
  /// If provided, this function is invoked when a bad certificate is encountered.
  final bool Function(X509Certificate certificate)? onBadCertificate;

  /// Creates an instance of [SocketConnector].
  ///
  /// - [onBadCertificate]: An optional callback for handling bad certificates.
  SocketConnector({this.onBadCertificate});

  /// Opens a socket connection to the specified [host] and [port].
  ///
  /// - [host]: The hostname to connect to.
  /// - [port]: The port to connect to.
  /// - [secure]: Whether the connection should be secure (default is `false`).
  /// - [context]: An optional [SecurityContext] for secure connections.
  /// - Returns a connected [Socket] or throws an error if the connection fails.
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

  /// Connects to a non-secure socket at the specified [host] and [port].
  ///
  /// Returns a [Future] that completes with the connected [Socket].
  Future<Socket> connectSocket(String host, int port) =>
      Socket.connect(host, port);

  /// Connects to a secure socket at the specified [host] and [port].
  ///
  /// Optionally accepts a [SecurityContext] and a bad certificate callback.
  ///
  /// Returns a [Future] that completes with the connected [SecureSocket].
  Future<SecureSocket> connectSecureSocket(
          String host, int port, SecurityContext? context) =>
      SecureSocket.connect(host, port,
          context: context, onBadCertificate: onBadCertificate);
}

/// An HTTP override class for using cached address resolution in HTTP clients.
///
/// Extends [HttpOverrides] to provide custom socket connection logic.
class HttpConnectorWithCachedAddresses extends HttpOverrides {
  /// A callback for handling invalid certificates in secure connections.
  final bool Function(X509Certificate certificate)? onBadCertificate;

  /// Creates an instance of [HttpConnectorWithCachedAddresses].
  ///
  /// Accepts an optional [onBadCertificate] callback to handle bad certificates.
  HttpConnectorWithCachedAddresses({this.onBadCertificate});

  /// Registers this override as the global HTTP override.
  void register() {
    HttpOverrides.global = this;
  }

  /// A socket connector for managing socket connections.
  late final SocketConnector _socketConnector =
      SocketConnector(onBadCertificate: onBadCertificate);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var httpClient = super.createHttpClient(context);

    httpClient.connectionFactory = (uri, String? proxyHost, int? proxyPort) =>
        connectionFactory(uri, proxyHost, proxyPort, context);

    return httpClient;
  }

  /// Custom connection factory for creating socket connections.
  ///
  /// Resolves and connects to the specified [uri].
  /// Optionally supports proxies and secure connections.
  ///
  /// Returns a [Future] that completes with a [ConnectionTask] for a [Socket].
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
