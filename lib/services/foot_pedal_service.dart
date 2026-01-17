import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class FootPedalEvent {
  FootPedalEvent({required this.pedal, required this.pressed});

  final String pedal;
  final bool pressed;

  factory FootPedalEvent.fromJson(Map<String, dynamic> json) {
    return FootPedalEvent(
      pedal: json['pedal'] as String? ?? 'middle',
      pressed: json['pressed'] as bool? ?? false,
    );
  }
}

class FootPedalService {
  FootPedalService({this.url = 'ws://127.0.0.1:5151'});

  final String url;
  WebSocketChannel? _channel;
  final _controller = StreamController<FootPedalEvent>.broadcast();
  Timer? _reconnectTimer;

  Stream<FootPedalEvent> get events => _controller.stream;

  void start() {
    _connect();
  }

  Future<void> _connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel?.ready; // Wait for connection to be established
      _channel?.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _controller.add(FootPedalEvent.fromJson(data));
          } catch (e) {
            // Ignore malformed messages
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
      );
    } catch (e) {
      // Silently handle connection failures - foot pedal is optional
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.close();
  }
}
