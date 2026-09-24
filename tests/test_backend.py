import json
import os
import tempfile
import unittest
from unittest.mock import patch

from bandcamp.backend import App
from bandcamp.api import APIError


class FakeAPI:
    def __init__(self, username, password):
        self.username = username
    def albums(self):
        return [{'id': 'a', 'name': 'Album', 'artist': 'Artist'}]
    def album(self, album_id):
        return {'id': album_id, 'name': 'Album', 'song': [{'id': 's', 'title': 'Song'}]}


class BackendTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.environment = patch.dict(os.environ, {'XDG_CONFIG_HOME':self.directory.name, 'XDG_CACHE_HOME':self.directory.name, 'XDG_STATE_HOME':self.directory.name})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.events = []
        self.app = App(emit=self.events.append)

    async def asyncTearDown(self):
        await self.app.close()

    async def test_login_populates_collection_without_exposing_credentials(self):
        with patch('bandcamp.backend.BandcampAPI', FakeAPI):
            await self.app.handle({'cmd': 'login', 'username': 'listener', 'password': 'NEVER_SHOW_THIS'})
        self.assertTrue(self.app.state['connected'])
        self.assertEqual(self.app.state['albums'][0]['id'], 'a')
        self.assertNotIn('NEVER_SHOW_THIS', json.dumps(self.events))
        self.assertFalse(self.app.state['busy'])

    async def test_rejected_login_does_not_claim_connected(self):
        with patch('bandcamp.backend.BandcampAPI', FakeAPI), patch.object(FakeAPI, 'albums', side_effect=APIError('Login rejected', auth=True)):
            await self.app.handle({'cmd': 'login', 'username': 'listener', 'password': 'bad'})
        self.assertFalse(self.app.state['connected'])
        self.assertEqual(self.app.state['error'], 'Login rejected')
        self.assertFalse(self.app.state['busy'])

    async def test_network_failure_keeps_loaded_collection(self):
        self.app.api = FakeAPI('u', 'p')
        self.app.state.update(connected=True, albums=[{'id': 'old'}])
        with patch.object(FakeAPI, 'albums', side_effect=APIError('Offline')):
            await self.app.handle({'cmd': 'refresh'})
        self.assertTrue(self.app.state['connected'])
        self.assertEqual(self.app.state['albums'], [{'id': 'old'}])

    async def test_invalid_command_gets_safe_error(self):
        await self.app.handle({'cmd': 'seek', 'position': 'password=secret'})
        self.assertNotIn('secret', json.dumps(self.events))

    async def test_enqueue_album_does_not_start_playback(self):
        self.app.api = FakeAPI('u', 'p')
        self.app.state['connected'] = True
        await self.app.handle({'cmd': 'enqueue_album', 'id': 'a'})
        self.assertEqual(self.app.state['queue'][0]['id'], 's')
        self.assertFalse(self.app.state['playing'])
