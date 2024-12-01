import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'raw_socket_as_socket.dart';

extension SecurityContextExtension on SecurityContext {
  /// A helper method to configure a [SecurityContext].
  /// Returns this [SecurityContext] instance.
  SecurityContext configure({
    String? certificateChainFile,
    List<int>? certificateChainBytes,
    String? certificateChainPassword,
    String? clientAuthoritiesFile,
    List<int>? clientAuthoritiesBytes,
    String? clientAuthoritiesPassword,
    String? privateKeyFile,
    List<int>? privateKeyBytes,
    String? privateKeyPassword,
  }) {
    if (clientAuthoritiesFile != null) {
      setClientAuthorities(clientAuthoritiesFile,
          password: clientAuthoritiesPassword);
    } else if (certificateChainBytes != null) {
      setClientAuthoritiesBytes(certificateChainBytes,
          password: clientAuthoritiesPassword);
    }

    if (certificateChainFile != null) {
      useCertificateChain(certificateChainFile,
          password: certificateChainPassword);
    } else if (certificateChainBytes != null) {
      useCertificateChainBytes(certificateChainBytes,
          password: certificateChainPassword);
    }

    if (privateKeyFile != null) {
      usePrivateKey(privateKeyFile, password: privateKeyPassword);
    } else if (privateKeyBytes != null) {
      usePrivateKeyBytes(privateKeyBytes, password: privateKeyPassword);
    }

    return this;
  }
}

extension RawSocketExtension on RawSocket {
  /// Converts a [RawSocket] into a [RawSocketAsSocket], which implements [Socket].
  ///
  /// This method wraps the [RawSocket] to provide a higher-level interface for socket
  /// operations, allowing it to be used where a [Socket] is expected.
  RawSocketAsSocket asSocket(
          {StreamController<Uint8List>? streamController,
          Encoding? encoding}) =>
      RawSocketAsSocket(this,
          streamController: streamController, encoding: encoding);
}

extension RawSecureSocketExtension on RawSecureSocket {
  /// Converts a [RawSecureSocket] into a [RawSecureSocketAsSecureSocket], which implements [SecureSocket].
  ///
  /// This method wraps the [RawSecureSocket] to provide a higher-level interface for secure socket
  /// operations, allowing it to be used where a [SecureSocket] is expected.
  RawSecureSocketAsSecureSocket asSecureSocket(
          {StreamController<Uint8List>? streamController,
          Encoding? encoding}) =>
      RawSecureSocketAsSecureSocket(this,
          streamController: streamController, encoding: encoding);
}

extension RawServerSocketExtension on RawServerSocket {
  /// Converts a [RawServerSocket] into a [RawServerSocketAsServerSocket], which implements [ServerSocket].
  ///
  /// This method wraps the [RawServerSocket] to provide a higher-level interface for server socket
  /// operations, allowing it to be used where a [ServerSocket] is expected.
  RawServerSocketAsServerSocket asServerSocket(
          {StreamController<Socket>? streamController}) =>
      RawServerSocketAsServerSocket(this, streamController: streamController);

  /// Converts a [RawServerSocket] into a [RawServerSocketAsSecureServerSocket], which implements [SecureServerSocket].
  ///
  /// This method wraps the [RawServerSocket] to provide a higher-level interface for server socket
  /// operations, allowing it to be used where a [SecureServerSocket] is expected.
  RawServerSocketAsSecureServerSocket asSecureServerSocket(
          {required StreamController<SecureSocket> streamController}) =>
      RawServerSocketAsSecureServerSocket(this,
          streamController: streamController);
}

extension RawSecureServerSocketExtension on RawSecureServerSocket {
  /// Converts a [RawSecureServerSocket] into a [RawSecureServerSocketAsSecureServerSocket], which implements [SecureServerSocket].
  ///
  /// This method wraps the [RawSecureServerSocket] to provide a higher-level interface for server socket
  /// operations, allowing it to be used where a [SecureServerSocket] is expected.
  RawSecureServerSocketAsSecureServerSocket asSecureServerSocket(
          {StreamController<SecureSocket>? streamController}) =>
      RawSecureServerSocketAsSecureServerSocket(this,
          streamController: streamController);
}
