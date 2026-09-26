import os
import tempfile
import unittest
from unittest.mock import patch

from bandcamp.backend import App
from bandcamp import album_flags


class AlbumFlagTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'XDG_STATE_HOME': self.directory.name, 'XDG_CONFIG_HOME': self.directory.name})
        self.env.start()
        self.app = App(emit=lambda event: None)
        self.app.api = type('API', (), {'username': 'fan-one'})()
        self.app.emit(albums=[{'id': 'a', 'name': 'A'}, {'id': 'b', 'name': 'B'}, {'id': 'c', 'name': 'C'}])

    async def asyncTearDown(self):
        await self.app.close()
        self.env.stop()
        self.directory.cleanup()

    async def test_favourite_and_hidden_are_reversible_and_home_excludes_hidden(self):
        await self.app.handle({'cmd': 'toggle_favourite', 'id': 'a'})
        await self.app.handle({'cmd': 'toggle_favourite', 'id': 'b'})
        self.assertEqual([a['id'] for a in self.app.state['homeFavourites']], ['a', 'b'])
        await self.app.handle({'cmd': 'toggle_hidden', 'id': 'a'})
        self.assertEqual(self.app.state['favouriteIds'], ['a', 'b'])
        self.assertEqual(self.app.state['hiddenIds'], ['a'])
        self.assertEqual([a['id'] for a in self.app.state['homeFavourites']], ['b'])
        self.assertNotIn('a', [a['id'] for a in self.app.state['homeRecent']])
        self.assertNotIn('a', [a['id'] for a in self.app.state['homeRediscover']])
        await self.app.handle({'cmd': 'toggle_hidden', 'id': 'a'})
        self.assertEqual(self.app.state['hiddenIds'], [])
        self.assertEqual([a['id'] for a in self.app.state['homeFavourites']], ['a', 'b'])
        await self.app.handle({'cmd': 'toggle_favourite', 'id': 'a'})
        self.assertEqual(self.app.state['favouriteIds'], ['b'])

    async def test_flags_survive_restart_and_are_scoped_to_account(self):
        await self.app.handle({'cmd': 'toggle_favourite', 'id': 'a'})
        await self.app.handle({'cmd': 'toggle_hidden', 'id': 'b'})
        second = App(emit=lambda event: None)
        try:
            second.api = type('API', (), {'username': 'fan-one'})()
            second.emit(albums=list(self.app.state['albums']))
            second.load_album_flags()
            self.assertEqual(second.state['favouriteIds'], ['a'])
            self.assertEqual(second.state['hiddenIds'], ['b'])
            second.api = type('API', (), {'username': 'fan-two'})()
            second.load_album_flags()
            self.assertEqual(second.state['favouriteIds'], [])
            self.assertEqual(second.state['hiddenIds'], [])
        finally:
            await second.close()

    async def test_unknown_album_cannot_be_flagged(self):
        await self.app.handle({'cmd': 'toggle_hidden', 'id': 'missing'})
        self.assertEqual(self.app.state['hiddenIds'], [])

    async def test_failed_save_leaves_current_flags_unchanged(self):
        with patch('bandcamp.album_flags.save', side_effect=OSError('Disk full')):
            await self.app.handle({'cmd': 'toggle_favourite', 'id': 'a'})
        self.assertEqual(self.app.state['favouriteIds'], [])
        self.assertTrue(self.app.state['error'])

    async def test_login_has_flags_in_first_connected_collection(self):
        await self.app.handle({'cmd': 'toggle_favourite', 'id': 'a'})
        await self.app.handle({'cmd': 'toggle_hidden', 'id': 'b'})
        events = []
        self.app.output = events.append
        api = type('API', (), {'username': 'fan-one', 'albums': lambda self: [{'id':'a'}, {'id':'b'}]})()
        with patch('bandcamp.backend.BandcampAPI', return_value=api), patch.object(self.app, 'task', lambda coroutine: coroutine.close()):
            await self.app.handle({'cmd':'login', 'username':'fan-one', 'password':'generated'})
        connected = next(event['state'] for event in events if event.get('state', {}).get('connected'))
        self.assertEqual(connected['favouriteIds'], ['a'])
        self.assertEqual(connected['hiddenIds'], ['b'])
        self.assertEqual([a['id'] for a in connected['homeRecent']], ['a'])

    async def test_malformed_state_does_not_break_collection(self):
        path = album_flags.path_for('fan-one')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('{broken')
        self.app.load_album_flags()
        self.assertEqual(self.app.state['favouriteIds'], [])
        self.assertEqual(self.app.state['hiddenIds'], [])
