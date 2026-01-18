import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class FootPedalEvent {
  FootPedalEvent({required this.pedal, required this.pressed});

  final String pedal;
  final bool pressed;

  factory FootPedalEvent.fromJson(Map<String, dynamic> json) {
    final rawCode = json['code'] ?? json['data0'] ?? json['value'];
    if (rawCode is num) {
      switch (rawCode.toInt()) {
        case 1:
          return FootPedalEvent(pedal: 'left', pressed: true);
        case 2:
          return FootPedalEvent(pedal: 'right', pressed: true);
        case 4:
          return FootPedalEvent(pedal: 'middle', pressed: true);
        default:
          return FootPedalEvent(pedal: 'middle', pressed: false);
      }
    }

    final action = (json['action'] as String?)?.toLowerCase().trim();
    if (action != null && action.isNotEmpty) {
      switch (action) {
        case 'rewind':
          return FootPedalEvent(pedal: 'left', pressed: true);
        case 'fast-forward':
          return FootPedalEvent(pedal: 'right', pressed: true);
        case 'play':
          return FootPedalEvent(pedal: 'middle', pressed: true);
        case 'pause':
          return FootPedalEvent(pedal: 'middle', pressed: false);
      }
    }

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
  final _statusController = StreamController<bool>.broadcast();
  Timer? _reconnectTimer;
  bool _isConnected = false;

  Stream<FootPedalEvent> get events => _controller.stream;
  Stream<bool> get connectionStatus => _statusController.stream;
  bool get isConnected => _isConnected;

  void start() {
    _connect();
  }

  Future<void> _connect() async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel?.ready; // Wait for connection to be established
      _setConnected(true);
      _channel?.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _controller.add(FootPedalEvent.fromJson(data));
          } catch (e) {
            // Ignore malformed messages
          }
        },
        onError: (_) => _handleDisconnected(),
        onDone: _handleDisconnected,
      );
    } catch (e) {
      // Silently handle connection failures - foot pedal is optional
      _handleDisconnected();
    }
  }

  void _handleDisconnected() {
    _setConnected(false);
    _scheduleReconnect();
  }

  void _setConnected(bool connected) {
    if (_isConnected == connected) return;
    _isConnected = connected;
    _statusController.add(connected);
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connect);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.close();
    _statusController.close();
  }
}
