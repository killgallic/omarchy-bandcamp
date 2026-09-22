# Native player implementation plan

Goal: deliver a runnable native Bandcamp collection player and Omarchy plugin.
Architecture: Python Subsonic client and mpv owner, private NDJSON IPC to Quickshell; MPRIS on the session bus.

- [x] API: add tests for salted auth, XML/JSON errors, collection pagination and album normalization; run `python -m unittest discover -s tests -v` red, implement `bandcamp/api.py`, run green.
- [x] Backend: implement queue and mpv IPC with EOF/error handling, login via generated credentials, Secret Service persistence, private artwork cache, snapshots. Add behavioral tests and a real local-audio smoke check.
- [x] UI: implement `Service.qml`, collection/login/detail/transport views, standalone `shell.qml`, and Omarchy `manifest.json`, `BarWidget.qml`, `Panel.qml`. Keep secrets out of process argv. Run offscreen loading checks.
- [x] Integration: add MPRIS, launcher/setup commands, README with exact login instructions, and validate on an isolated bus. Review for correctness and credential exposure; fix findings.
- [x] User test: launch the login screen after local checks; user generates credentials in Bandcamp Fan Settings and enters them in the app. Confirm collection and stream playback after login.

Protocol: commands are objects with `cmd` and arguments: login(username,password,remember), refresh, album(id), play_album(id,index), enqueue_album(id), play_index(index), toggle, next, previous, seek(position), volume(value 0..100), shuffle(enabled), repeat(mode none/all/one), logout, quit. Events: `{event:state,state:{connected,username,busy,error,albums,album,queue,index,playing,position,duration,volume,shuffle,repeat,current}}`. Albums/tracks use Subsonic id/name/title/artist/coverArt/duration and a local `art` file URL. Credentials and stream URLs never appear in snapshots. UI sends `{cmd:hello}` on process readiness if needed; backend emits initial state automatically. Additional `{event:raise}` asks UI to show its window.

Validation: 23 automated tests pass. User confirmed live login, collection loading, playback, pause/stop, volume, queue additions, shuffle and repeat on 2026-09-22. Omarchy plugin is enabled and the live MPRIS service is registered.
