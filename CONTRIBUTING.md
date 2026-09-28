# Contributing

Bug reports, design feedback, documentation and code are welcome. Omarchy Bandcamp is independent of Bandcamp and uses its Subsonic beta.

## Start locally

Use an Omarchy 4 system for manual UI checks. Install `uv`, `mpv`, `libsecret`, and the Qt 6 QML test runner (`qt6-declarative` on Arch). Clone the repository and run:

```bash
uv sync --frozen
tests/run-python
tests/run-qml
tests/check-package
```

`uv sync` creates `.venv` for development. Omarchy refuses symlinks within a plugin directory, so do not register a development checkout containing `.venv` as a public plugin. `tests/check-package` validates a clean tracked source archive, which is what Omarchy receives. To run locally, use `bin/setup`; it installs the runtime outside the repository, then `bin/omarchy-bandcamp --standalone` launches the standalone shell. To exercise the plugin, use a clean Omarchy plugin checkout.

Tests use synthetic fixtures and a silent mpv instance. They do not need a Bandcamp account. A real login is needed for a manual streaming check because the upstream beta can change independently of this repository.

## Where things live

| Area | Files |
| --- | --- |
| Omarchy entry points and UI | `manifest.json`, root `*.qml`, `qml/` |
| Playback, Bandcamp protocol and state | `bandcamp_player/` |
| Launcher, setup and removal | `bin/`, `share/applications/` |
| Python and QML tests | `tests/`, `tests/qml/` |
| Release automation | `.github/workflows/`, `tests/check-package` |

Keep changes focused. Extend existing state and UI patterns before adding another abstraction or dependency. Keep network requests outside the render path and preserve bounded retries and caches. Credentials belong only in memory or Secret Service; never put them in screenshots, fixtures, logs or config. Use synthetic records for examples and tests. Avoid changing a user's real playlists in automated checks.

## Propose a change

Open an issue for a sizeable feature so its behavior and Omarchy fit can be discussed. For a bug, include Omarchy version, installation method, reproduction steps, expected and actual behavior, and relevant redacted logs. A small PR can go straight to review. Explain the user-visible change and run the commands above. For UI changes, include a screenshot using synthetic data or describe manual checks. Update README and CHANGELOG when behavior or install steps change.

CI runs Python, QML, and package checks on Arch. Maintainers prepare releases from reviewed semantic-version tags; the release workflow creates a draft for final review. Do not attach account tokens or private collection exports to issues or PRs. Follow [SECURITY.md](SECURITY.md) for a suspected credential leak or other security issue.
