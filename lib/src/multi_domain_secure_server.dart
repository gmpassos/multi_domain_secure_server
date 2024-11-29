import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
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

  MultiDomainSecureServer._(this._rawServerSocket, this._supportedProtocols,
      this._defaultSecureContext, this.securityContextResolver) {
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
  ///
  /// Returns a [Future] that completes with a [MultiDomainSecureServer] once the server is bound.
  ///
  /// See [RawServerSocket.bind].
  static Future<MultiDomainSecureServer> bind(address, int port,
      {List<String>? supportedProtocols,
      SecurityContext? defaultSecureContext,
      SecurityContextResolver? securityContextResolver}) async {
    final rawServerSocket = await RawServerSocket.bind(address, port);
    return MultiDomainSecureServer._(rawServerSocket, supportedProtocols,
        defaultSecureContext, securityContextResolver);
  }

  final StreamController<RawSecureSocket> _onAcceptController =
      StreamController();

  /// Stream of incoming [RawSecureSocket] connections.
  ///
  /// Emits a [RawSecureSocket] each time a new connection is successfully accepted.
  Stream<RawSecureSocket> get onAccept => _onAcceptController.stream;

  Future<void> _accept(RawSocket rawSocket) async {
    rawSocket.readEventsEnabled = false;
    rawSocket.writeEventsEnabled = false;

    var sniHostname = await extractSNIHostname(rawSocket);

    var securityContext = resolveSecureContext(sniHostname.hostname);

    if (securityContext == null) {
      rawSocket.close();
      return;
    }

    var rawSecureSocketAsync = RawSecureSocket.secureServer(
      rawSocket,
      securityContext,
      bufferedData: sniHostname.clientHello,
      supportedProtocols: _supportedProtocols,
    );

    rawSecureSocketAsync.then(_onAcceptController.add);
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
  RawServerSocketAsServerSocket asServerSocket() {
    var streamController = StreamController<Socket>();

    onAccept.listen((rawSecureSocket) {
      streamController.add(rawSecureSocket.asSocket());
    });

    return _rawServerSocket.asServerSocket(streamController: streamController);
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
  static Future<({Uint8List clientHello, String? hostname})> extractSNIHostname(
      RawSocket rawSocket) async {
    var clientHello = Uint8List(0);

    var retry = 0;

    while (clientHello.length < 1024 * 16 && retry < 100) {
      var buffer = rawSocket.read(1024 * 4);
      if (buffer != null && buffer.isNotEmpty) {
        clientHello = clientHello.isNotEmpty
            ? Uint8List.fromList(clientHello + buffer)
            : buffer;

        var hostname = parseSNIHostname(clientHello);
        if (hostname != null) {
          return (hostname: hostname, clientHello: clientHello);
        }
      } else {
        int delayMs;
        switch (retry) {
          case 0:
          case 1:
          case 2:
          case 3:
            {
              delayMs = 1;
            }
          case 4:
          case 5:
          case 6:
          case 7:
            {
              delayMs = 10;
            }
          default:
            {
              delayMs = math.min(10 * retry, 100);
            }
        }

        await Future.delayed(Duration(milliseconds: delayMs));
        ++retry;
      }
    }

    return (hostname: null, clientHello: clientHello);
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

      offset += 2;

      // Extension Length (2 bytes):
      var extensionLength =
          (clientHelloBuffer[offset] << 8) | clientHelloBuffer[offset + 1];

      // Server Name List Length (2 bytes):
      var extensionListLength =
          (clientHelloBuffer[offset + 2] << 8) | clientHelloBuffer[offset + 3];

      if (extensionLength <= extensionListLength) {
        ++offset;
        continue;
      }

      // Server Name Type (1 byte):
      var serverNameType = clientHelloBuffer[offset + 4];

      // 0x00: Hostname
      if (serverNameType != 0) {
        ++offset;
        continue;
      }

      var serverNameLength =
          (clientHelloBuffer[offset + 5] << 8) | clientHelloBuffer[offset + 6];
      if (serverNameLength >= extensionLength) {
        ++offset;
        continue;
      }

      var serverNameOffset = offset + 7;

      // The Server Name bytes:
      var serverNameBytes = clientHelloBuffer.sublist(
          serverNameOffset, serverNameOffset + serverNameLength);

      // Server Name ASCII `String`:
      var serverName = String.fromCharCodes(serverNameBytes);
      return serverName;
    }

    // No SNI extension was found:
    return null;
  }

  @override
  String toString() =>
      'MultiDomainSecureServer{address: ${_rawServerSocket.address}, port: ${_rawServerSocket.port}}';
}
