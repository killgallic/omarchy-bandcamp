import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from bandcamp.backend import App
class BackendNotifications(unittest.IsolatedAsyncioTestCase):
 async def test_each_settings_save_emits_a_transient_event(self):
  with tempfile.TemporaryDirectory() as directory, patch.dict('os.environ', {'XDG_CONFIG_HOME':directory}):
   events=[]; app=App(emit=events.append)
   await app.handle({'cmd':'configure','values':{'bar_width':220}})
   await app.handle({'cmd':'configure','values':{'bar_width':240}})
   saved=[event for event in events if event.get('event')=='notification' and event.get('notification',{}).get('code')=='settings_saved']
   self.assertEqual(len(saved),2)
   self.assertNotEqual(saved[0]['notification']['id'],saved[1]['notification']['id'])
