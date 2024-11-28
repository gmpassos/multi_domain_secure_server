import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:multi_domain_secure_server/multi_domain_secure_server.dart';
import 'package:test/test.dart';

void main() {
  group('MultiDomainSecureServer', () {
    test('Basic (null SecurityContext)', () async {
      final port = 9443;

      var onHostError = Completer<String>();

      var server = await MultiDomainSecureServer.bind(
        InternetAddress.anyIPv4,
        port,
        securityContextResolver: (host) {
          onHostError.complete(host);
          return null;
        },
      );

      expect(server.rawServerSocket.port, equals(port));

      var socketAsync = SecureSocket.connect(
        'localhost',
        port,
        onBadCertificate: (_) => true,
      );

      var hostError = await onHostError.future;
      print('hostError: $hostError');

      expect(hostError, equals('localhost'));

      Object? socketError;
      var socket =
          await socketAsync.then((skt) => skt as SecureSocket?, onError: (e) {
        socketError = e;
        return null;
      });

      print('socketError: $socketError');

      expect(socket, isNull);
      expect(socketError, isA<HandshakeException>());
    });

    test('parseSNIHostname', () {
      var clientHello1 = Uint8List.fromList(
          '22 3 1 1 60 1 0 1 56 3 3 61 102 193 32 209 174 53 83 188 33 75 119 88 137 2 44 45 206 110 171 116 31 225 143 242 253 243 48 100 205 70 97 32 44 215 108 123 47 114 71 97 202 224 139 71 86 115 204 215 150 142 34 2 242 186 145 113 134 164 74 82 139 166 48 41 0 98 19 2 19 3 19 1 192 48 192 44 192 40 192 36 192 20 192 10 0 159 0 107 0 57 204 169 204 168 204 170 255 133 0 196 0 136 0 129 0 157 0 61 0 53 0 192 0 132 192 47 192 43 192 39 192 35 192 19 192 9 0 158 0 103 0 51 0 190 0 69 0 156 0 60 0 47 0 186 0 65 192 17 192 7 0 5 0 4 192 18 192 8 0 22 0 10 0 255 1 0 0 141 0 43 0 9 8 3 4 3 3 3 2 3 1 0 51 0 38 0 36 0 29 0 32 184 1 34 43 208 205 96 129 192 251 165 124 120 253 218 236 32 6 190 57 24 207 103 41 146 78 97 177 153 195 174 2 0 0 0 16 0 14 0 0 11 102 111 111 111 98 97 114 46 99 111 109 0 11 0 2 1 0 0 10 0 10 0 8 0 29 0 23 0 24 0 25 0 13 0 24 0 22 8 6 6 1 6 3 8 5 5 1 5 3 8 4 4 1 4 3 2 1 2 3 0 16 0 14 0 12 2 104 50 8 104 116 116 112 47 49 46 49'
              .split(' ')
              .map(int.parse)
              .toList());

      var hostname1 = MultiDomainSecureServer.parseSNIHostname(clientHello1);
      expect(hostname1, equals('fooobar.com'));

      var clientHello2 = Uint8List.fromList(
          '22 3 1 1 57 1 0 1 53 3 3 22 118 175 117 166 161 17 83 157 202 188 92 49 216 16 174 121 43 240 151 47 82 79 27 179 158 248 139 106 178 222 203 32 201 96 17 56 231 105 142 243 36 59 111 35 38 241 55 50 163 111 171 111 23 180 34 151 157 232 77 213 15 216 161 74 0 98 19 2 19 3 19 1 192 48 192 44 192 40 192 36 192 20 192 10 0 159 0 107 0 57 204 169 204 168 204 170 255 133 0 196 0 136 0 129 0 157 0 61 0 53 0 192 0 132 192 47 192 43 192 39 192 35 192 19 192 9 0 158 0 103 0 51 0 190 0 69 0 156 0 60 0 47 0 186 0 65 192 17 192 7 0 5 0 4 192 18 192 8 0 22 0 10 0 255 1 0 0 138 0 43 0 9 8 3 4 3 3 3 2 3 1 0 51 0 38 0 36 0 29 0 32 164 211 199 95 244 133 245 16 25 60 17 24 207 18 188 181 93 240 85 20 38 150 146 4 44 15 50 68 77 111 253 8 0 0 0 13 0 11 0 0 8 102 111 111 111 46 99 111 109 0 11 0 2 1 0 0 10 0 10 0 8 0 29 0 23 0 24 0 25 0 13 0 24 0 22 8 6 6 1 6 3 8 5 5 1 5 3 8 4 4 1 4 3 2 1 2 3 0 16 0 14 0 12 2 104 50 8 104 116 116 112 47 49 46 49'
              .split(' ')
              .map(int.parse)
              .toList());

      var hostname2 = MultiDomainSecureServer.parseSNIHostname(clientHello2);
      expect(hostname2, equals('fooo.com'));

      var clientHello3 = Uint8List.fromList(
          '22 3 1 1 62 1 0 1 58 3 3 246 97 144 92 131 25 85 170 225 103 157 215 232 201 57 136 72 215 119 201 175 209 29 170 123 92 136 200 213 237 145 139 32 213 44 27 55 163 127 128 60 114 242 101 130 81 190 90 111 181 227 166 254 14 74 42 98 174 132 161 95 214 174 92 58 0 98 19 2 19 3 19 1 192 48 192 44 192 40 192 36 192 20 192 10 0 159 0 107 0 57 204 169 204 168 204 170 255 133 0 196 0 136 0 129 0 157 0 61 0 53 0 192 0 132 192 47 192 43 192 39 192 35 192 19 192 9 0 158 0 103 0 51 0 190 0 69 0 156 0 60 0 47 0 186 0 65 192 17 192 7 0 5 0 4 192 18 192 8 0 22 0 10 0 255 1 0 0 143 0 43 0 9 8 3 4 3 3 3 2 3 1 0 51 0 38 0 36 0 29 0 32 171 231 170 186 80 47 211 23 40 213 43 251 80 249 249 29 31 215 3 120 106 143 156 114 90 179 114 71 205 142 25 5 0 0 0 18 0 16 0 0 13 102 111 111 111 111 111 111 111 111 46 99 111 109 0 11 0 2 1 0 0 10 0 10 0 8 0 29 0 23 0 24 0 25 0 13 0 24 0 22 8 6 6 1 6 3 8 5 5 1 5 3 8 4 4 1 4 3 2 1 2 3 0 16 0 14 0 12 2 104 50 8 104 116 116 112 47 49 46 49'
              .split(' ')
              .map(int.parse)
              .toList());

      var hostname3 = MultiDomainSecureServer.parseSNIHostname(clientHello3);
      expect(hostname3, equals('foooooooo.com'));
    });
  });
}
