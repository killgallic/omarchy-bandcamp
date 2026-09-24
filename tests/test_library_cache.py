import tempfile
import unittest
from pathlib import Path
from bandcamp.library import LibraryCache
class LibraryCacheTests(unittest.TestCase):
 def test_per_account_preview_and_clear(self):
  with tempfile.TemporaryDirectory() as directory:
   cache=LibraryCache(Path(directory))
   cache.save('one',[{'id':'1','name':'One','artist':'A','streamUrl':'SECRET'}])
   self.assertEqual(cache.load('one')['albums'][0]['name'],'One')
   self.assertIsNone(cache.load('two'))
   self.assertNotIn('SECRET', next(Path(directory).glob('library-*.json')).read_text())
   cache.clear()
   self.assertIsNone(cache.load('one'))

class CachedLoginTests(unittest.IsolatedAsyncioTestCase):
 async def test_fresh_cache_uses_authenticated_lightweight_request(self):
  import os
  from unittest.mock import patch
  from bandcamp.backend import App
  with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ,{'XDG_CACHE_HOME':directory,'XDG_CONFIG_HOME':directory}):
   LibraryCache().save('listener',[{'id':'a','name':'Cached','artist':'A'}])
   app=App(emit=lambda event:None)
   class API:
    def __init__(self,*args): self.username='listener';self._password='private';self.calls=[]
    def playlists(self): self.calls.append('playlists');return []
    def albums(self): self.calls.append('albums');raise AssertionError('unnecessary full fetch')
   with patch('bandcamp.backend.BandcampAPI',API), patch('bandcamp.backend.credentials.save',return_value=True), patch('bandcamp.backend.Mpv.close',return_value=None):
    await app.handle({'cmd':'login','username':'listener','password':'private'})
   self.assertEqual(app.api.calls,['playlists'])
   self.assertEqual(app.state['albums'][0]['name'],'Cached')
   for task in list(app.tasks): task.cancel()
