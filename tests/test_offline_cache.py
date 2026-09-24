import os
import tempfile
import unittest
from unittest.mock import patch
from bandcamp.backend import App
from bandcamp.api import APIError
from bandcamp.library import LibraryCache
class OfflineCacheTests(unittest.IsolatedAsyncioTestCase):
 async def test_saved_account_network_failure_exposes_read_only_cache(self):
  with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ,{'XDG_CONFIG_HOME':directory,'XDG_CACHE_HOME':directory}):
   LibraryCache().save('listener',[{'id':'a:1','name':'Cached','artist':'A'}])
   app=App(emit=lambda event:None)
   app.emit(cachedCollection=LibraryCache().load('listener'))
   class API:
    def __init__(self,*args): self.username='listener'
    def playlists(self): raise APIError('Cannot reach Bandcamp.')
   with patch('bandcamp.backend.BandcampAPI',API):
    await app.handle({'cmd':'login','username':'listener','password':'bad','cached_reconnect':True})
   self.assertFalse(app.state['connected'])
   self.assertTrue(app.state['offline'])
   self.assertEqual(app.state['cachedCollection']['albums'][0]['name'],'Cached')
