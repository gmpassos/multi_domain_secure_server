import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'extensions.dart';

/// A [RawSocket] wrapper that implements the [Socket] interface.
///
/// This class wraps a [RawSocket] and exposes it as a [Socket] by implementing
/// the [Socket] interface. It allows the [RawSocket] to be used in contexts
/// that expect a [Socket], providing stream-based access to data with [Uint8List]
/// buffers.
class RawSocketAsSocket extends Stream<Uint8List> implements Socket {
  final RawSocket _rawSocket;
  final StreamController<Uint8List> _streamController;

  @override
  Encoding encoding;

  RawSocketAsSocket(this._rawSocket,
      {StreamController<Uint8List>? streamController, Encoding? encoding})
      : encoding = encoding ?? utf8,
        _streamController =
            _resolveStreamController(_rawSocket, streamController);

  static StreamController<Uint8List> _resolveStreamController(
      RawSocket rawSocket, StreamController<Uint8List>? streamController) {
    if (streamController != null) return streamController;

    streamController = StreamController();

    rawSocket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          var bs = rawSocket.read();
          if (bs != null) {
            streamController!.add(bs);
          }
        }
      },
      onError: (e, s) => streamController!.addError(e, s),
      onDone: () {
        streamController!.close();
      },
      cancelOnError: true,
    );

    return streamController;
  }

  @override
  int get port => _rawSocket.remotePort;

  @override
  InternetAddress get address => _rawSocket.remoteAddress;

  @override
  InternetAddress get remoteAddress => _rawSocket.remoteAddress;

  @override
  int get remotePort => _rawSocket.remotePort;

  @override
  bool setOption(SocketOption option, bool enabled) =>
      _rawSocket.setOption(option, enabled);

  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _rawSocket.getRawOption(option);

  @override
  void setRawOption(RawSocketOption option) => _rawSocket.setRawOption(option);

  @override
  void add(List<int> data) {
    _checkNotAddingStream();
    _rawSocket.write(data);
  }

  @override
  void write(Object? data) {
    _checkNotAddingStream();

    var bs = encoding.encode(data.toString());
    _rawSocket.write(bs);
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = ""]) {
    _checkNotAddingStream();

    if (object != '') {
      var bs = encoding.encode(object.toString());
      _rawSocket.write(bs);
    }

    _rawSocket.write(const [10]); // New line: \n
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    _checkNotAddingStream();

    if (separator.isNotEmpty) {
      final itr = objects.iterator;

      if (itr.moveNext()) {
        var o = itr.current;
        {
          var bs = encoding.encode(o.toString());
          _rawSocket.write(bs);
        }

        var separatorBs = encoding.encode(separator);

        while (itr.moveNext()) {
          var o = itr.current;
          _rawSocket.write(separatorBs);
          var bs = encoding.encode(o.toString());
          _rawSocket.write(bs);
        }
      }
    } else {
      for (var o in objects) {
        var bs = encoding.encode(o.toString());
        _rawSocket.write(bs);
      }
    }
  }

  bool _addingStream = false;

  void _checkNotAddingStream() {
    if (_addingStream) {
      throw StateError("Currently adding to `Stream`");
    }
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    _addingStream = true;

    try {
      final completer = Completer<void>();

      final subscription = stream.listen(
        (data) => _rawSocket.write(data),
        onError: (e, s) => completer.completeError(e, s),
        onDone: () => completer.complete(),
        cancelOnError: true, // Cancel the subscription on error
      );

      await completer.future;

      await subscription.cancel();
    } finally {
      _addingStream = false;
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _checkNotAddingStream();
    _streamController.addError(error, stackTrace);
  }

  @override
  Future get done => _streamController.done;

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _streamController.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future flush() {
    return Future.value();
  }

  @override
  Future<void> close() async {
    await _rawSocket.close();
  }

  @override
  void destroy() {
    _rawSocket.close();
    _streamController.close();
  }
}

/// A [RawSecureSocket] wrapper that implements the [SecureSocket] interface.
/// Extends [RawSocketAsSocket].
class RawSecureSocketAsSecureSocket extends RawSocketAsSocket
    implements SecureSocket {
  RawSecureSocket get _rawSecureSocket => _rawSocket as RawSecureSocket;

  //ignore: use_super_parameters
  RawSecureSocketAsSecureSocket(RawSecureSocket rawSecureSocket,
      {super.streamController, super.encoding})
      : super(rawSecureSocket);

  @override
  X509Certificate? get peerCertificate => _rawSecureSocket.peerCertificate;

  @override
  @Deprecated("Not implemented")
  void renegotiate(
          {bool useSessionCache = true,
          bool requestClientCertificate = false,
          bool requireClientCertificate = false}) =>
      _rawSecureSocket.renegotiate();

  @override
  String? get selectedProtocol => _rawSecureSocket.selectedProtocol;
}

/// A [RawServerSocket] wrapper that implements the [ServerSocket] interface.
///
/// This class wraps a [RawServerSocket] and exposes it as a [RawServerSocketAsServerSocket] by
/// implementing the [ServerSocket] interface. It allows the [RawServerSocket]
/// to be used in contexts that expect a [ServerSocket], providing a stream of
/// incoming [Socket] connections.
class RawServerSocketAsServerSocket extends Stream<Socket>
    implements ServerSocket {
  final RawServerSocket _rawServerSocket;
  final StreamController<Socket> _streamController;

  RawServerSocketAsServerSocket(this._rawServerSocket,
      {StreamController<Socket>? streamController})
      : _streamController = _resolveStream(_rawServerSocket, streamController);

  static StreamController<Socket> _resolveStream(
      RawServerSocket rawServerSocket,
      StreamController<Socket>? streamController) {
    if (streamController != null) return streamController;

    streamController = StreamController<Socket>();

    rawServerSocket.listen((rawSocket) {
      streamController!.add(rawSocket.asSocket());
    });

    return streamController;
  }

  @override
  InternetAddress get address => _rawServerSocket.address;

  @override
  int get port => _rawServerSocket.port;

  @override
  StreamSubscription<Socket> listen(void Function(Socket event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _streamController.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<ServerSocket> close() async {
    await _rawServerSocket.close();
    return this;
  }
}

/// A [RawServerSocket] wrapper that implements the [SecureServerSocket] interface.
///
/// This class wraps a [RawServerSocket] and exposes it as a [RawServerSocketAsSecureServerSocket] by
/// implementing the [SecureServerSocket] interface. It allows the [RawServerSocket]
/// to be used in contexts that expect a [SecureServerSocket], providing a stream of
/// incoming [SecureSocket] connections.
class RawServerSocketAsSecureServerSocket extends Stream<SecureSocket>
    implements SecureServerSocket {
  final RawServerSocket _rawServerSocket;
  final StreamController<SecureSocket> _streamController;

  RawServerSocketAsSecureServerSocket(this._rawServerSocket,
      {required StreamController<SecureSocket> streamController})
      : _streamController = streamController;

  @override
  InternetAddress get address => _rawServerSocket.address;

  @override
  int get port => _rawServerSocket.port;

  @override
  StreamSubscription<SecureSocket> listen(
          void Function(SecureSocket event)? onData,
          {Function? onError,
          void Function()? onDone,
          bool? cancelOnError}) =>
      _streamController.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<SecureServerSocket> close() async {
    await _rawServerSocket.close();
    return this;
  }
}

/// A [RawSecureServerSocket] wrapper that implements the [SecureServerSocket] interface.
///
/// This class wraps a [RawSecureServerSocket] and exposes it as a [RawSecureServerSocketAsSecureServerSocket] by
/// implementing the [SecureServerSocket] interface. It allows the [RawSecureServerSocket]
/// to be used in contexts that expect a [SecureServerSocket], providing a stream of
/// incoming [SecureSocket] connections.
class RawSecureServerSocketAsSecureServerSocket extends Stream<SecureSocket>
    implements SecureServerSocket {
  final RawSecureServerSocket _rawSecureServerSocket;
  final StreamController<SecureSocket> _streamController;

  RawSecureServerSocketAsSecureServerSocket(this._rawSecureServerSocket,
      {StreamController<SecureSocket>? streamController})
      : _streamController =
            _resolveStream(_rawSecureServerSocket, streamController);

  static StreamController<SecureSocket> _resolveStream(
      RawSecureServerSocket rawSecureServerSocket,
      StreamController<SecureSocket>? streamController) {
    if (streamController != null) return streamController;

    streamController = StreamController<SecureSocket>();

    rawSecureServerSocket.listen((rawSecureSocket) {
      streamController!.add(rawSecureSocket.asSecureSocket());
    });

    return streamController;
  }

  @override
  InternetAddress get address => _rawSecureServerSocket.address;

  @override
  int get port => _rawSecureServerSocket.port;

  @override
  StreamSubscription<SecureSocket> listen(
          void Function(SecureSocket event)? onData,
          {Function? onError,
          void Function()? onDone,
          bool? cancelOnError}) =>
      _streamController.stream.listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Future<SecureServerSocket> close() async {
    await _rawSecureServerSocket.close();
    return this;
  }
}
