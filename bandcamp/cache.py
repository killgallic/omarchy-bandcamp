"""Bound and clear only the files owned by the player's cache."""
import os
import threading
from pathlib import Path

class Cache:
    _lock = threading.RLock()
    def __init__(self, root=None):
        self.root = Path(root) if root else Path(os.environ.get('XDG_CACHE_HOME', Path.home()/'.cache'))/'omarchy-bandcamp'

    def files(self, category):
        if category == 'artwork': return list(self.root.glob('[0-9a-f]' * 64 + '.img'))
        if category == 'profile': return list(self.root.glob('profile-' + '[0-9a-f]' * 64 + '.img'))
        if category == 'metadata': return [self.root/'metadata.json']
        if category == 'collection': return list(self.root.glob('library-'+'[0-9a-f]'*64+'.json')) + list(self.root.glob('links-'+'[0-9a-f]'*64+'.json'))
        raise ValueError('Unknown cache category.')

    def stats(self):
        with self._lock:
            sizes = {kind + '_bytes': sum(p.stat().st_size for p in self.files(kind) if p.is_file()) for kind in ('artwork','profile','metadata','collection')}
            sizes['total_bytes'] = sum(sizes.values())
            return sizes

    def clear(self, category):
        with self._lock:
            for path in self.files(category):
                path.unlink(missing_ok=True)

    def prune_artwork(self, max_bytes):
        with self._lock:
            files = sorted((p for p in self.files('artwork') if p.is_file()), key=lambda p:p.stat().st_mtime, reverse=True)
            used = 0
            for path in files:
                size = path.stat().st_size
                if used + size > max_bytes: path.unlink(missing_ok=True)
                else: used += size

    def prune_total(self, max_bytes):
        with self._lock:
            reserved = sum(self.stats()[kind + '_bytes'] for kind in ('profile','metadata','collection'))
            self.prune_artwork(max(0, max_bytes - reserved))
            remaining = self.stats()['total_bytes']
            if remaining <= max_bytes: return
            for kind in ('collection','profile','metadata'):
                files = sorted((p for p in self.files(kind) if p.is_file()), key=lambda p:p.stat().st_mtime)
                for path in files:
                    if remaining <= max_bytes: return
                    size = path.stat().st_size
                    path.unlink(missing_ok=True)
                    remaining -= size
