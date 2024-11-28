import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class RawSocketAsSocket extends Stream<Uint8List> implements Socket {
  final RawSocket _rawSocket;

  @override
  Encoding encoding;

  RawSocketAsSocket(this._rawSocket, {Encoding? encoding})
      : encoding = encoding ?? utf8;

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
  void add(List<int> data) => _rawSocket.write(data);

  @override
  void write(Object? data) {
    var bs = encoding.encode(data.toString());
    _rawSocket.write(bs);
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    if (separator.isNotEmpty) {
      var i = 0;
      for (var o in objects) {
        if (i > 0) {
          write(separator);
        }
        write(o);
        i++;
      }
    } else {
      for (var o in objects) {
        write(o);
      }
    }
  }

  @override
  Future<void> close() async {
    await _rawSocket.close();
  }

  @override
  void destroy() {
    _rawSocket.close();
  }

  @override
  void writeln([Object? object = ""]) {
    write(object);
    write("\n");
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    // TODO: implement addError
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    // TODO: implement addStream
    throw UnimplementedError();
  }

  @override
  // TODO: implement done
  Future get done => throw UnimplementedError();

  @override
  Future flush() {
    // TODO: implement flush
    throw UnimplementedError();
  }

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    // TODO: implement listen
    throw UnimplementedError();
  }
}
