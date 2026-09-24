# Omarchy marketplace submission packet

Repository: https://github.com/killgallic/omarchy-bandcamp
Plugin ID: `killgallic.bandcamp`; category Media.

A native Quickshell/Qt interface with a Python/mpv playback service for a fan's Bandcamp collection. It uses Bandcamp's official Subsonic beta for authenticated collection playback and playlists, desktop Secret Service for generated credentials, and optional MusicBrainz lookups for tags. Community and purchase actions open official Bandcamp pages. It does not embed a browser or persist signed stream URLs.

Requirements: Omarchy 4, Quickshell, Qt 6.8+, mpv, uv, Secret Service and a Bandcamp fan account with generated Subsonic credentials. Install with `omarchy plugin add <repository URL>`, then run `bin/setup` in the cloned plugin directory. After enabling the plugin, add its bar widget if it is not already placed. Settings/cache use the `omarchy-bandcamp` XDG namespace and survive plugin-ID migration. Uninstall through `omarchy plugin remove killgallic.bandcamp`; user data may be removed separately after backing up desired preferences/history.

Tests before submission: `tests/run-python`, `tests/run-qml`, `tests/check-package`, plus a live Omarchy shell smoke test, authenticating and playing a personally owned track, empty playlist create/add/delete, and a synthetic screenshot. Record the exact tested commit SHA and actual results in the marketplace issue. The public fan profile yields direct links for some records; unresolved records show a labelled Bandcamp search. MusicBrainz is opt-in. The Subsonic beta can change independently of this plugin.

Marketplace review and public release are separate actions. No core Omarchy change is presently required.
