# Omarchy Bandcamp

A native Quickshell player for your purchased Bandcamp collection. Browse album artwork, filter by artist or album, open tracklists, queue records, and control playback from a compact player or Linux media keys. Colours follow the active Omarchy theme.

Uses **Bandcamp's official Subsonic beta** and mpv. No browser runs during playback.

## Run

Requires Omarchy 4 / Quickshell, mpv, uv, and optionally Secret Service (`secret-tool`) for remembered logins.

```bash
cd ~/code/omarchy-bandcamp
uv sync --frozen
./bin/omarchy-bandcamp
```

The launcher opens the Omarchy plugin when installed; otherwise it starts the standalone player. `--standalone` explicitly selects the standalone shell. Re-running it brings the existing standalone player forward. In standalone mode, closing the library shows the mini-player; Quit exits both. Playback continues while switching between library and mini-player.

## Connect your collection

1. Open [Bandcamp Fan Settings](https://bandcamp.com/settings?pane=fan).
2. Scroll to **Subsonic** and generate credentials.
3. Enter that generated username and password in the player. Your ordinary Bandcamp password is not the right credential.
4. Optionally select **Remember securely on this computer** to save the login in your desktop keyring. Otherwise it is kept only for this session.

The fixed server is `https://bandcamp.com/api/subsonic`. Login checks collection access, since a successful ping alone does not prove authentication. Credentials are sent through private process pipes and HTTPS, never process arguments. No passwords are written into project or configuration files. Album artwork is cached under `$XDG_CACHE_HOME/omarchy-bandcamp` (normally `~/.cache/omarchy-bandcamp`). Desktop metadata contains only local artwork URLs.

## Omarchy plugin

The project contains service, bar-widget, and panel entry points under plugin ID `its.bandcamp`. It is linked into `~/.config/omarchy/plugins/its.bandcamp` and enabled in the right bar section on this machine. The `omarchy-bandcamp` command is installed in `~/.local/bin`. Keep this project and its `.venv` available through those links. Do not run the standalone player and plugin simultaneously: one process owns Bandcamp's media controls.

To hide the library, close it or press Mini; playback remains in the bar. To disable the plugin, run `omarchy plugin disable its.bandcamp`.

The bar widget opens a mini-player on left-click, opens the collection on right-click, pauses on middle-click, and changes tracks with the scroll wheel. The built-in Omarchy media widget can also control the standalone player through MPRIS.

## Checks

```bash
dbus-run-session -- env BANDCAMP_INTEGRATION=1 .venv/bin/python -m unittest discover -s tests -v
```

Includes silent real mpv playback and an isolated D-Bus client test. Tests use local fixtures, not your account. Authenticated collection access and streaming need a live user login before this can be considered verified with Bandcamp.

## Scope

This first version streams your collection; it does not yet download audio, edit Bandcamp playlists, or browse the public catalogue. Subsonic is a Bandcamp beta and large collections may load slowly. Refresh retries failed collection requests.

Research: [Bandcamp announcement](https://blog.bandcamp.com/2026/07/16/discover-improvements-and-subsonic-implementation/), [Nocturne's Subsonic adapter](https://github.com/Jeffser/Nocturne/blob/main/src/integrations/navidrome.py), [Omarchy Spotify](https://github.com/stappmus/Omarchy-Spotify), [Subsonic protocol](https://www.subsonic.org/pages/api.jsp). Original implementation; unofficial and unaffiliated with Bandcamp.
