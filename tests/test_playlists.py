import unittest
from urllib.parse import parse_qs, urlsplit
from bandcamp.api import BandcampAPI, decode_response


class PlaylistTests(unittest.TestCase):
    def setUp(self):
        self.api = BandcampAPI('listener', 'password')
        self.calls = []
        def request(action, params=None, **kwargs):
            self.calls.append((action, params, kwargs))
            return {'status': 'ok', 'playlist': {'id': 'p', 'name': 'Playlist', 'entry': []}}
        self.api.request = request

    def test_repeat_song_ids_are_encoded_in_order(self):
        query = parse_qs(urlsplit(self.api.url('createPlaylist', {'songId': ['a', 'b', 'a']})).query)
        self.assertEqual(query['songId'], ['a', 'b', 'a'])

    def test_save_uses_post_and_preserves_duplicates(self):
        self.api.create_playlist('  Evening  ', ['a', 'b', 'a'])
        self.assertEqual(self.calls, [('createPlaylist', {'name': 'Evening', 'songId': ['a', 'b', 'a']}, {'post': True})])

    def test_rename_does_not_replace_tracks(self):
        self.api.rename_playlist('p', 'New name')
        self.assertEqual(self.calls[0], ('updatePlaylist', {'playlistId': 'p', 'name': 'New name'}, {'post': True}))

    def test_remove_uses_index_not_song_id(self):
        self.api.remove_playlist_track('p', 2)
        self.assertEqual(self.calls[0][1], {'playlistId': 'p', 'songIndexToRemove': 2})

    def test_reorder_uses_existing_id_not_new_playlist(self):
        self.api.replace_playlist_tracks('p', ['b', 'a'])
        self.assertEqual(self.calls[0], ('createPlaylist', {'playlistId': 'p', 'songId': ['b', 'a']}, {'post': True}))

    def test_xml_entries_keep_order_and_duplicates(self):
        data = b'<subsonic-response status="ok"><playlist id="p"><entry id="a"/><entry id="a"/></playlist></subsonic-response>'
        self.assertEqual([x['id'] for x in decode_response(data)['playlist']['entry']], ['a', 'a'])

    def test_empty_names_are_rejected_before_network(self):
        with self.assertRaises(ValueError):
            self.api.create_playlist('   ', ['a'])
        self.assertEqual(self.calls, [])
