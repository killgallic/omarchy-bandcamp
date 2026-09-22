# Omarchy Bandcamp

Approved direction: native Quickshell player modeled on Omarchy Spotify, primarily for the user's purchased collection. No browser required during playback.

Research on 2026-09-22 found Bandcamp's official Subsonic beta, announced July 16, 2026: https://blog.bandcamp.com/2026/07/16/discover-improvements-and-subsonic-implementation/
Fan Settings generates a dedicated username/password; endpoint is https://bandcamp.com/api/subsonic. Nocturne's src/integrations/navidrome.py confirms the .view endpoint suffix and salted-token authentication. The eremef/bandcamp-player wrapper instead opens a temporary Electron login window and reuses cookies; that approach is unnecessary here. Omarchy Spotify provides the reference service/bar/panel plugin contract. All implementation here is original.

## Design

Python backend owns credentials, collection pagination, album details, queue, and mpv IPC. A Quickshell service speaks newline-delimited JSON over private process pipes. Credentials never appear in command arguments or UI state snapshots. Store a remembered login in desktop Secret Service; if unavailable offer session-only operation instead of silently storing a plaintext password. Use generated credentials, never the ordinary Bandcamp account password.

The QML interface offers login, an album grid, title/artist filtering, album tracklists, play/enqueue, queue selection, transport controls, shuffle/repeat and a compact player. Omarchy plugin entry points share one service. A standalone shell entry allows development without modifying the desktop. Use the host's theme colors. Hiding either UI preserves playback. Explicit quit shuts down the owned backend/mpv. MPRIS exports Bandcamp separately from other players.

Network requests use HTTPS and fresh salted tokens. Accept JSON and XML Subsonic responses, map errors into safe user messages without authenticated URLs, paginate until exhaustion, and reject repeating pages. Cache artwork locally so authenticated image URLs are not broadcast through MPRIS. Stream URLs are passed through mpv's private IPC rather than argv. On expired credentials, return to login; network failure preserves the loaded collection and is retryable.

## Validation and limits

Automated fixture tests cover auth encoding, XML/JSON responses, pagination, credential errors and queue boundaries. Smoke-test mpv with a generated local audio fixture and validate Quickshell loading offscreen. Exercise MPRIS on an isolated session bus. Final authenticated collection/stream checks require the user to enter generated credentials locally. No claim of live account verification before that test.

This first build does not implement purchases, global discovery, downloads, playlist editing or offline audio. Those are not required for collection streaming. Full collection access and browser-free playback remain the acceptance target.
