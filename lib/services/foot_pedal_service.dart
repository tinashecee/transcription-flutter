import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:io';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

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

  _WindowsHidPedal? _windowsHidPedal;

  Stream<FootPedalEvent> get events => _controller.stream;
  Stream<bool> get connectionStatus => _statusController.stream;
  bool get isConnected => _isConnected;

  void start() {
    if (Platform.isWindows) {
      _startWindowsHid();
      return;
    }
    _connectWebSocket();
  }

  Future<void> _startWindowsHid() async {
    if (_windowsHidPedal != null) return;
    _windowsHidPedal = _WindowsHidPedal(vendorId: 0x05F3);
    _windowsHidPedal!.events.listen(
      (event) {
        _controller.add(event);
      },
      onError: (e) {
        // optional: keep service alive
        print('[FootPedal][HID] error: $e');
      },
    );
    await _windowsHidPedal!.start();
    _setConnected(_windowsHidPedal!.isConnected);
  }

  Future<void> _connectWebSocket() async {
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
    _reconnectTimer = Timer(const Duration(seconds: 3), _connectWebSocket);
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _windowsHidPedal?.dispose();
    _controller.close();
    _statusController.close();
  }
}

class _WindowsHidPedal {
  _WindowsHidPedal({required this.vendorId});

  final int vendorId;

  final _eventsController = StreamController<FootPedalEvent>.broadcast();
  Stream<FootPedalEvent> get events => _eventsController.stream;

  bool isConnected = false;

  Isolate? _isolate;
  SendPort? _isolateCommandPort;
  ReceivePort? _receivePort;

  Future<void> start() async {
    if (_isolate != null) return;

    _receivePort = ReceivePort();
    _receivePort!.listen((message) {
      if (message is SendPort) {
        _isolateCommandPort = message;
        return;
      }
      if (message is Map) {
        final type = message['type'];
        if (type == 'status') {
          isConnected = message['connected'] == true;
          return;
        }
        if (type == 'event') {
          final pedal = (message['pedal'] as String?) ?? 'middle';
          final pressed = (message['pressed'] as bool?) ?? false;
          _eventsController.add(FootPedalEvent(pedal: pedal, pressed: pressed));
          return;
        }
        if (type == 'log') {
          final text = message['message'];
          if (text is String) {
            print(text);
          }
          return;
        }
      }
    });

    _isolate = await Isolate.spawn<_HidIsolateArgs>(
      _hidIsolateMain,
      _HidIsolateArgs(
        sendPort: _receivePort!.sendPort,
        vendorId: vendorId,
      ),
      debugName: 'windows-hid-footpedal',
    );
  }

  void dispose() {
    try {
      _isolateCommandPort?.send({'cmd': 'stop'});
    } catch (_) {}
    _receivePort?.close();
    _eventsController.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

class _HidIsolateArgs {
  _HidIsolateArgs({required this.sendPort, required this.vendorId});
  final SendPort sendPort;
  final int vendorId;
}

// Minimal hid.dll bindings (win32 package doesn't always export these symbols).
final DynamicLibrary _hidDll = DynamicLibrary.open('hid.dll');

typedef _HidD_GetHidGuid_Native = Void Function(Pointer<GUID> hidGuid);
typedef _HidD_GetHidGuid_Dart = void Function(Pointer<GUID> hidGuid);
final _HidD_GetHidGuid_Dart _HidD_GetHidGuid =
    _hidDll.lookupFunction<_HidD_GetHidGuid_Native, _HidD_GetHidGuid_Dart>(
  'HidD_GetHidGuid',
);

base class HIDD_ATTRIBUTES extends Struct {
  @Uint32()
  external int Size;

  @Uint16()
  external int VendorID;

  @Uint16()
  external int ProductID;

  @Uint16()
  external int VersionNumber;
}

typedef _HidD_GetAttributes_Native = Int32 Function(
  IntPtr hidDeviceObject,
  Pointer<HIDD_ATTRIBUTES> attributes,
);
typedef _HidD_GetAttributes_Dart = int Function(
  int hidDeviceObject,
  Pointer<HIDD_ATTRIBUTES> attributes,
);
final _HidD_GetAttributes_Dart _HidD_GetAttributes =
    _hidDll.lookupFunction<_HidD_GetAttributes_Native, _HidD_GetAttributes_Dart>(
  'HidD_GetAttributes',
);

typedef _HidD_GetProductString_Native = Int32 Function(
  IntPtr hidDeviceObject,
  Pointer<Void> buffer,
  Int32 bufferLength,
);
typedef _HidD_GetProductString_Dart = int Function(
  int hidDeviceObject,
  Pointer<Void> buffer,
  int bufferLength,
);
final _HidD_GetProductString_Dart _HidD_GetProductString =
    _hidDll.lookupFunction<_HidD_GetProductString_Native, _HidD_GetProductString_Dart>(
  'HidD_GetProductString',
);

void _hidIsolateMain(_HidIsolateArgs args) {
  final out = args.sendPort;

  void log(String msg) => out.send({'type': 'log', 'message': '[FootPedal][HID] $msg'});

  final commandPort = ReceivePort();
  out.send(commandPort.sendPort);

  var shouldStop = false;
  commandPort.listen((message) {
    if (message is Map && message['cmd'] == 'stop') {
      shouldStop = true;
    }
  });

  int? handle;
  var notFoundCount = 0;

  try {
    while (!shouldStop) {
      final devicePath = _findHidDevicePathByVendor(args.vendorId);
      if (devicePath == null) {
        notFoundCount++;
        out.send({'type': 'status', 'connected': false});
        log('Infinity pedal not found (vendor=0x${args.vendorId.toRadixString(16)}). Retrying...');
        // Dump HID devices occasionally to help identify the correct VID/PID/interface.
        if (notFoundCount == 1 || (notFoundCount % 10 == 0)) {
          _dumpHidDevices(log);
        }
        Sleep(1500);
        continue;
      }

      notFoundCount = 0;
      log('Found device path: $devicePath');

      final pathPtr = devicePath.toNativeUtf16();
      try {
        handle = CreateFile(
          pathPtr,
          GENERIC_READ, // keep it simple: read-only
          FILE_SHARE_READ | FILE_SHARE_WRITE,
          nullptr,
          OPEN_EXISTING,
          0,
          0,
        );
      } finally {
        calloc.free(pathPtr);
      }

      if (handle == INVALID_HANDLE_VALUE) {
        out.send({'type': 'status', 'connected': false});
        log('CreateFile failed (err=${GetLastError()}). Retrying...');
        Sleep(1500);
        continue;
      }

      out.send({'type': 'status', 'connected': true});
      log('Connected. Reading reports...');

      var lastButtonsByte = -1;
      final buffer = calloc<Uint8>(64);
      final bytesRead = calloc<Uint32>();

      try {
        while (!shouldStop) {
          bytesRead.value = 0;
          final ok = ReadFile(handle, buffer, 64, bytesRead, nullptr);
          if (ok == 0) {
            final err = GetLastError();
            out.send({'type': 'status', 'connected': false});
            log('ReadFile failed (err=$err). Reconnecting...');
            break;
          }

          if (bytesRead.value <= 0) {
            Sleep(5);
            continue;
          }

          // Copy report bytes for logging/parsing
          final len = bytesRead.value;
          final report = List<int>.generate(len, (i) => buffer[i]);
          final hex = report
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(' ');

          // Many HID devices use byte0 as Report ID (often 0), and data starts at byte1.
          // Heuristic: if report[0] == 0 and we have at least 2 bytes, use report[1] as buttons.
          final buttonsByte = (len >= 2 && report[0] == 0) ? report[1] : report[0];

          if (buttonsByte == lastButtonsByte) {
            // No button-state change; nothing to emit.
            continue;
          }

          final prev = lastButtonsByte;
          lastButtonsByte = buttonsByte;

          final left = (buttonsByte & 0x01) != 0;
          final right = (buttonsByte & 0x02) != 0;
          final middle = (buttonsByte & 0x04) != 0;

          log(
            'report: bytes=[$hex] buttons=$buttonsByte (0x${buttonsByte.toRadixString(16).padLeft(2, '0')}) '
            'left=$left middle=$middle right=$right (prev=${prev < 0 ? 'none' : '0x${prev.toRadixString(16).padLeft(2, '0')}'})',
          );

          // Emit on state transitions:
          // - left/right: press only (rising edge)
          // - middle: press + release (level)
          final prevLeft = prev >= 0 ? ((prev & 0x01) != 0) : false;
          final prevRight = prev >= 0 ? ((prev & 0x02) != 0) : false;
          final prevMiddle = prev >= 0 ? ((prev & 0x04) != 0) : false;

          if (left && !prevLeft) {
            log('emit: left pressed');
            out.send({'type': 'event', 'pedal': 'left', 'pressed': true});
          }
          if (right && !prevRight) {
            log('emit: right pressed');
            out.send({'type': 'event', 'pedal': 'right', 'pressed': true});
          }
          if (middle != prevMiddle) {
            log('emit: middle pressed=$middle');
            out.send({'type': 'event', 'pedal': 'middle', 'pressed': middle});
          }
        }
      } finally {
        calloc.free(buffer);
        calloc.free(bytesRead);
        try {
          CloseHandle(handle);
        } catch (_) {}
        handle = null;
      }
    }
  } catch (e) {
    out.send({'type': 'status', 'connected': false});
    log('Fatal isolate error: $e');
    try {
      if (handle != null) CloseHandle(handle);
    } catch (_) {}
  } finally {
    commandPort.close();
  }
}

String? _findHidDevicePathByVendor(int vendorId) {
  final guidPtr = calloc<GUID>();
  try {
    _HidD_GetHidGuid(guidPtr);

    final deviceInfoSet = SetupDiGetClassDevs(
      guidPtr,
      nullptr,
      0,
      DIGCF_PRESENT | DIGCF_DEVICEINTERFACE,
    );

    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
      return null;
    }

    try {
      for (var deviceIndex = 0; ; deviceIndex++) {
        final deviceInterfaceData = calloc<SP_DEVICE_INTERFACE_DATA>()
          ..ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();
        try {
          final ok = SetupDiEnumDeviceInterfaces(
            deviceInfoSet,
            nullptr,
            guidPtr,
            deviceIndex,
            deviceInterfaceData,
          );
          if (ok == 0) break;

          final requiredSize = calloc<DWORD>();
          try {
            SetupDiGetDeviceInterfaceDetail(
              deviceInfoSet,
              deviceInterfaceData,
              nullptr,
              0,
              requiredSize,
              nullptr,
            );

            if (requiredSize.value <= 0) continue;

            final detailData = calloc<Uint8>(requiredSize.value);
            try {
              // SP_DEVICE_INTERFACE_DETAIL_DATA_W:
              // - On 64-bit: cbSize = 8
              // - On 32-bit: cbSize = 6
              final cbSize = sizeOf<IntPtr>() == 8 ? 8 : 6;
              detailData.cast<Uint32>().value = cbSize;

              final ok2 = SetupDiGetDeviceInterfaceDetail(
                deviceInfoSet,
                deviceInterfaceData,
                detailData.cast(),
                requiredSize.value,
                nullptr,
                nullptr,
              );
              if (ok2 == 0) continue;

              // NOTE: DevicePath starts immediately after the 4-byte DWORD cbSize field.
              // The cbSize VALUE is 8/6 for historical alignment reasons, but it's NOT the offset.
              final devicePathPtr = detailData
                  .cast<Uint8>()
                  .elementAt(sizeOf<Uint32>())
                  .cast<Utf16>();
              final devicePath = devicePathPtr.toDartString();

              final handle = CreateFile(
                devicePath.toNativeUtf16(),
                GENERIC_READ,
                FILE_SHARE_READ | FILE_SHARE_WRITE,
                nullptr,
                OPEN_EXISTING,
                0,
                0,
              );

              if (handle == INVALID_HANDLE_VALUE) continue;
              try {
                final attributes = calloc<HIDD_ATTRIBUTES>();
                try {
                  attributes.ref.Size = sizeOf<HIDD_ATTRIBUTES>();
                  final ok3 = _HidD_GetAttributes(handle, attributes);
                  if (ok3 == 0) continue;
                  if (attributes.ref.VendorID == vendorId) {
                    return devicePath;
                  }
                } finally {
                  calloc.free(attributes);
                }
              } finally {
                CloseHandle(handle);
              }
            } finally {
              calloc.free(detailData);
            }
          } finally {
            calloc.free(requiredSize);
          }
        } finally {
          calloc.free(deviceInterfaceData);
        }
      }
    } finally {
      SetupDiDestroyDeviceInfoList(deviceInfoSet);
    }
  } finally {
    calloc.free(guidPtr);
  }

  return null;
}

void _dumpHidDevices(void Function(String) log) {
  final guidPtr = calloc<GUID>();
  try {
    _HidD_GetHidGuid(guidPtr);

    final deviceInfoSet = SetupDiGetClassDevs(
      guidPtr,
      nullptr,
      0,
      DIGCF_PRESENT | DIGCF_DEVICEINTERFACE,
    );
    if (deviceInfoSet == INVALID_HANDLE_VALUE) {
      log('HID dump: SetupDiGetClassDevs failed (err=${GetLastError()})');
      return;
    }

    try {
      log('HID dump: enumerating HID interfaces...');
      var count = 0;
      var interfaceCount = 0;
      for (var deviceIndex = 0; ; deviceIndex++) {
        final deviceInterfaceData = calloc<SP_DEVICE_INTERFACE_DATA>()
          ..ref.cbSize = sizeOf<SP_DEVICE_INTERFACE_DATA>();
        try {
          final ok = SetupDiEnumDeviceInterfaces(
            deviceInfoSet,
            nullptr,
            guidPtr,
            deviceIndex,
            deviceInterfaceData,
          );
          if (ok == 0) {
            final err = GetLastError();
            if (deviceIndex == 0) {
              log('HID dump: no interfaces enumerated (err=$err)');
            }
            break;
          }

          final requiredSize = calloc<DWORD>();
          try {
            SetupDiGetDeviceInterfaceDetail(
              deviceInfoSet,
              deviceInterfaceData,
              nullptr,
              0,
              requiredSize,
              nullptr,
            );
            if (requiredSize.value <= 0) continue;

            final detailData = calloc<Uint8>(requiredSize.value);
            try {
              final cbSize = sizeOf<IntPtr>() == 8 ? 8 : 6;
              detailData.cast<Uint32>().value = cbSize;

              final ok2 = SetupDiGetDeviceInterfaceDetail(
                deviceInfoSet,
                deviceInterfaceData,
                detailData.cast(),
                requiredSize.value,
                nullptr,
                nullptr,
              );
              if (ok2 == 0) continue;

              final devicePathPtr = detailData
                  .cast<Uint8>()
                  .elementAt(sizeOf<Uint32>())
                  .cast<Utf16>();
              final devicePath = devicePathPtr.toDartString();
              interfaceCount++;

              final pathPtr = devicePath.toNativeUtf16();
              final handle = CreateFile(
                pathPtr,
                GENERIC_READ,
                FILE_SHARE_READ | FILE_SHARE_WRITE,
                nullptr,
                OPEN_EXISTING,
                0,
                0,
              );
              calloc.free(pathPtr);

              if (handle == INVALID_HANDLE_VALUE) {
                // Log only a few failures to avoid massive spam.
                if (interfaceCount <= 5) {
                  log('HID: CreateFile failed (err=${GetLastError()}) path=$devicePath');
                }
                continue;
              }

              try {
                final attributes = calloc<HIDD_ATTRIBUTES>();
                try {
                  attributes.ref.Size = sizeOf<HIDD_ATTRIBUTES>();
                  final ok3 = _HidD_GetAttributes(handle, attributes);
                  if (ok3 == 0) {
                    if (interfaceCount <= 5) {
                      log('HID: HidD_GetAttributes failed (err=${GetLastError()}) path=$devicePath');
                    }
                    continue;
                  }

                  String? product;
                  final productBuf = calloc<Uint16>(256); // UTF-16
                  try {
                    final ok4 = _HidD_GetProductString(handle, productBuf.cast(), 512);
                    if (ok4 != 0) {
                      product = productBuf.cast<Utf16>().toDartString();
                    }
                  } finally {
                    calloc.free(productBuf);
                  }

                  log(
                    'HID: VID=0x${attributes.ref.VendorID.toRadixString(16).padLeft(4, '0')} '
                    'PID=0x${attributes.ref.ProductID.toRadixString(16).padLeft(4, '0')} '
                    'Product="${product ?? ''}" '
                    'Path=$devicePath',
                  );
                  count++;
                } finally {
                  calloc.free(attributes);
                }
              } finally {
                CloseHandle(handle);
              }
            } finally {
              calloc.free(detailData);
            }
          } finally {
            calloc.free(requiredSize);
          }
        } finally {
          calloc.free(deviceInterfaceData);
        }
      }
      log('HID dump: done (interfaces=$interfaceCount listed=$count)');
    } finally {
      SetupDiDestroyDeviceInfoList(deviceInfoSet);
    }
  } catch (e) {
    log('HID dump failed: $e');
  } finally {
    calloc.free(guidPtr);
  }
}
