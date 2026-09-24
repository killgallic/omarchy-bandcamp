import tempfile
from pathlib import Path
import unittest
from bandcamp.config import Config

class ConfigTests(unittest.TestCase):
    def test_roundtrip_and_defaults(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            config = Config(path)
            self.assertTrue(config.values['remember_login'])
            config.update({'bar_display': 'icon', 'mini_player_enabled': False})
            self.assertEqual(Config(path).values['bar_display'], 'icon')
            self.assertFalse(Config(path).values['mini_player_enabled'])
            self.assertNotIn('password', path.read_text())

    def test_invalid_changes_do_not_overwrite_valid_file(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Config(Path(directory) / 'config.json')
            config.update({'bar_display': 'title'})
            for change in ({'password': 'secret'}, {'stream_retries': -1}, {'remember_login': 'false'}, {'bar_display': 'invalid'}):
                with self.assertRaises(ValueError):
                    config.update(change)
            self.assertEqual(config.values['bar_display'], 'title')

    def test_corrupt_file_has_recoverable_notice(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            path.write_text('{bad')
            config = Config(path)
            self.assertTrue(config.notice)
            self.assertEqual(path.read_text(), '{bad')

    def test_legacy_click_migration_preserves_custom_choice(self):
        import json
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'config.json'
            for old, expected in [('toggle_library', 'library'), ('mini', 'mini'), ('library', 'library')]:
                path.write_text(json.dumps({'bar_click': old}))
                config = Config(path)
                self.assertEqual(config.values.get('bar_left_action'), expected)
                self.assertEqual(config.values.get('bar_right_action'), 'mini')
                self.assertEqual(config.values.get('schema_version'), 1)

    def test_bar_preferences_validate_before_write(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Config(Path(directory) / 'config.json')
            config.update({'bar_format': '{Artist} / {Song Name}', 'bar_right_action': 'none'})
            for change in ({'bar_format': '{Password}'}, {'bar_format': 'x' * 241}, {'bar_width': 10}, {'schema_version': 2}):
                with self.assertRaises(ValueError):
                    config.update(change)
            self.assertEqual(Config(config.path).values['bar_right_action'], 'none')
