# Collection UX improvements

User confirmed the first version works with live login, streaming, queue, shuffle and repeat. Requested clearer onboarding, faster scrolling, middle-click autoscroll, playlist saving/management, strong artist/name/tag filters, most-played and recently-purchased sorting where possible.

## Design

Preserve the album grid and compact player. Add a searchable artist selector, album/artist text search, available tag/genre filter, sort selector and reset filters. Preserve filter/scroll context when returning from an album. Middle-click toggles autoscroll using pointer displacement from an anchor; stop with middle/left/right click, Escape, wheel, view change, or window deactivation. Normal wheel scrolling covers roughly 120 pixels per notch and trackpad pixel deltas remain proportional.

Onboarding explains the three steps beside the fields: open Fan Settings, scroll to Subsonic, generate and copy its separate username/password. A direct button opens the exact settings page. Keep a short troubleshooting expander and do not clear the password on a rejected login; successful login destroys the fields. No credential values enter logs or argv.

Playlists use Bandcamp's official Subsonic API so changes sync to Bandcamp. Support list/open/play, save queue as new playlist, append queue, rename, remove selected track, move tracks up/down, and delete with an in-app confirmation. User actions trigger mutations; development probes are read-only. Refresh authoritative playlist details after successful writes and retain the UI on error.

Collection metadata and sorting must be honest: use actual API fields and server-supported sort orders, distinguish genre from Bandcamp tags, and label local-only play history explicitly. Do not invent purchase dates or historical play counts. Record local completed listens for most-played-here sorting and persist per account without credentials.

## Tasks

- [x] Read-only API capability probe using app credentials only if remembered; compare Subsonic docs.
- [x] API tests: repeated songId encoding, XML playlist lists, safe errors, playlist CRUD and sort parameters. Implement client methods.
- [x] Backend: playlist commands/state, collection sorting preserving cover art, per-account history with valid-listen thresholds. Add focused tests and regressions.
- [x] QML: onboarding, filters, sort, scrolling/autoscroll, playlist views/actions and clear busy/error feedback. Fixture UI checks include input behavior.
- [ ] Run full Python/local mpv/MPRIS tests, QML smoke tests, inspect screenshots, review changes.
- [ ] Deploy after checks with care for the active playback session; preserve the working first-version commit.

## UI/backend protocol additions

State is still patch-merged. New keys: playlists (summary list), playlist (detail object with entry tracks), playlistBusy, playlistError, collectionOrder, collectionNotice, history (per-album local plays/lastPlayed), tagSource. Albums retain genre/tags/created/playCount when supplied. Commands: playlists; playlist(id); play_playlist(id,index=0); save_playlist(name) from current queue; append_playlist(id) from current queue; rename_playlist(id,name); remove_playlist_track(id,index); move_playlist_track(id,index,direction=-1|1); delete_playlist(id); collection_order(order=artist|album|newest|most_played|recent_played). Sorting emits complete albums in display order; text/artist/tag filtering remains in QML. Queue contents are unaffected by library/playlist edits. All mutations occur only on explicit UI actions.


## Additional approved scope

Remember login defaults on and uses Secret Service; startup shows reconnecting until the saved login is checked. Optional public profile URL in onboarding/settings loads a cached public avatar because Bandcamp Subsonic does not expose the fan handle or image. Configuration is validated JSON in XDG_CONFIG_HOME/omarchy-bandcamp, without credentials. Settings control bar display/click, mini visibility/width/artwork, large dimensions, discovery links and retry count. Bar icon toggles/minimizes the library by default.

Playback now has bounded fresh-URL retries, timeout feedback and cancellation when stopped or superseded. Single-track enqueue and queue removal are supported. Local and live silent automatic-next probes passed; the originally reported intermittent failure was not reproduced. Regression tests found and fixed Stop racing pending stream setup and overlapping mpv starts.

MusicBrainz enrichment is opt-in, serial and rate-limited, with strict artist/title matching and a bounded on-disk cache (1 MiB/1,000 entries; 30-day positives/7-day misses). Cached tags remain usable during API cooldown. Native Bandcamp genres and collection-added dates retain their actual provenance. No live playlist writes occurred in development.


## Filter revision inspired by Waxlog

Reference: https://www.waxlog.com/ and its published filtering screenshot. Adopt compact dropdown buttons, stackable choices and removable active chips. For a native Bandcamp collection use Artist, Genre, optional MusicBrainz Tags and a separate Sort control; omit vinyl-specific pressing/format filters not supplied by this API. Options are searchable, multi-select, show contextual counts and remain open while selecting. OR within a category, AND across categories. Each popup owns a clipped, bounded ListView with visible scrollbar, wheel handling and keyboard selection. Explicit Popup.Item avoids platform ComboBox popup behavior. Test long lists, search, multi-select, keyboard/Escape, intersection/counts, and preserving collection scroll after layout changes.

Bar icon revised to 18×12 pixels to match neighboring desktop icons.
