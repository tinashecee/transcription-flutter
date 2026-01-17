# Updates

The app checks `GET /api/check-updates` for a payload:

```
{
  "version": "1.0.2",
  "url": "https://download.testimony.co.zw/releases/1.0.2/setup.exe",
  "mandatory": false
}
```

## Flow

1. Check for update on launch or from a settings action.
2. Download the installer to the app support directory.
3. Launch the installer and exit the app gracefully.
4. Installer replaces binaries and restarts.

`UpdateService` handles steps 1–2. Installer execution can be wired in the platform layer.
