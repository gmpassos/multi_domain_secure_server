import 'dart:async';
import 'dart:collection';
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
  late final StreamController<Uint8List> _streamController;

  @override
  Encoding encoding;

  Completer<bool>? _writeCompleter;

  RawSocketAsSocket(this._rawSocket, {Encoding? encoding})
      : encoding = encoding ?? utf8 {
    _streamController = StreamController<Uint8List>();

    _rawSocket.readEventsEnabled = true;
    _rawSocket.writeEventsEnabled = false;

    _rawSocket.listen(
      (event) {
        switch (event) {
          case RawSocketEvent.read:
            {
              var bs = _rawSocket.read();
              if (bs != null) {
                _streamController.add(bs);
              }
            }
          case RawSocketEvent.write:
            {
              var writeCompleter = _writeCompleter;
              if (writeCompleter != null && !writeCompleter.isCompleted) {
                writeCompleter.complete(true);
              }
            }
          case RawSocketEvent.readClosed:
            {
              var w = _flushWriteQueue();
              if (w > 0) {
                Future.delayed(Duration(milliseconds: 2), () => close());
              } else {
                close();
              }
            }
          case RawSocketEvent.closed:
            {
              close();
            }
          default:
            break;
        }
      },
      onError: (e, s) => _streamController.addError(e, s),
      onDone: () => _streamController.close(),
      cancelOnError: true,
    );
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
    _writeImpl(data);
  }

  @override
  void write(Object? data) {
    _checkNotAddingStream();

    var bs = encoding.encode(data.toString());
    _writeImpl(bs);
  }

  void _writeImpl(List<int> bs, [int offset = 0, int? length]) {
    if (_closed) return;

    length ??= bs.length;

    _flushWriteQueue();

    if (_writeQueue.isNotEmpty) {
      _writeQueue.addLast((bs, offset, length));
      _scheduleFlushWriteQueue();
    } else {
      var w = _rawSocket.write(bs, offset, length);
      if (w < length) {
        _writeQueue.addLast((bs, offset + w, length - w));
        _scheduleFlushWriteQueue();
      }
    }
  }

  final Queue<(List<int>, int, int)> _writeQueue = Queue();
  Completer<bool>? _writeQueueComplete;

  int _flushWriteQueue() {
    var wTotal = 0;

    while (_writeQueue.isNotEmpty && !_closed) {
      var e = _writeQueue.first;

      var bs = e.$1;
      var offset = e.$2;
      var length = e.$3;

      var w = _rawSocket.write(bs, offset, length);
      wTotal += w;

      if (w == length) {
        _writeQueue.removeFirst();
      } else if (w == 0) {
        _scheduleFlushWriteQueue(slow: true);
        return wTotal;
      } else {
        _writeQueue.removeFirst();
        _writeQueue.addFirst((bs, offset + w, length - w));
        _scheduleFlushWriteQueue(fast: true);
        return wTotal;
      }
    }

    assert(_writeQueue.isEmpty);

    var writeQueueComplete = _writeQueueComplete;
    if (writeQueueComplete != null && !writeQueueComplete.isCompleted) {
      writeQueueComplete.complete(true);
      _writeQueueComplete = null;
    }

    return wTotal;
  }

  Future<bool>? _scheduleFlushWriteQueueFuture;

  void _scheduleFlushWriteQueue({bool slow = false, bool fast = false}) {
    if (_closed) return;

    var future = _scheduleFlushWriteQueueFuture;
    if (future != null) return;

    Duration delay;
    if (fast) {
      delay = Duration(milliseconds: 10);
    } else {
      var delayMs = slow ? 1000 : 100;
      delay = Duration(milliseconds: delayMs);
    }

    var writeCompleter = _writeCompleter ??= Completer<bool>();
    _rawSocket.writeEventsEnabled = true;

    _scheduleFlushWriteQueueFuture =
        future = writeCompleter.future.timeout(delay, onTimeout: () {
      if (!writeCompleter.isCompleted) {
        writeCompleter.complete(false);
      }
      return false;
    });

    future.then((ready) {
      if (identical(future, _scheduleFlushWriteQueueFuture)) {
        _scheduleFlushWriteQueueFuture = null;
      }
      if (identical(writeCompleter, _writeCompleter)) {
        _writeCompleter = null;
      }
      _rawSocket.writeEventsEnabled = false;
      _flushWriteQueue();
    });
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = ""]) {
    _checkNotAddingStream();

    if (object != '') {
      var bs = encoding.encode(object.toString());
      _writeImpl(bs);
    }

    _writeImpl(const [10]); // New line: \n
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
          _writeImpl(bs);
        }

        var separatorBs = encoding.encode(separator);

        while (itr.moveNext() && !_closed) {
          var o = itr.current;
          _writeImpl(separatorBs);
          var bs = encoding.encode(o.toString());
          _writeImpl(bs);
        }
      }
    } else {
      for (var o in objects) {
        var bs = encoding.encode(o.toString());
        _writeImpl(bs);
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
        (data) => _writeImpl(data),
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
    if (_writeQueue.isEmpty) {
      return Future.value();
    }

    return flushImpl();
  }

  Future<void> flushImpl() async {
    while (_writeQueue.isNotEmpty && !_closed) {
      var w = _flushWriteQueue();

      if (w == 0) {
        assert(_writeQueue.isNotEmpty);
        assert(_scheduleFlushWriteQueueFuture != null);

        var writeQueueComplete = _writeQueueComplete ??= Completer();
        await writeQueueComplete.future;
      }
    }
  }

  bool _closed = false;

  void _closeImpl() {
    _closed = true;

    var completers = [_writeCompleter, _writeQueueComplete].nonNulls;

    _writeCompleter = null;
    _writeQueueComplete = null;

    for (var c in completers) {
      if (!c.isCompleted) {
        c.complete(false);
      }
    }

    _streamController.close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;

    _flushWriteQueue();
    _writeQueue.clear();
    await _rawSocket.close();
    _closeImpl();
  }

  @override
  void destroy() {
    if (_closed) return;

    _flushWriteQueue();
    _writeQueue.clear();
    _rawSocket.shutdown(SocketDirection.both);
    _rawSocket.close();
    _closeImpl();
  }
}

/// A [RawSecureSocket] wrapper that implements the [SecureSocket] interface.
/// Extends [RawSocketAsSocket].
class RawSecureSocketAsSecureSocket extends RawSocketAsSocket
    implements SecureSocket {
  RawSecureSocket get _rawSecureSocket => _rawSocket as RawSecureSocket;

  //ignore: use_super_parameters
  RawSecureSocketAsSecureSocket(RawSecureSocket rawSecureSocket,
      {super.encoding})
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
  final StreamSubscription<RawSocket>? _acceptSubscription;
  final StreamController<Socket> _streamController;

  RawServerSocketAsServerSocket(this._rawServerSocket,
      {StreamSubscription<RawSocket>? acceptSubscription,
      StreamController<Socket>? streamController})
      : _acceptSubscription = acceptSubscription,
        _streamController = _resolveStream(_rawServerSocket, streamController);

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
    _streamController.close();
    _acceptSubscription?.cancel();
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
  final StreamSubscription<RawSocket>? _acceptSubscription;
  final StreamController<SecureSocket> _streamController;

  RawServerSocketAsSecureServerSocket(this._rawServerSocket,
      {StreamSubscription<RawSocket>? acceptSubscription,
      required StreamController<SecureSocket> streamController})
      : _acceptSubscription = acceptSubscription,
        _streamController = streamController;

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
    _streamController.close();
    _acceptSubscription?.cancel();
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
  final StreamSubscription<RawSecureSocket>? _acceptSubscription;
  final StreamController<SecureSocket> _streamController;

  RawSecureServerSocketAsSecureServerSocket(this._rawSecureServerSocket,
      {StreamSubscription<RawSecureSocket>? acceptSubscription,
      StreamController<SecureSocket>? streamController})
      : _acceptSubscription = acceptSubscription,
        _streamController =
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
    _streamController.close();
    _acceptSubscription?.cancel();
    return this;
  }
}
