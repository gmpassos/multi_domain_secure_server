import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart' as logging;

import 'extensions.dart';
import 'raw_socket_as_socket.dart';

final _log = logging.Logger('MultiDomainSecureServer');

/// A function that resolves a [SecurityContext] for a given [hostname].
/// See [MultiDomainSecureServer.securityContextResolver]
typedef SecurityContextResolver = SecurityContext? Function(String? hostname);

/// A secure server that wraps a [RawServerSocket] and supports multiple
/// [SecurityContext] configurations via [securityContextResolver].
///
/// This class uses a [RawServerSocket] for low-level communication and allows dynamic
/// selection of [SecurityContext] based on the incoming connection and hostname.
/// The [securityContextResolver] determines the appropriate security context for each
/// connection.
class MultiDomainSecureServer {
  final RawServerSocket _rawServerSocket;
  final List<String>? _supportedProtocols;
  final SecurityContext? _defaultSecureContext;

  /// Resolves the [SecurityContext] for each connection and hostname.
  final SecurityContextResolver? securityContextResolver;

  /// If true, only handshakes with a ClientHello message containing a hostname are accepted.
  final bool requiresHandshakesWithHostname;

  MultiDomainSecureServer._(
      this._rawServerSocket,
      this._supportedProtocols,
      this._defaultSecureContext,
      this.securityContextResolver,
      this.requiresHandshakesWithHostname) {
    _rawServerSocket.listen(_accept);
  }

  /// The wrapped [RawServerSocket].
  RawServerSocket get rawServerSocket => _rawServerSocket;

  List<String>? get supportedProtocols {
    var supportedProtocols = _supportedProtocols;
    return supportedProtocols != null
        ? UnmodifiableListView(supportedProtocols)
        : null;
  }

  /// The default [SecurityContext] to use if [securityContextResolver] returns `null`.
  SecurityContext? get defaultSecureContext => _defaultSecureContext;

  /// Binds a [MultiDomainSecureServer] to the specified [address] and [port].
  ///
  /// This method sets up a secure server that listens on the given [address] and [port].
  /// You can optionally provide a list of supported protocols, a default security context,
  /// and a custom [securityContextResolver] to select the security context for each connection.
  ///
  /// - [address]: The address to bind the server to (IP or hostname).
  /// - [port]: The port to bind the server to.
  /// - [supportedProtocols]: Optional list of supported security protocols.
  /// - [defaultSecureContext]: Optional default security context for connections.
  /// - [securityContextResolver]: Optional custom resolver for selecting security contexts.
  /// - [requiresHandshakesWithHostname]: If true, only handshakes with a hostname in the ClientHello are accepted.
  /// - [backlog]: The maximum number of pending connections in the queue. Defaults to 0, meaning the system default.
  /// - [v6Only]: If true, restricts the server to IPv6 connections only. Defaults to false.
  /// - [shared]: If true, allows multiple isolates to bind to the same address and port. Defaults to false.
  ///
  /// Returns a [Future] that completes with a [MultiDomainSecureServer] once the server is bound.
  ///
  /// See [RawServerSocket.bind].
  static Future<MultiDomainSecureServer> bind(address, int port,
      {List<String>? supportedProtocols,
      SecurityContext? defaultSecureContext,
      SecurityContextResolver? securityContextResolver,
      bool requiresHandshakesWithHostname = false,
      int backlog = 0,
      bool v6Only = false,
      bool shared = false}) async {
    final rawServerSocket = await RawServerSocket.bind(address, port,
        backlog: backlog, v6Only: v6Only, shared: shared);
    return MultiDomainSecureServer._(
        rawServerSocket,
        supportedProtocols,
        defaultSecureContext,
        securityContextResolver,
        requiresHandshakesWithHostname);
  }

  final StreamController<RawSecureSocket> _onAcceptController =
      StreamController();

  /// Stream of incoming [RawSecureSocket] connections.
  ///
  /// Emits a [RawSecureSocket] each time a new connection is successfully accepted.
  Stream<RawSecureSocket> get onAccept => _onAcceptController.stream;

  Future<void> _accept(RawSocket rawSocket) async {
    rawSocket.writeEventsEnabled = false;

    var sniHostname = await extractSNIHostname(rawSocket);
    if (sniHostname.hostname == null && requiresHandshakesWithHostname) {
      sniHostname.subscription?.cancel();
      rawSocket.close();
      return;
    }

    var securityContext = resolveSecureContext(sniHostname.hostname);

    if (securityContext == null) {
      sniHostname.subscription?.cancel();
      rawSocket.close();
      return;
    }

    var rawSecureSocketAsync = RawSecureSocket.secureServer(
      rawSocket,
      securityContext,
      bufferedData: sniHostname.clientHello,
      supportedProtocols: _supportedProtocols,
      subscription: sniHostname.subscription,
    );

    rawSecureSocketAsync.then(_onAcceptController.add, onError: (e) {
      _log.warning(() => "Erro establishing `RawSecureSocket`", e);
      return null;
    });
  }

  /// Resolves the [SecurityContext] for the given [hostname].
  ///
  /// This method first tries to use the `securityContextResolver`. If that returns `null`,
  /// it falls back to the `defaultSecureContext`. If neither is available, it logs a warning
  /// and returns `null`.
  ///
  /// - [hostname]: The hostname for which the security context is resolved.
  ///
  /// Returns a [SecurityContext] or `null` if not found.
  SecurityContext? resolveSecureContext(String? hostname) {
    var securityContextResolver = this.securityContextResolver;
    if (securityContextResolver != null) {
      var ctx = securityContextResolver(hostname);
      if (ctx != null) return ctx;

      var defaultSecureContext = _defaultSecureContext;
      if (defaultSecureContext != null) {
        return defaultSecureContext;
      }

      _log.warning(() =>
          "`securityContextResolver` returned `null` and `defaultSecureContext` is not defined! Hostname: $hostname");
      return null;
    } else {
      var defaultSecureContext = _defaultSecureContext;
      if (defaultSecureContext != null) {
        return defaultSecureContext;
      }

      _log.warning(() =>
          "No `defaultSecureContext` or `securityContextResolver` is defined! Hostname: $hostname");
      return null;
    }
  }

  /// Converts this to a [RawServerSocketAsServerSocket], which implements [ServerSocket].
  RawServerSocketAsServerSocket asServerSocket({bool useSecureSocket = false}) {
    var streamController = StreamController<Socket>();

    if (useSecureSocket) {
      onAccept.listen((rawSecureSocket) {
        streamController.add(rawSecureSocket.asSecureSocket());
      });
    } else {
      onAccept.listen((rawSecureSocket) {
        streamController.add(rawSecureSocket.asSocket());
      });
    }

    return _rawServerSocket.asServerSocket(streamController: streamController);
  }

  /// Converts this to a [RawServerSocketAsSecureServerSocket], which implements [SecureServerSocket].
  RawServerSocketAsSecureServerSocket asSecureServerSocket() {
    var streamController = StreamController<SecureSocket>();

    onAccept.listen((rawSecureSocket) {
      streamController.add(rawSecureSocket.asSecureSocket());
    });

    return _rawServerSocket.asSecureServerSocket(
        streamController: streamController);
  }

  /// Extracts the SNI hostname from a TLS `ClientHello` message.
  ///
  /// Reads data from the provided [RawSocket] in chunks, extracting the SNI hostname
  /// if present. The method retries reading with delays if no data is available.
  ///
  /// - [rawSocket]: The [RawSocket] to read the `ClientHello` message from.
  ///
  /// Returns a [Future] with a tuple:
  /// - [clientHello]: The raw `ClientHello` data (as [Uint8List]) that was read from the socket.
  /// - [hostname]: The extracted SNI hostname, or null if not found.
  /// - [subscription]: A [StreamSubscription] to the socket's events, opened only if needed,
  ///   allowing the caller to manage or cancel socket operations.
  static Future<
      ({
        Uint8List clientHello,
        String? hostname,
        StreamSubscription<RawSocketEvent>? subscription
      })> extractSNIHostname(RawSocket rawSocket) async {
    var clientHello = rawSocket.read(1024 * 4) ?? Uint8List(0);

    try {
      var hostname = parseSNIHostname(clientHello);
      if (hostname != null) {
        return (
          hostname: hostname,
          clientHello: clientHello,
          subscription: null
        );
      }
    } catch (e, s) {
      _log.severe(
          "Error calling `parseSNIHostname`> clientHello: ${base64.encode(clientHello)}",
          e,
          s);
      rethrow;
    }

    // With retry and timeout:

    final initTime = DateTime.now();
    var closed = false;
    StreamSubscription<RawSocketEvent>? subscription;
    Completer<bool>? readCompleter;

    while (!closed &&
        clientHello.length < 1024 * 16 &&
        DateTime.now().difference(initTime).inSeconds < 30) {
      var buffer = rawSocket.read(1024 * 4);
      if (buffer != null && buffer.isNotEmpty) {
        clientHello = Uint8List.fromList(clientHello + buffer);

        try {
          var hostname = parseSNIHostname(clientHello);
          if (hostname != null) {
            return (
              hostname: hostname,
              clientHello: clientHello,
              subscription: subscription
            );
          }
        } catch (e, s) {
          _log.severe(
              "Error calling `parseSNIHostname`> clientHello: ${base64.encode(clientHello)}",
              e,
              s);
          rethrow;
        }
      } else {
        assert(readCompleter == null);
        var completer = readCompleter = Completer<bool>();

        if (subscription == null) {
          rawSocket.readEventsEnabled = true;

          subscription = rawSocket.listen((event) {
            switch (event) {
              case RawSocketEvent.read:
                {
                  readCompleter?.complete(true);
                  readCompleter = null;
                }
              case RawSocketEvent.readClosed:
              case RawSocketEvent.closed:
                {
                  closed = true;
                  readCompleter?.complete(true);
                  readCompleter = null;
                }
              default:
                break;
            }
          });
        }

        await completer.future.timeout(
          Duration(seconds: 1),
          onTimeout: () {
            if (!completer.isCompleted) {
              completer.complete(false);
            }
            return false;
          },
        );

        readCompleter = null;
      }
    }

    return (
      hostname: null,
      clientHello: clientHello,
      subscription: subscription
    );
  }

  /// Parses an SSL/TLS ClientHello message to extract the Server Name Indication (SNI) hostname.
  ///
  /// This function expects a valid ClientHello message buffer as input.
  /// It searches for the SNI extension and extracts the hostname if present.
  ///
  /// Returns the SNI hostname as a [String], or `null` if no hostname is found.
  ///
  /// [clientHelloBuffer]: The raw ClientHello message as a [Uint8List].
  static String? parseSNIHostname(Uint8List clientHelloBuffer) {
    if (clientHelloBuffer.length < 38) return null;

    var offset = 0;

    var contentType = clientHelloBuffer[offset];
    // Not a handshake message:
    if (contentType != 22) {
      return null;
    }

    offset += 5; // Skip the handshake header

    var messageType = clientHelloBuffer[offset];
    offset += 1; // Skip Message Type (1 bytes)

    // Not a ClientHello message:
    if (messageType != 1) {
      return null;
    }

    offset += 3; // Skip Length of the ClientHello message (3 bytes)
    offset += 2; // Skip Protocol Version (2 bytes)
    offset += 32; // Skip Random Data (32 bytes)

    // Session ID Length (1 byte):
    var sessionIDLength = clientHelloBuffer[offset];
    offset += 1;

    offset += sessionIDLength; // Skip Session ID bytes

    // Find SNI:
    while (offset + 7 < clientHelloBuffer.length) {
      // Extension Type (2 bytes):
      var b0 = clientHelloBuffer[offset];
      var b1 = clientHelloBuffer[offset + 1];

      if (b0 != 0 || b1 != 0) {
        ++offset;
        continue;
      }

      // Extension Length (2 bytes):
      var extensionLength = (clientHelloBuffer[offset + 2] << 8) |
          clientHelloBuffer[offset + 2 + 1];

      // Server Name List Length (2 bytes):
      var extensionListLength = (clientHelloBuffer[offset + 2 + 2] << 8) |
          clientHelloBuffer[offset + 2 + 3];

      if (extensionLength <= extensionListLength) {
        ++offset;
        continue;
      }

      if ((offset + 2 + 4 + extensionListLength) > clientHelloBuffer.length) {
        ++offset;
        continue;
      }

      // Server Name Type (1 byte):
      var serverNameType = clientHelloBuffer[offset + 2 + 4];

      // 0x00: Hostname
      if (serverNameType != 0) {
        ++offset;
        continue;
      }

      var serverNameLength = (clientHelloBuffer[offset + 2 + 5] << 8) |
          clientHelloBuffer[offset + 2 + 6];
      if (serverNameLength >= extensionLength) {
        ++offset;
        continue;
      }

      var serverNameOffset = offset + 2 + 7;

      // The Server Name bytes:
      var serverNameBytes = clientHelloBuffer.sublist(
          serverNameOffset, serverNameOffset + serverNameLength);

      // Server Name ASCII `String`:
      var serverName = String.fromCharCodes(serverNameBytes);

      if (!isValidHostname(serverName)) {
        ++offset;
        continue;
      }

      return serverName;
    }

    // No SNI extension was found:
    return null;
  }

  static final regexpDomainName = RegExp(
      r'^(?:(?!-)[A-Za-z0-9-]+(?<!-)|(?!-)[A-Za-z0-9-]{1,63}(?<!-)\.(?!-)([A-Za-z0-9-]{1,63})(\.[A-Za-z]{2,})?)$');

  static bool isValidHostname(String? hostname) {
    if (hostname == null || hostname.isEmpty) return false;
    return regexpDomainName.hasMatch(hostname);
  }

  @override
  String toString() =>
      'MultiDomainSecureServer{address: ${_rawServerSocket.address}, port: ${_rawServerSocket.port}}';
}
