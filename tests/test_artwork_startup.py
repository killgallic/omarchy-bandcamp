"""Cached covers should be ready with the first collection, without repeat patches."""
import asyncio
import hashlib
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from bandcamp.backend import App


class FakeAPI:
    def __init__(self, username, password):
        self.username = username
        self.fetches = 0
    def albums(self):
        return [{'id': 'album', 'name': 'Cached album', 'artist': 'Artist', 'coverArt': 'cover'}]
    def playlists(self):
        return []
    def fetch(self, endpoint, params, limit):
        self.fetches += 1
        return b'\xff\xd8new-image'


class ArtworkStartupTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.environment = patch.dict(os.environ, {'XDG_CONFIG_HOME': self.directory.name, 'XDG_CACHE_HOME': self.directory.name,
                                                    'XDG_STATE_HOME': self.directory.name})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.events = []
        self.app = App(emit=self.events.append)
        cache = Path(self.directory.name) / 'omarchy-bandcamp'
        cache.mkdir(exist_ok=True)
        self.cover = cache / (hashlib.sha256(b'listener:cover').hexdigest() + '.img')
        self.cover.write_bytes(b'\xff\xd8cached-image')

    async def asyncTearDown(self):
        await self.app.close()

    async def test_cached_art_is_in_first_connected_collection(self):
        with patch('bandcamp.backend.BandcampAPI', FakeAPI):
            await self.app.handle({'cmd': 'login', 'username': 'listener', 'password': 'test'})
        connected = next(e['state'] for e in self.events if e.get('event') == 'state' and e['state'].get('connected'))
        self.assertEqual(connected['albums'][0]['art'], self.cover.as_uri())

    async def test_cached_art_does_not_reemit_the_collection(self):
        self.app.state['albums'] = [{'id': 'album', 'coverArt': 'cover', 'art': self.cover.as_uri()}]
        self.app.generation = 1
        await self.app.load_artwork(FakeAPI('listener', 'test'), 1)
        self.assertEqual([e for e in self.events if e.get('event') == 'state' and 'albums' in e['state']], [])

    async def test_missing_artwork_still_downloads(self):
        api = FakeAPI('listener', 'test')
        self.app.state['albums'] = [{'id': 'album', 'coverArt': 'missing'}]
        self.app.generation = 1
        await self.app.load_artwork(api, 1)
        self.assertEqual(api.fetches, 1)
        self.assertTrue(self.app.state['albums'][0]['art'].startswith('file:'))
        self.assertTrue(Path(self.app.state['albums'][0]['art'][7:]).is_file())
