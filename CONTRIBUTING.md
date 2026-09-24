# Contributing

Please open an issue before a large behavioral change. Keep authentication secrets, signed stream URLs, screenshots of private collections, and unrelated security reports out of issues and commits.

Run `bin/setup`, `tests/run-python`, `tests/run-qml`, and `tests/check-package` before a PR. Use synthetic account fixtures. UI changes should include an image of synthetic demo data and keyboard/mouse verification where applicable. The current Omarchy shell host needs a manual integration smoke check in addition to QtTest.
