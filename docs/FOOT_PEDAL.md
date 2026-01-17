# Foot Pedal Integration

The app listens for Infinity foot pedal events via a lightweight local WebSocket bridge.

## Recommended setup

1. Use a Node.js `node-hid` background service that reads the Infinity pedal (vendor ID `0x05f3`).
2. Emit WebSocket messages to `ws://127.0.0.1:5151` in the format:

```
{"pedal":"left","pressed":true}
{"pedal":"middle","pressed":true}
{"pedal":"middle","pressed":false}
{"pedal":"right","pressed":true}
```

## Mapping

- Left pedal → rewind 5s
- Middle pedal press → play while pressed, pause on release
- Right pedal → forward 5s

## Auto-reconnect

The Flutter client reconnects every 3 seconds if the bridge goes offline.
