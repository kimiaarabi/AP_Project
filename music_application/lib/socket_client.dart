import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';

class SocketClient {
  final String host;
  final int port;
  Socket? _socket;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  String? _token;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isConnected => _socket != null;

  SocketClient({required this.host, required this.port});

  Future<void> connect({Duration timeout = const Duration(seconds: 5)}) async {
    _socket = await Socket.connect(host, port, timeout: timeout);
    _socket!
        .transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>)
        .transform(const LineSplitter())
        .listen((line) {
      final msg = jsonDecode(line) as Map<String, dynamic>;
      if (msg.containsKey('event')) {
        _events.add(msg);
      } else if (msg.containsKey('reqId')) {
        final id = msg['reqId'] as String;
        _pending.remove(id)?.complete(msg);
      }
    }, onDone: _cleanup, onError: (_) => _cleanup());
  }

  void _cleanup() {
    _socket?.destroy();
    _socket = null;
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError('Disconnected');
    }
    _pending.clear();
  }

  void setToken(String? t) => _token = t;

  Future<Map<String, dynamic>> request(String action,
      {Map<String, dynamic>? data, String? token}) async {
    if (_socket == null) throw 'Not connected';
    final reqId = const Uuid().v4();
    final c = Completer<Map<String, dynamic>>();
    _pending[reqId] = c;

    final msg = {
      'reqId': reqId,
      'action': action,
      if (_token != null || token != null) 'token': token ?? _token,
      if (data != null) 'data': data,
    };
    _socket!.write(jsonEncode(msg) + '\n');

    final res = await c.future;
    if (res['ok'] == true) {
      final r = res['result'];
      if (r is Map<String, dynamic>) return r;
      return {'result': r};
    } else {
      throw res['error'] ?? 'error';
    }
  }

  void dispose() {
    _cleanup();
    _events.close();
  }
}
