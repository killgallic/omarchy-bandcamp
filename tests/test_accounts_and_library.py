import asyncio
import os
import tempfile
import unittest
from unittest.mock import patch, AsyncMock
from bandcamp.backend import App

class LibraryTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'XDG_CONFIG_HOME': self.directory.name, 'XDG_STATE_HOME': self.directory.name})
        self.env.start()
        self.app = App(emit=lambda event: None)

    async def asyncTearDown(self):
        await self.app.close()
        self.env.stop()
        self.directory.cleanup()

    async def test_remember_disabled_skips_keyring_lookup_on_start(self):
        self.app.config.values['remember_login'] = False
        with patch('bandcamp.credentials.load') as load, patch('bandcamp.mpris.Mpris.connect', AsyncMock(side_effect=RuntimeError())):
            await self.app.start()
        load.assert_not_called()
        self.assertFalse(self.app.state['starting'])

    async def test_concurrent_config_changes_are_both_persisted(self):
        await asyncio.gather(self.app.handle({'cmd': 'configure', 'values': {'bar_display': 'icon'}}),
                             self.app.handle({'cmd': 'configure', 'values': {'large_player_width': 1100}}))
        self.assertEqual(self.app.state['config']['bar_display'], 'icon')
        self.assertEqual(self.app.state['config']['large_player_width'], 1100)

    async def test_recently_added_sorts_real_bandcamp_dates_without_losing_albums(self):
        self.app.emit(albums=[{'id': 'a', 'created': '01 Nov 2020 00:00:00 GMT'},
                              {'id': 'b', 'created': '13 Jan 2024 00:00:00 GMT'}, {'id': 'c'}])
        await self.app.handle({'cmd': 'collection_order', 'order': 'newest'})
        self.assertEqual([a['id'] for a in self.app.state['albums']], ['b', 'a', 'c'])

    async def test_playlist_reorder_keeps_duplicate_tracks_and_queue(self):
        class API:
            playlist = lambda self, id: {'id': id, 'entry': [{'id': 'a'}, {'id': 'b'}, {'id': 'a'}]}
            playlists = lambda self: []
            def replace_playlist_tracks(self, id, tracks): self.written = (id, tracks)
        api = self.app.api = API()
        self.app.queue.replace([{'id': 'playing'}])
        await self.app.handle({'cmd': 'move_playlist_track', 'id': 'p', 'index': 0, 'direction': 1})
        self.assertEqual(api.written, ('p', ['b', 'a', 'a']))
        self.assertEqual(self.app.queue.current['id'], 'playing')

    async def test_single_track_enqueue_only_adds_selected_track(self):
        class API:
            album = lambda self, id: {'id': id, 'song': [{'id': 'a'}, {'id': 'b'}]}
        self.app.api = API()
        await self.app.handle({'cmd': 'enqueue_track', 'id': 'album', 'index': 1})
        self.assertEqual(self.app.state['queue'], [{'id': 'b'}])
        self.assertFalse(self.app.state['playing'])

    async def test_recently_purchased_uses_verified_public_dates_and_leaves_unknown_last(self):
        self.app.emit(albums=[{'id':'old','purchasedAt':'01 Jan 2020 00:00:00 GMT'},
                              {'id':'new','purchasedAt':'01 Jan 2024 00:00:00 GMT'}, {'id':'unknown','created':'01 Jan 2025 00:00:00 GMT'}])
        await self.app.handle({'cmd':'collection_order','order':'recent_purchased'})
        self.assertEqual([a['id'] for a in self.app.state['albums']],['new','old','unknown'])

    async def test_play_album_track_id_ignores_playlist_row_index(self):
        class API:
            def album(self, id): return {'id':id,'song':[{'id':'first'},{'id':'wanted'}]}
        self.app.api=API()
        async def fake_play(): pass
        with patch.object(self.app,'play_current',fake_play), patch.object(self.app,'artwork',AsyncMock(return_value='')):
            await self.app.handle({'cmd':'play_album','id':'album','index':0,'trackId':'wanted'})
        self.assertEqual(self.app.queue.current['id'],'wanted')
