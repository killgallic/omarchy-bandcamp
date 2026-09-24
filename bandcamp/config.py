"""Validated, non-secret preferences shared by the native player views."""
import json
import os
import re
from pathlib import Path
import tempfile
from urllib.parse import urlsplit

DEFAULTS = dict(schema_version=1, bar_left_action='library', bar_right_action='mini',
                bar_preset='compact', bar_format='{Artist} — {Song Name}', bar_text_mode='marquee',
                bar_width=240, bar_scroll_speed=30, bar_compact_when_idle=True, reduced_motion=False, cache_budget_mb=256, cache_ttl_minutes=15,
                remember_login=True, confirm_quit=True, bar_display='icon_title', bar_click='toggle_library',
                mini_player_enabled=True, large_player_width=1000, large_player_height=760,
                show_discover_links=True, stream_retries=2, metadata_enrichment=False, profile_url='', mini_player_width=460, mini_show_artwork=True, wheel_scroll_pixels=360, wheel_acceleration=True)

class Config:
    def __init__(self, path=None):
        self.path = Path(path) if path else Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'omarchy-bandcamp/config.json'
        self.values = DEFAULTS.copy()
        self.notice = ''
        try:
            if self.path.exists():
                loaded = json.loads(self.path.read_text())
                if isinstance(loaded, dict) and 'schema_version' not in loaded:
                    loaded = dict(loaded)
                    loaded.setdefault('bar_left_action', 'mini' if loaded.get('bar_click') == 'mini' else 'library')
                    loaded.setdefault('bar_right_action', 'mini')
                    loaded['schema_version'] = 1
                self.values.update(self.validate(loaded))
            else:
                self.update({})
        except (OSError, ValueError, TypeError):
            self.notice = 'Could not read the player configuration. Defaults are active; save settings to repair it.'

    @staticmethod
    def validate(values):
        if not isinstance(values, dict) or set(values) - set(DEFAULTS):
            raise ValueError('Unknown configuration option.')
        enums = {'bar_left_action': ('library', 'mini', 'play_pause', 'none'),
                 'bar_right_action': ('library', 'mini', 'play_pause', 'none'),
                 'bar_preset': ('compact', 'track', 'full', 'record', 'custom'),
                 'bar_text_mode': ('marquee', 'elide', 'static'),
                 'bar_display': ('icon', 'title', 'icon_title'), 'bar_click': ('mini', 'library', 'toggle_library')}
        ranges = {'schema_version': (1, 1), 'bar_width': (100, 600), 'bar_scroll_speed': (10, 100), 'cache_budget_mb': (32, 2048), 'cache_ttl_minutes': (1, 1440), 'large_player_width': (660, 3000), 'large_player_height': (620, 2000), 'stream_retries': (0, 5), 'mini_player_width': (440, 900), 'wheel_scroll_pixels': (120, 1200)}
        for key, value in values.items():
            if key == 'bar_format':
                valid = isinstance(value, str) and 0 < len(value) <= 240 and not re.search(r'[\x00-\x1f]', value)
                if valid:
                    remainder = re.sub(r'\{(?:Artist|Album|Song Name|State)\}', '', value)
                    valid = '{' not in remainder and '}' not in remainder
            elif key == 'profile_url':
                parsed = urlsplit(value) if isinstance(value, str) else None
                valid = isinstance(value, str) and (not value or (parsed.scheme == 'https' and parsed.netloc == 'bandcamp.com' and len(parsed.path.strip('/').split('/')) == 1 and bool(parsed.path.strip('/')) and not parsed.query and not parsed.fragment))
            elif key in enums:
                valid = value in enums[key]
            elif key in ranges:
                valid = type(value) is int and ranges[key][0] <= value <= ranges[key][1]
            else:
                valid = type(value) is bool
            if not valid:
                raise ValueError('Invalid configuration value.')
        return values

    def update(self, values):
        updated = {**self.values, **self.validate(values)}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode='w', dir=self.path.parent, delete=False) as output:
            temporary = Path(output.name)
            try:
                json.dump(updated, output, indent=2)
                output.write('\n')
                output.flush()
                os.fsync(output.fileno())
                temporary.replace(self.path)
            finally:
                temporary.unlink(missing_ok=True)
        self.values = updated
        self.notice = ''
