"""Validated, non-secret preferences shared by the native player views."""
import json
import os
from pathlib import Path
import tempfile
from urllib.parse import urlsplit

DEFAULTS = dict(remember_login=True, bar_display='icon_title', bar_click='toggle_library',
                mini_player_enabled=True, large_player_width=1000, large_player_height=760,
                show_discover_links=True, stream_retries=2, metadata_enrichment=False, profile_url='', mini_player_width=460, mini_show_artwork=True, wheel_scroll_pixels=360)

class Config:
    def __init__(self, path=None):
        self.path = Path(path) if path else Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'omarchy-bandcamp/config.json'
        self.values = DEFAULTS.copy()
        self.notice = ''
        try:
            if self.path.exists():
                self.values.update(self.validate(json.loads(self.path.read_text())))
            else:
                self.update({})
        except (OSError, ValueError, TypeError):
            self.notice = 'Could not read the player configuration. Defaults are active; save settings to repair it.'

    @staticmethod
    def validate(values):
        if not isinstance(values, dict) or set(values) - set(DEFAULTS):
            raise ValueError('Unknown configuration option.')
        enums = {'bar_display': ('icon', 'title', 'icon_title'), 'bar_click': ('mini', 'library', 'toggle_library')}
        ranges = {'large_player_width': (660, 3000), 'large_player_height': (620, 2000), 'stream_retries': (0, 5), 'mini_player_width': (440, 900), 'wheel_scroll_pixels': (120, 1200)}
        for key, value in values.items():
            if key == 'profile_url':
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
