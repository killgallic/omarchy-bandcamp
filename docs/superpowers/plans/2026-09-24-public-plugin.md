# Omarchy Bandcamp public-plugin implementation plan

> **For agentic workers:** Use the executing-plans skill to implement this plan task by task. Keep each milestone independently usable and reviewed. Do not publish or submit upstream as a side effect of local development.

**Goal:** Build a polished, configurable native Bandcamp player that fits Omarchy, supports artists, and is maintainable as a public plugin.

**Architecture:** Keep Python, mpv, MPRIS, Quickshell/QML, and the private JSON process protocol. Extract cohesive responsibilities from the existing backend and player view as those features change. Use concrete components and a small validated settings schema, not a general plugin framework or user-executable templates.

**Tech stack:** Python 3.11+, dbus-next, mpv, Secret Service, Qt Quick/Quickshell, uv, GitHub Actions. No browser runtime for playback. Official Bandcamp pages open externally for discovery, purchases, merch, and community interactions.

**Status:** Planning deliverable. The features below are not represented as implemented. The smaller icon, filter buttons, and current playback functionality already exist. Genre frequency sorting and accelerated wheel handling are a separate, tested follow-up to the preceding user request.

## 1. Product decisions and defaults

| Area | Decision |
| --- | --- |
| Home | A useful landing page, not the entire record grid. Profile image and Bandcamp wordmark are Home controls everywhere. |
| Navigation | Remove the Collection navigation button. Header exposes Playlists, Queue, Settings; Home provides Browse all records, and collection search opens filtered records. Back restores the prior route, filters, and scroll position. |
| Album/track actions | Right-click opens a focused menu. Keyboard Menu / Shift+F10 opens the same menu. A visible overflow button provides discoverability. |
| Empty playlists | New playlist requires only a name. It may contain zero tracks. Add tracks/albums later. |
| Mouse | Speed slider, accelerated rapid turns by default, controlled isolated turns, pause/reversal resets acceleration. Preserve genuine trackpad pixel scrolling. |
| Bar actions | Left: full player. Right: mini-player. Middle: play/pause. Left and right independently configurable. Clicking an already open target toggles that target. |
| Bar appearance | Four presets plus a custom format. Compact Artist — Song is the default. Text scrolls only when it overflows and playback is active; static elision remains available. |
| Theme | Follow Omarchy colors and fonts by default; no separate theme engine. Reduced motion disables marquee/animated scrolling. |
| Metadata | MusicBrainz remains opt-in. Consent and starting a scan are separate, visible actions. Cached tags can load without a new scan. |
| Feedback | Success toasts disappear. Actionable failures remain discoverable through a small status indicator and bounded activity history. |
| Cache | Bounded, inspectable, account-separated cache; no audio downloads, passwords, signed stream URLs, or tokens in it. |
| Publishing | Prepare source installation, tests, release artifacts, docs, and an upstream submission packet. Publication is a separate reviewed action. |

An expanded monolithic view would be quicker initially but make every new action harder to reason about. A generic action/plugin architecture would add machinery without a present need. Prefer a few reusable UI components and small domain modules with explicit interfaces.

## 2. Home and Bandcamp community experience

Home contains these compact sections, in order:

1. **Continue listening:** current record, queue status, resume action; hide when empty.
2. **Recently added:** up to eight records with a Browse all records link. Label collection-added dates honestly; do not claim exact purchase dates.
3. **Your playlists:** a short list and New playlist action; useful empty state.
4. **Rediscover your records:** locally chosen records not played recently. Explain that this uses this app's listening history, not a global recommendation system.
5. **Explore and support:** relevant artists from the user's records, plus clearly presented Bandcamp Discover and Bandcamp Daily destinations. Link to artist pages, releases, and available merch/support pages when verified.

Search is available at the top. Typing opens the full record browser with the existing filters. Home is reachable from album, playlist, queue, and settings via the profile/wordmark. In the mini-player, clicking the identity opens the full player at Home. An explicit external-link action opens the user's public Bandcamp profile; the avatar itself remains Home.

Album detail includes Artist on Bandcamp and View / support this release. Track details include its parent album link. Context menus offer the same destinations. Existing browser playback is not required, and embedded checkout, fake purchase flows, and scraped editorial headlines are outside the first public release.

### Canonical link capability check

The existing album/track allowlist does not retain canonical URLs, and the prior getAlbumInfo2 probe was unsupported. Before promising direct links:

- Inspect actual getAlbum/getSong/getArtist responses for a canonical public URL or a stable ID that can be mapped reliably.
- If unavailable, evaluate mapping records from the explicitly supplied public Bandcamp collection, storing only item IDs and canonical public links. Do not assume the public collection exposes every owned record.
- Store provenance and last verification with each mapping. Permit user-supplied links for unresolved records, scoped to that record.
- Never derive a purported canonical slug from an artist or album title. An unresolved item can offer a clearly labelled Search Bandcamp action, not a misleading direct link.
- Accept HTTPS destinations after URL validation. Account credentials never accompany external links.

The capability check is the first implementation step for this subsystem, not a reason to block the rest of the UI.

## 3. Album, track, and playlist interactions

Album context menu:

- Play now
- Add album to queue
- Add to playlist…
- View album details
- Artist on Bandcamp / View release on Bandcamp, when resolved

Track context menu:

- Play now
- Add track to queue
- Add to playlist…
- Track information
- View parent album / Bandcamp destinations, when available

Queue rows additionally offer Remove from queue. Playlist rows offer Remove from this playlist and Move up/down. Labels identify the scope, so removing a queue entry cannot look like deleting a purchase.

Add to playlist opens a reusable searchable picker with playlist names and track counts. Its New playlist row lets a user create-and-add without losing the original album/track selection. The payload snapshots the target item IDs at menu-open time; changing the currently playing record must not change the menu's target. Loading playlists does not block Add to queue.

Playlist page:

- New playlist is independent of the queue.
- Selecting an empty playlist shows a useful empty state; Play is disabled.
- Save current queue and Append queue remain explicit actions, not the only creation route.
- Rename and Delete live in an overflow menu rather than a dense row of equivalent buttons.
- Delete opens a dialog naming the playlist, explaining it does not delete purchased music, and clearly separating Cancel from Delete playlist. Cancel receives initial focus; Escape cancels.
- Do not promise Undo for remote deletion unless genuine restoration semantics are implemented.
- Network mutation errors preserve the view and inputs. Do not automatically retry ambiguous playlist writes: a server may have accepted the operation before the response was lost. Refresh authoritative state first, particularly when duplicates are legitimate.

Proposed protocol additions, with names used consistently by UI/backend/tests:

```json
{"cmd":"create_playlist","name":"Late nights"}
{"cmd":"add_to_playlist","id":"playlist-id","source":{"kind":"album","id":"album-id"}}
{"cmd":"add_to_playlist","id":"playlist-id","source":{"kind":"track","id":"track-id","albumId":"album-id"}}
{"cmd":"item_info","source":{"kind":"track","id":"track-id","albumId":"album-id"}}
```

Keep existing queue commands compatible while moving their implementation behind a small playlist/collection controller. Resolve album contents in the backend; never send arbitrary playback URLs from menus.

## 4. Scrolling, filters, and layout

- Genre options sort by contextual matching count descending, with alphabetical tie-breaks. Zero-match unselected options stay at the bottom and disabled; selected values remain removable.
- Artist options stay alphabetical/searchable. Tags remain a separate provenance-labelled facet.
- Speed slider controls base distance: 120–1200 pixels/notch, default 360, with a live numeric label. Debounce writes and save on release/keyboard completion rather than issuing a keyring/config operation for every pixel moved.
- Acceleration defaults on. Current tested curve increases rapid same-direction turns by 1.45 per burst step, capped at 5×; pause over 260 ms or reversal resets it. Slower turns decay the burst. Expose the on/off switch initially; put fine thresholds in config only if real feedback justifies them.
- Mouse events with both angle and pixel deltas use the angle for configured wheel travel. Pixel presence alone must not cause the mouse-speed control to be bypassed. Genuine touchpad behavior uses its own path.
- Cancel conflicting Flickable momentum when handling a mouse wheel event. Do not let layout restoration overwrite an active user scroll.
- Test scrolling over real album cards, near the bottom, after artwork/tag updates, and after returning from album details. A blank Flickable-only test is insufficient.
- Middle-click autoscroll remains supported and cancels on click, wheel, Escape, navigation, or focus loss.
- Compact widths must wrap controls rather than overlap, and destructive actions must not blend into transport buttons.

## 5. Configurable bar and mini-player

Replace the overloaded `bar_click` with `bar_left_action` and `bar_right_action`. Choices are `library`, `mini`, `play_pause`, `none`; defaults are library and mini. If mini is disabled, its action opens the full player. Preserve explicitly customized old settings during migration; migrate an untouched old default to the newly requested defaults. Keep middle-click play/pause. Opening the mini-player hides the full player; opening the full player closes the mini, while keeping the same playback session.

Display presets:

| Preset | Template | Example |
| --- | --- | --- |
| Compact, default | `{Artist} — {Song Name}` | Artist — Track |
| Track | `{Song Name}` | Track |
| Full | `{Artist} — {Album} — {Song Name}` | Artist — Record — Track |
| Record | `{Artist} — {Album}` | Artist — Record |
| Custom | User-edited template | `{Artist} / {Song Name}` |

Icon-only remains a separate display mode. Known placeholders are `{Artist}`, `{Album}`, `{Song Name}`, `{State}`. Render plain text through a small formatter, never eval or a template language capable of executing code. Validate unknown placeholders, cap length, and show a live preview before saving. Empty metadata should not leave duplicated separators. Idle text is Bandcamp; paused state stays discernible without misleading activity animation.

Marquee defaults to overflow-only while playing, with a short lead-in pause, a capped width, and a moderate speed (30 px/s). Do not resize the whole desktop bar as titles change. Stop animation when hidden, when text fits, when paused, or when reduced motion is enabled. Offer marquee/elide/static modes and advanced speed/width settings. The existing small icon is retained.

## 6. Theme behavior

The plugin already reads Omarchy `Color`/`Style` and standalone `Theme.qml` watches colors.toml. Complete the integration rather than replacing it:

- Route surfaces, text, muted text, borders, focus rings, selections, menus, sliders, dialogs, notifications, and destructive states through shared semantic colors.
- Use the host font and scale consistently. Theme changes should apply while the player is open.
- Remove fixed black autoscroll-marker text and mismatched native-control defaults.
- Provide `brand_icon_color = theme | bandcamp`, default theme for the public plugin; preserve the user's explicit existing blue choice during migration if recorded.
- Use one theme adapter for standalone mode and host-supplied palette properties for the plugin. Avoid two competing sources of truth.
- Verify a light theme, dark theme, and a low-contrast custom theme; ensure focus/selection remain visible.

## 7. Notifications and operation status

Current permanent `state.notice` is not a notification system. Introduce structured events and one notification presenter shared by large/mini views:

```json
{"event":"notification","notification":{"id":"opaque-id","level":"success","code":"settings_saved","message":"Settings saved","resourceId":"settings","action":null}}
```

- Success/info: dismiss automatically after 3 seconds.
- Warnings/actionable failures: toast for 8 seconds, then remain in a bounded 20-entry in-memory activity list accessible from the toolbar indicator until resolved/dismissed.
- Pause dismissal while the message is hovered or keyboard-focused. Always allow explicit dismissal.
- Settings saved events coalesce into one toast; repeated stream retries produce one evolving operation indicator, not a stack of identical warnings.
- Playback loading/buffering is operation state in the toolbar. Exhausted retries generate a failure with Retry / Skip actions; successful playback resolves the associated warning.
- Notification action identifiers are a small allowlist mapped to existing app commands. No arbitrary callbacks, shell commands, or server-supplied executable content.
- Authentication errors remain inline with login fields; playlist errors remain near the relevant operation as well as the global indicator.
- Optional desktop notifications for hidden-app failures default off.
- No secrets or signed URLs in text, diagnostic records, history, or exported bug reports.

## 8. MusicBrainz enrichment with visible outcomes

Settings offers consent plus Generate tags, Cancel, and Refresh expired metadata. The tag filter's empty state links to this same action.

Display a small operation summary:

- Last successful scan time
- Records checked / total
- Records with matched tags, cache hits, unmatched and ambiguous records
- Current activity, rate-limit pause, cancellation, or failure
- Completion result, e.g. “Tags added to 84 records; 12 had no confident match” and a Show tagged records action

Consent alone must not silently start repeated full scans. On startup, use cached approved metadata. Generate scans missing/expired entries; an explicit Refresh all explains that it rechecks matches and remains rate-limited. Unknown or ambiguous releases retain their original Bandcamp metadata.

Retain strict artist/title matching, one request per 1.05 seconds maximum, cancellation/consent checks, and Retry-After handling. Expose source and timestamp in record information. Successful scans should visibly increase available tag facets and their record counts; do not describe MusicBrainz tags as native Bandcamp tags.

Protocol:

```json
{"cmd":"generate_tags","mode":"missing"}
{"cmd":"generate_tags","mode":"expired"}
{"cmd":"generate_tags","mode":"all"}
{"cmd":"cancel_tags"}
```

State `metadataJob` contains status, total, processed, matched, cached, unmatched, ambiguous, lastCompletedAt, and safe message. Only one job runs at a time; switching accounts cancels obsolete delivery.

## 9. User-controlled caching

Default total disk budget: 256 MiB, adjustable 32–2048 MiB. Separate images, library metadata, and enrichment in the UI. Show usage, freshness and Clear controls; clearly distinguish cached data from saved playlists, listening history, and credentials.

| Data | Default policy |
| --- | --- |
| Collection and album details | Fresh for 15 minutes; show an explicitly stale cached snapshot immediately while refreshing. Offline cached browsing is supported, but streaming still needs network access. |
| Playlist lists/details | Fresh for 60 seconds; invalidate affected entries after every successful write. Refresh before ambiguous-write recovery. |
| Artwork | 30-day refresh policy, LRU eviction inside overall budget; protect currently referenced artwork until no view/player uses it. |
| Profile avatar | 7-day refresh policy. |
| MusicBrainz | 30-day positive matches, 7-day negative matches; small separate cap within the total budget. Keep existing limits initially unless real collection sizes show a need to expand. |
| Signed streaming URLs/audio | Never persisted. Generate a fresh URL on each playback/retry. |

Use a concrete `CacheStore` with a small SQLite index (stdlib) for namespace/key/account, timestamps, size and payload path, plus content files required by QML artwork URLs. No distributed cache, cache server, or generic storage framework. Migrate current image/metadata files lazily; migration failure must not erase the user's old cache.

Cache writes are atomic, account-scoped where appropriate, and serialized. Corrupt/missing entries become misses. Disabling disk caching leaves only memory caching. Clear images, Clear metadata, and Clear all cache do not sign out, delete playlists, or erase listening history. Account removal can explicitly remove that account's private cached library.

Cached library state must not falsely claim successful authentication. Show reconnecting/offline state separately from whether cached records exist.

## 10. Lean code boundaries

The audit found `bandcamp/backend.py` at 666 lines, `PlayerView.qml` at 314, plus view-specific settings logic. Extract only as needed:

| File | Responsibility |
| --- | --- |
| `bandcamp/backend.py` | Command dispatch, app lifecycle, coordination and state/event output. |
| `bandcamp/playlists.py` | Playlist operations, source resolution, authoritative refresh and mutation failure handling. |
| `bandcamp/library.py` | Collection data, sorting, account-scoped history and item information. |
| `bandcamp/cache.py` | Concrete cache budget/TTL/eviction and safe persistence. |
| `bandcamp/links.py` | Canonical Bandcamp link resolution and provenance. |
| `bandcamp/config.py` | Defaults, validation, schema migration and atomic updates. |
| `bandcamp/metadata.py` | MusicBrainz matching/cache adapter and progress reporting. |
| `PlayerView.qml` | Route shell and composition; no domain mutation logic. |
| `HomeView.qml`, `LibraryView.qml`, `AlbumView.qml`, `QueueView.qml` | Route-specific presentation; keep existing PlaylistView and SettingsView. |
| `ItemContextMenu.qml`, `PlaylistPicker.qml`, `ConfirmDialog.qml` | Reused interaction components. |
| `NotificationCenter.qml` | Bounded activity state, deduplication and expiration; one instance per Service. |
| `ToastHost.qml` | Notification presentation shared by large/mini views. |
| `NowPlayingText.qml`, `TextFormat.js` | Bounded marquee and safe placeholder formatting. |

Do not add an abstract provider interface for one API, generic event buses, dependency injection containers, a settings DSL, or a plugin-within-plugin architecture. Keep mpv, MPRIS, credentials and queue modules unless a concrete change needs them.

At every milestone review: remove duplicated behavior, identify hidden coupling, check task cancellation/account boundaries, assess whether each abstraction has a real caller, inspect dependencies, and delete obsolete code. Prefer small behavior-preserving extractions and tests around user-visible outcomes, not line-count targets.

## 11. Public repository, CI/CD and upstream distribution

Verified 2026-09-24: https://github.com/killgallic/omarchy-bandcamp is public and empty; it has no default branch yet. The local project has no Git remote configured. Nothing has been pushed by this plan.

### Repository package

- Choose public plugin ID `killgallic.bandcamp` before first public release. Provide a one-time local migration from `its.bandcamp`, preserving bar placement and XDG settings/keyring/history; do not create two competing MPRIS players. Keep the existing app storage namespace stable.
- Keep manifest.json at repo root and version synchronized with pyproject.toml, uv.lock and changelog.
- Add README install/update/uninstall/setup/troubleshooting, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, `THIRD_PARTY_NOTICES.md`, and `.editorconfig`.
- Keep MIT licensing with accurate attribution; document that Bandcamp's name/logo are third-party branding and the plugin is unofficial.
- Add `.github/PULL_REQUEST_TEMPLATE.md`, bug and feature issue forms, security-report routing, `.github/CODEOWNERS` with the actual maintainer, and dependency update configuration.
- PR template asks for user-visible before/after, tests, screenshots for UI changes, and account/network/cache changes. Keep it short.
- Audit tracked files and history for credentials, personal collection fixtures, private screenshots, absolute home paths and accidentally retained diagnostic output. Use synthetic fixtures and a demo mode for public screenshots.
- Do not include the unrelated Waxlog investigation or any credential-bearing evidence in this repository.

### Installation reality

Omarchy plugin installation clones/validates a repo; it does not execute dependency-install hooks. A fresh clone currently lacks `.venv`, so first-install setup is a release blocker.

Add explicit `bin/setup` using the locked uv environment and a friendly dependency/setup state in the UI. The README supplies the exact command after `omarchy plugin add`. Do not silently run sudo, install packages, or fetch executable code as a side effect of loading a bar widget. Test installation without the developer's existing venv/cache.

### CI: `.github/workflows/ci.yml`

Run on pull_request and pushes to main. Use read-only default permissions, timeouts, cancellation of superseded runs, and pinned action SHAs. Fork PR tests never receive account secrets. Do not execute fork code through pull_request_target.

Required checks:

1. **python:** locked dependency install, Python minimum and supported current version, unit tests, safe protocol/config validation.
2. **playback:** isolated dbus-run-session, mpv null output, generated audio fixtures, EOF transitions/retry cancellation/MPRIS. No live Bandcamp credentials.
3. **qml:** Arch-compatible Qt environment with the minimum supported Qt version documented; offscreen QtTest, scoped linting, and screenshot artifacts on UI failures. The current UI uses Qt 6.8+ features such as Popup.Item; test the declared floor and the Omarchy-compatible rolling version rather than assuming Ubuntu's bundled Qt suffices.
4. **package:** manifest validation, version consistency, clean archive contents, executable launchers, setup from a clean directory, and no secret/runtime artifacts.

CI script entry points: `tests/run-python`, `tests/run-qml`, `tests/check-package`. Local and CI commands use the same entry points. Clear XDG paths and use temporary homes in tests so they cannot touch real credentials/cache. QML fixture tests run without Omarchy; the qs.Commons/qs.Ui host integration gets a documented real Omarchy smoke check and an isolated supported-host test where practical. Do not pretend generic Qt tests validate every host capability.

### Releases: `.github/workflows/release.yml`

- Trigger on an explicitly created semantic version tag or manual dispatch of a reviewed tag; never auto-publish every merge.
- Verify tag/version agreement, run required checks, build source archive and SHA256 checksums from an explicit file allowlist.
- Produce a draft GitHub Release with installation instructions and migration notes. Only the release job gets contents:write; pin its dependencies/actions too.
- Optional provenance attestations may be added when they bind the actual release artifact; they do not replace testing or a marketplace review.
- No automatic desktop installation or upstream submission from CI. The plugin is a source distribution, so a PyPI package/container registry is unnecessary for the first release.

After first push, configure main as default, require passing checks/PRs, prevent force-push/deletion, enable private vulnerability reporting and secret scanning where available. A solo maintainer must not be blocked by a rule requiring their own unavailable second approval; CODEOWNERS can request review without a self-approval deadlock.

### Upstream path

The current marketplace asks for one public repository with manifest, README and license, and an exact-commit scan plus explicit maintainer approval. Prepare a submission packet containing repo URL, tested SHA, compatibility/dependencies, category/tags, synthetic screenshots, account/data/network behavior, install/update/uninstall instructions, known limitations, and test results.

Treat registry development/design proposals separately from the currently documented submission path. Recheck requirements at submission time. Prepare a core Omarchy PR only if maintainers identify an actual core change; listing this plugin need not add its implementation to the Omarchy source tree.

Publishing the first public code/release and sending the upstream submission are explicit final actions after the result is reviewable. The user's request is to plan this work, and their intent to publish was future-facing.

## 12. Implementation sequence and acceptance gates

### Milestone 0 — Preserve and ship the pending interaction fixes

Files: ScrollAssist.qml, PlayerView.qml, PlaylistView.qml, SettingsView.qml, bandcamp/config.py, tests/qml/tst_scroll.qml, tests/qml/tst_player.qml.

- [ ] Commit genre frequency ordering and exponential scrolling separately from this larger plan.
- [ ] Run the existing QtTest suite and config tests; confirm mixed angle/pixel input, fast bursts, pause/reversal, real album cards, and near-bottom restoration.
- [ ] Deploy to the local plugin and reopen it; verify the new process/window. Record that this is a targeted fix, not completion of the roadmap.

### Milestone 1 — Settings migration, notifications and lifecycle

Files: bandcamp/config.py, bandcamp/backend.py, Service.qml, SettingsView.qml; new NotificationCenter.qml, ToastHost.qml; tests/test_config.py, tests/test_accounts_and_library.py, tests/qml/tst_notifications.qml.

- [ ] Add config schema version and deterministic legacy migration tests before changing defaults.
- [ ] Define independent bar actions and scrolling slider values in the validated schema, preserving explicit custom choices.
- [ ] Replace permanent success notices with structured notifications; retain operation-specific state separately.
- [ ] Implement timeout/deduplication/action dispatch and bounded history.
- [ ] Add tests: Settings saved disappears; burst saves coalesce; hover pauses expiration; failed playback retains actionable status; success clears it; sign-out prevents stale account messages.
- [ ] Verify sliders write on completion, invalid configs recover without deleting the original file, and saved settings survive restart.
- [ ] Review abstractions and commit this milestone.

### Milestone 2 — Context menus and useful playlists

Files: bandcamp/api.py, bandcamp/backend.py, new bandcamp/playlists.py; PlayerView.qml, TrackRow.qml, PlaylistView.qml; new ItemContextMenu.qml, PlaylistPicker.qml, ConfirmDialog.qml; tests/test_playlists.py, tests/test_accounts_and_library.py, tests/qml/tst_context_actions.qml.

- [ ] Add failing API/backend tests for empty creation and adding an explicit album/track to a selected playlist, independently of the queue.
- [ ] Implement the protocol in section 3 and preserve duplicate track order intentionally.
- [ ] Implement shared mouse/keyboard context menus and the playlist picker.
- [ ] Replace crowded destructive buttons with the overflow/dialog flow.
- [ ] Test opening a menu then changing playback, empty playlists, queue/playlist scope separation, inaccessible/deleted playlists, mutation failure, and cancellation without a write.
- [ ] Validate actual Bandcamp empty-playlist behavior using an explicitly designated disposable test playlist/account; do not mutate unrelated existing playlists. If unsupported, report the capability and design a clearly local draft rather than silently pretending sync succeeded.
- [ ] Review abstractions and commit this milestone.

### Milestone 3 — Navigation, Home and canonical links

Files: PlayerView.qml, MiniPlayer.qml, Service.qml, bandcamp/api.py; new HomeView.qml, LibraryView.qml, AlbumView.qml, QueueView.qml, bandcamp/library.py, bandcamp/links.py; tests/qml/tst_navigation.qml, tests/test_links.py.

- [ ] Perform the canonical-link capability check and implement validated mappings with provenance/fallbacks.
- [ ] Extract route views without changing playback ownership or queue semantics.
- [ ] Add the Home sections and profile/wordmark navigation; remove the Collection tab.
- [ ] Add album/artist external actions and item-info presentation.
- [ ] Test Home from every route/mini, back preserving filters/scroll, no fabricated URLs, unavailable links, offline cached data, and unchanged music playback during navigation.
- [ ] Review small-screen layouts and abstraction boundaries, then commit.

### Milestone 4 — Bar presentation and full theme consistency

Files: BarWidget.qml, Panel.qml, MiniPlayer.qml, Theme.qml, SettingsView.qml, ActionButton.qml, ScrollAssist.qml; new NowPlayingText.qml, TextFormat.js; tests/qml/tst_bar_format.qml, tests/qml/tst_theme.qml.

- [ ] Add tests for preset/custom substitution, unknown fields, empty metadata, long/untrusted text and bounded widths.
- [ ] Implement independent click actions, preset previews, marquee/elide modes and reduced motion.
- [ ] Audit every view/control for semantic colors/fonts, including destructive actions and popup focus states.
- [ ] Test hidden/paused marquee shutdown, disabled mini fallback, vertical bar, multiple monitors and theme changes while playing.
- [ ] Check dark/light/custom-theme screenshots and real Omarchy behavior, then review and commit.

### Milestone 5 — Controlled cache and visible enrichment

Files: new bandcamp/cache.py; bandcamp/metadata.py, bandcamp/profile.py, bandcamp/library.py, bandcamp/playlists.py, bandcamp/backend.py, SettingsView.qml, FilterDropdown.qml; tests/test_cache.py, tests/test_metadata.py, tests/qml/tst_metadata_status.qml.

- [ ] Add cache tests for account separation, atomic replacement, TTL, LRU budget, corruption, protected artwork, clear operations, and disabled disk writes.
- [ ] Implement the concrete cache store and lazy migration; expose usage, budgets and category clear controls.
- [ ] Add generate/cancel job protocol and progress/counters; load cache separately from network generation.
- [ ] Add tests for 429 cooldown with cache hits, cancellation/opt-out/account switches, no-confidence matches, no repeated auto-scan, and completion creating visible tag options.
- [ ] Verify clearing caches never deletes playlists/history/credentials; confirm offline state does not fake authentication.
- [ ] Review actual resource use and avoid abstraction creep; commit.

### Milestone 6 — Public distribution and upstream readiness

Files: manifest.json, bin/setup, bin/backend, README.md, pyproject.toml, uv.lock; new CONTRIBUTING.md, SECURITY.md, CHANGELOG.md, THIRD_PARTY_NOTICES.md, .editorconfig, .github/workflows/ci.yml, .github/workflows/release.yml, .github/PULL_REQUEST_TEMPLATE.md, .github/ISSUE_TEMPLATE/bug.yml, .github/ISSUE_TEMPLATE/feature.yml, .github/ISSUE_TEMPLATE/config.yml, .github/CODEOWNERS, .github/dependabot.yml, tests/run-python, tests/run-qml, tests/check-package, demo/shell.qml, docs/upstream-submission.md.

- [ ] Audit history/artifacts and prepare the public identity migration.
- [ ] Make fresh-clone setup, install, upgrade and uninstall work without the development checkout.
- [ ] Add test scripts, synthetic demo data, CI and draft-release workflow; pin resolved action revisions during implementation and record their provenance.
- [ ] Add contribution/security templates and release/migration documentation.
- [ ] Run packaging locally, inspect the archive, validate a clean user install, and rehearse rollback to the previous release.
- [ ] Prepare remote/main/ruleset settings and the first release as concrete reviewable artifacts. Do not push/publish merely to make the plan look complete.
- [ ] After authorized publication, run hosted CI, verify release assets/checksums, and prepare the current marketplace submission with the tested exact SHA.
- [ ] Final review: code boundaries, config compatibility, theme/UX, privacy, installability, known limitations, and no accidentally promised live validations.

## 13. Verification commands and release acceptance

Current baseline commands:

```sh
uv sync --frozen --offline
dbus-run-session -- env BANDCAMP_INTEGRATION=1 .venv/bin/python -m unittest discover -s tests -v
QT_QPA_PLATFORM=offscreen QT_QUICK_CONTROLS_STYLE=Basic QT_QPA_PLATFORMTHEME=generic /usr/lib/qt6/bin/qmltestrunner -input tests/qml
git diff --check
```

Use networked uv sync only when locked dependencies are not cached. Desktop sockets/D-Bus may require running outside an execution sandbox. Keep real-account probes opt-in, read-only by default, separate from CI, and redact outputs.

Before a public beta: all required checks pass; empty-playlist support has been established; playback/auto-next/retry cancellation work; new-install setup works; context actions and notification lifetimes are verified; cache limits and opt-out are enforced; at least two Omarchy themes and a narrow layout have been checked; installation, upgrade, removal and rollback have been rehearsed. Record limitations rather than masking absent Bandcamp metadata.

## Sources checked for this plan

- Repository state: `gh repo view killgallic/omarchy-bandcamp --json nameWithOwner,url,visibility,defaultBranchRef,isEmpty,description` on 2026-09-24.
- Omarchy plugin source/install contract: https://github.com/omacom/omarchy/blob/quattro/shell/README.md
- Current marketplace process: https://github.com/omacom/omarchy-plugin-marketplace
- Maintained plugin example: https://github.com/basecamp/omarchy-basecamp-plugin
- GitHub fork-workflow security: https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target
- Subsonic playlist contracts: https://www.subsonic.org/pages/api.jsp
- Qt wheel semantics: https://doc.qt.io/qt-6/qml-qtquick-wheelhandler.html
- MusicBrainz API/rate requirements: https://musicbrainz.org/doc/MusicBrainz_API
