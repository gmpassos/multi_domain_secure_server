import 'dart:convert';
import 'dart:io';

import 'raw_socket_as_socket.dart';

extension SecurityContextExtension on SecurityContext {
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
  RawSocketAsSocket asSocket({Encoding? encoding}) =>
      RawSocketAsSocket(this, encoding: encoding);
}
