# Audio Streaming

The player uses `just_audio` with HTTP streaming and `Range` support enabled by default.

## Streaming behavior

- Audio URLs are constructed from `audioBaseUrl` + `recording.audioPath`.
- The token is sent as an `Authorization: Bearer <token>` header.
- No full-file preloading; playback streams as needed.

## Supported formats

WAV, MP3, M4A, OGG, WebM (as supported by the OS codecs).
