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

The project contains service, bar-widget, and panel entry points under plugin ID `killgallic.bandcamp`. It is linked into `~/.config/omarchy/plugins/its.bandcamp` and enabled in the right bar section on this machine. The `omarchy-bandcamp` command is installed in `~/.local/bin`. Keep this project and its `.venv` available through those links. Do not run the standalone player and plugin simultaneously: one process owns Bandcamp's media controls.

To hide the library, close it or press Mini; playback remains in the bar. To disable the plugin, run `omarchy plugin disable killgallic.bandcamp`.

The bar widget opens the full player on left-click, the mini-player on right-click, pauses on middle-click, and changes tracks with the scroll wheel. The built-in Omarchy media widget can also control the standalone player through MPRIS.

## Checks

```bash
dbus-run-session -- env BANDCAMP_INTEGRATION=1 .venv/bin/python -m unittest discover -s tests -v
```

Includes silent real mpv playback and an isolated D-Bus client test. Tests use local fixtures, not your account. Authenticated collection access and streaming need a live user login before this can be considered verified with Bandcamp.

## Scope

The player streams your collection and manages Bandcamp playlists through Subsonic. Public discovery and editorial links open Bandcamp in your browser; collection playback stays native. Downloads are not implemented. Subsonic is a Bandcamp beta, so endpoint availability can vary.

## Preferences and onboarding

Login is remembered by default in the desktop keyring. Startup reconnects automatically without showing empty login fields. Uncheck Remember for a session-only login. An optional public profile URL in onboarding or Settings supplies your profile photo; Subsonic credentials do not expose your public handle.

Settings writes `~/.config/omarchy-bandcamp/config.json` (or `$XDG_CONFIG_HOME/omarchy-bandcamp/config.json`). It contains no passwords. Manual edits apply when the player restarts; UI changes apply immediately.

| Key | Default | Behavior |
| --- | --- | --- |
| `remember_login` | `true` | Restore generated credentials from Secret Service |
| `confirm_quit` | `true` | Ask before quitting; the dialog can turn this off, and Settings can turn it back on |
| `profile_url` | empty | Public `https://bandcamp.com/yourname` URL for cached avatar |
| `bar_display` | `icon_title` | `icon`, `title`, or `icon_title` |
| `bar_compact_when_idle` | `true` | Shrink the bar entry to its label when no track is selected |
| `bar_left_action` / `bar_right_action` | `library` / `mini` | Independent click actions (`library`, `mini`, `play_pause`, `none`) |
| `mini_player_enabled` | `true` | Enable mini player (disabled falls back to library) |
| `mini_player_width` | `460` | Width from 440–900 pixels |
| `mini_show_artwork` | `true` | Artwork in compact controls |
| `large_player_width` | `1000` | Initial library width, 660–3000 |
| `large_player_height` | `760` | Initial library height, 620–2000 |
| `show_discover_links` | `true` | Bandcamp Discover and Daily links |
| `wheel_acceleration` | `true` | Accelerate rapid consecutive wheel turns, capped at 5× |
| `wheel_scroll_pixels` | `360` | Mouse wheel travel per notch, 120–1200 |
| `stream_retries` | `2` | Automatic attempts after stream failure, 0–5 |
| `metadata_enrichment` | `false` | Optional MusicBrainz tags |

Left-click the bar entry to open or close the full player by default; right-click opens the mini-player without closing the full player, middle-click toggles playback, and wheel skips tracks. Home, Collection, Playlists, and Queue live at the top of the full player. Closing the window keeps playback running; Quit stops playback and asks for confirmation by default.

## Collection and playback

Search album/artist text and open Artist, Genre, or Tags filter buttons for searchable, scrollable multi-select lists with contextual record counts. Each menu can order choices by most records, least records, A–Z, or Z–A. Values within one category use OR; different categories combine with AND. Remove selections using their chips or Clear all. Sort has its own dropdown. Native Bandcamp genres and optional MusicBrainz tags remain distinct. MusicBrainz coverage and scan results appear under Settings → Collection tags. Recently added uses Bandcamp's collection-added timestamps, not a guaranteed purchase date. Most played here/recently played track qualified listens in this app only (half a track or four minutes, whichever comes first). Local per-account history lives under `$XDG_STATE_HOME/omarchy-bandcamp`.

Mouse wheel starts at 360 pixels per notch, configurable from 120–1200 in Settings. Quick consecutive turns accelerate exponentially up to 5×; a pause or direction change resets the speed. Disable acceleration in Settings if preferred. Middle-click starts autoscroll; move away from its marker to adjust speed. Click, wheel, Escape, page change, or window deactivation stops it. Trackpads retain native scrolling.

Add individual tracks or whole albums to the queue and remove queue entries. Playlists can be saved from the queue, appended to, renamed, reordered, and deleted (with confirmation). Playlist edits sync through Bandcamp's API and do not change the current queue.

Stream failures retry with fresh signed URLs and bounded backoff. A toolbar spinner shows loading/buffering; a warning reveals errors and Retry reloads the selected track. Stop and newer playback actions cancel obsolete retries.

## Optional metadata cache

Enabling MusicBrainz sends artist and album names to its free public API. It needs no API key. Strict artist/title matching rejects ambiguous releases. Requests run serially, at most one per 1.05 seconds; rate-limit responses pause enrichment. Playback never depends on it.

`~/.cache/omarchy-bandcamp/metadata.json` holds at most 1 MiB / 1,000 entries. Matches expire after 30 days; misses after 7. Cached tags remain available during service cooldowns. MusicBrainz tags are separate from Bandcamp genres; they are not claimed to be Bandcamp's full tag catalogue.

## Verification

`dbus-run-session -- env BANDCAMP_INTEGRATION=1 .venv/bin/python -m unittest discover -s tests -v` exercises API contracts, account/config behavior, queues, metadata cache, retry cancellation, and real silent mpv/MPRIS playback. Qt UI checks: `QT_QPA_PLATFORM=offscreen QT_QUICK_CONTROLS_STYLE=Basic QT_QPA_PLATFORMTHEME=generic /usr/lib/qt6/bin/qmltestrunner -input tests/qml`.

Live read-only probes verified collection metadata, playlist listing, POST support, public profile photo, and automatic stream transition. Playlist writes use mocked contract tests, not changes to an actual user's playlists.

Research: [Bandcamp announcement](https://blog.bandcamp.com/2026/07/16/discover-improvements-and-subsonic-implementation/), [Nocturne's Subsonic adapter](https://github.com/Jeffser/Nocturne/blob/main/src/integrations/navidrome.py), [Omarchy Spotify](https://github.com/stappmus/Omarchy-Spotify), [Subsonic protocol](https://www.subsonic.org/pages/api.jsp). Original implementation; unofficial and unaffiliated with Bandcamp.

## Public plugin setup

After `omarchy plugin add https://github.com/killgallic/omarchy-bandcamp`, run `bin/setup` from the cloned plugin directory. It checks for `uv` and `mpv` and installs the locked Python dependencies into a local `.venv`. The player presents this setup step if opened before dependencies are installed. No sudo or installation happens automatically when the bar loads.

The large player now opens on Home. The profile image and Bandcamp wordmark return there from anywhere; Browse all records leads to the filterable grid. Right-click album art or a song (or use its `⋯` button / Menu key) to add it to the queue or a playlist. New playlists can be empty. Bandcamp searches are clearly labelled when a canonical artist or release URL is not available from the Subsonic API.

Bar defaults: left-click full player, right-click mini-player, middle-click play/pause. Settings independently change left and right actions, choose one of four text formats or a custom `{Artist}`, `{Album}`, `{Song Name}`, `{State}` format, and control overflow, width, and scroll speed. A mouse-speed slider controls 120–1200 px per notch, with the existing accelerated burst handling.

MusicBrainz consent is separate from Generate tags. The scan shows progress, matched/cached/unmatched counts, and last completion. Startup loads cached tags only. Total cache has a 256 MiB default limit, configurable from 32–2048 MiB, with per-category clear buttons. Clearing caches does not delete music or playlists from Bandcamp, local listening history, or saved login.

Use `tests/run-python`, `tests/run-qml`, and `tests/check-package` for local checks. CI runs those checks in an Arch container. Releases are prepared as drafts from reviewed version tags.

Existing local installs under `its.bandcamp` can migrate the bar entry and symlink to `killgallic.bandcamp`; preferences, cached artwork, listening history, and Secret Service login remain under the unchanged `omarchy-bandcamp` storage namespace.

## Preview

Synthetic sample records, with no listener data:

![Home screen with recently added records, playlists, and discovery](assets/screenshots/home.png)

![Filterable record collection](assets/screenshots/collection.png)

A fresh collection snapshot is cached per account for 15 minutes by default. Startup first verifies the saved Subsonic credentials through an authenticated playlist request before using that snapshot. If a saved account cannot reconnect, the player offers a clearly marked read-only offline browser with search, Artist/Genre filters, and a Reconnect action; playback and playlist writes remain unavailable. The cache age and total disk budget are adjustable in Settings. Public profile collection pages can provide verified release URLs and partial purchase dates; records without a verified match use labelled Bandcamp searches and sort after dated purchases.
