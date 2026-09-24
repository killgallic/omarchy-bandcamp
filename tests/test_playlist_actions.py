import tempfile
import unittest
from unittest.mock import patch
from bandcamp.backend import App

class PlaylistActions(unittest.IsolatedAsyncioTestCase):
    async def test_empty_creation_and_item_add_leave_queue_unchanged(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict('os.environ', {'XDG_CONFIG_HOME': directory}):
            app = App(emit=lambda event: None)
            class API:
                def __init__(self): self.entries = []; self.created = None
                def create_playlist(self, name, ids): self.created = (name, ids); return {'id': 'p'}
                def album(self, id): return {'song': [{'id':'a'}, {'id':'b'}]}
                def append_playlist(self, id, ids): self.entries.extend(ids)
                def playlist(self, id): return {'id': id, 'entry': [{'id': x} for x in self.entries]}
                def playlists(self): return [{'id':'p', 'name':'Empty'}]
            app.api = API()
            app.queue.append([{'id':'untouched'}])
            await app.handle({'cmd':'create_playlist', 'name':'Empty'})
            self.assertEqual(app.api.created, ('Empty', []))
            await app.handle({'cmd':'add_to_playlist', 'id':'p', 'source':{'kind':'track','id':'b','albumId':'album'}})
            self.assertEqual(app.api.entries, ['b'])
            await app.handle({'cmd':'add_to_playlist', 'id':'p', 'source':{'kind':'album','id':'album'}})
            self.assertEqual(app.api.entries, ['b','a','b'])
            self.assertEqual(app.queue.tracks, [{'id':'untouched'}])
            await app.handle({'cmd':'add_to_playlist', 'id':'p', 'source':{'kind':'track','id':'unknown','albumId':'album'}})
            self.assertEqual(app.api.entries, ['b','a','b'])
            self.assertTrue(app.state['playlistError'])

    async def test_create_and_add_snapshots_selection(self):
        with tempfile.TemporaryDirectory() as directory, patch.dict('os.environ', {'XDG_CONFIG_HOME': directory}):
            app = App(emit=lambda event: None)
            class API:
                def __init__(self): self.created = None
                def create_playlist(self,name,ids): self.created=(name,ids); return {'id':'new'}
                def album(self,id): return {'song':[{'id':'first'},{'id':'second'}]}
                def playlist(self,id): return {'id':id,'entry':[]}
                def playlists(self): return []
            api=app.api=API()
            await app.handle({'cmd':'create_and_add','name':'Evening','source':{'kind':'track','id':'second','albumId':'album'}})
            self.assertEqual(api.created,('Evening',['second']))
