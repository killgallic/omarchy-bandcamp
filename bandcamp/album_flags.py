"""Account-scoped, local favourite and hidden album IDs."""

import hashlib
import json
import os
from pathlib import Path


def path_for(username):
    name = hashlib.sha256(username.encode()).hexdigest() + '-albums.json'
    return Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'omarchy-bandcamp' / name


def load(username):
    try:
        saved = json.loads(path_for(username).read_text())
        if not isinstance(saved, dict):
            return {'favourites': [], 'hidden': []}
        result = {}
        for key in ('favourites', 'hidden'):
            values = saved.get(key, [])
            result[key] = list(dict.fromkeys(str(item) for item in values if isinstance(item, (str, int)))) if isinstance(values, list) else []
        return result
    except (OSError, ValueError, TypeError):
        return {'favourites': [], 'hidden': []}


def save(username, favourites, hidden):
    path = path_for(username)
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps({'favourites': favourites, 'hidden': hidden}))
    temporary.chmod(0o600)
    temporary.replace(path)
