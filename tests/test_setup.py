"""A public install must leave the plugin tree valid for Omarchy updates."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class SetupTests(unittest.TestCase):
    def test_installer_keeps_runtime_outside_plugin_and_backend_uses_it(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            project = base / 'plugin'
            for relative in ('bin/setup', 'bin/backend', 'bin/omarchy-bandcamp',
                             'share/applications/omarchy-bandcamp.desktop', 'assets/bandcamp.svg'):
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, target)
            home = base / 'home'
            home.mkdir()
            commands = base / 'commands'
            commands.mkdir()
            uv_log = base / 'uv-environment'
            (commands / 'uv').write_text('''#!/bin/sh
printf '%s\\n' "${UV_PROJECT_ENVIRONMENT:-}" > "$SETUP_TEST_UV_LOG"
target="${UV_PROJECT_ENVIRONMENT:-.venv}"
mkdir -p "$target/bin"
printf '#!/bin/sh\\nprintf "backend launched\\n"\\n' > "$target/bin/python"
chmod +x "$target/bin/python"
''')
            (commands / 'uv').chmod(0o755)
            (commands / 'mpv').write_text('#!/bin/sh\nexit 0\n')
            (commands / 'mpv').chmod(0o755)
            data = home / 'data'
            env = {**os.environ, 'HOME': str(home), 'XDG_DATA_HOME': str(data),
                   'PATH': str(commands) + os.pathsep + os.environ['PATH'],
                   'SETUP_TEST_UV_LOG': str(uv_log)}
            subprocess.run([str(project / 'bin/setup')], env=env, check=True, capture_output=True, text=True)
            runtime = data / 'omarchy-bandcamp' / 'venv'
            self.assertEqual(uv_log.read_text().strip(), str(runtime))
            self.assertFalse((project / '.venv').exists())
            self.assertTrue((data / 'applications/omarchy-bandcamp.desktop').is_file())
            self.assertTrue((data / 'icons/hicolor/scalable/apps/omarchy-bandcamp.svg').is_symlink())
            backend = subprocess.run([str(project / 'bin/backend')], env=env, check=True, capture_output=True, text=True)
            self.assertEqual(backend.stdout.strip(), 'backend launched')

    def test_uninstall_removes_only_app_integration_and_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            project = base / 'plugin'
            for relative in ('bin/uninstall', 'bin/omarchy-bandcamp',
                             'share/applications/omarchy-bandcamp.desktop', 'assets/bandcamp.svg'):
                target = project / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                if (ROOT / relative).exists():
                    shutil.copy2(ROOT / relative, target)
            home = base / 'home'
            data = home / 'data'
            command = home / '.local/bin/omarchy-bandcamp'
            desktop = data / 'applications/omarchy-bandcamp.desktop'
            icon = data / 'icons/hicolor/scalable/apps/omarchy-bandcamp.svg'
            runtime = data / 'omarchy-bandcamp/venv'
            for path in (command, desktop, icon, runtime / 'bin/python'):
                path.parent.mkdir(parents=True, exist_ok=True)
            command.symlink_to(project / 'bin/omarchy-bandcamp')
            shutil.copy2(project / 'share/applications/omarchy-bandcamp.desktop', desktop)
            icon.symlink_to(project / 'assets/bandcamp.svg')
            (runtime / 'pyvenv.cfg').write_text('home = /usr/bin\n')
            (runtime / 'bin/python').write_text('stub')
            settings = home / '.config/omarchy-bandcamp/config.json'
            settings.parent.mkdir(parents=True)
            settings.write_text('{}')
            commands = base / 'commands'
            commands.mkdir()
            (commands / 'cmp').write_text('#!/bin/sh\nexit 127\n')
            (commands / 'cmp').chmod(0o755)
            env = {**os.environ, 'HOME': str(home), 'XDG_DATA_HOME': str(data),
                   'PATH': str(commands) + os.pathsep + os.environ['PATH']}
            subprocess.run([str(project / 'bin/uninstall')], env=env, check=True, capture_output=True, text=True)
            self.assertFalse(command.exists())
            self.assertFalse(desktop.exists())
            self.assertFalse(icon.exists())
            self.assertFalse(runtime.exists())
            self.assertTrue(settings.exists())
            desktop.write_text('[Desktop Entry]\nName=My custom launcher\n')
            subprocess.run([str(project / 'bin/uninstall')], env=env, check=True, capture_output=True, text=True)
            self.assertTrue(desktop.exists())
