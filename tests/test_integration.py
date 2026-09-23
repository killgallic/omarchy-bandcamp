"""Run with BANDCAMP_INTEGRATION=1 on an isolated dbus-run-session bus."""
import asyncio
import os
from pathlib import Path
import tempfile
import unittest
import wave

from bandcamp.backend import App
from bandcamp.mpv import Mpv
from bandcamp.mpris import Mpris, NAME, PATH
from dbus_next.aio import MessageBus


@unittest.skipUnless(os.environ.get('BANDCAMP_INTEGRATION') == '1', 'Opt-in local audio/session-bus test')
class IntegrationTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.audio = Path(self.directory.name) / 'silence.wav'
        with wave.open(str(self.audio), 'wb') as output:
            output.setparams((1, 2, 8000, 0, 'NONE', 'not compressed'))
            output.writeframes(b'\0\0' * 8000 * 5)
        self.app = App(emit=lambda event: None)
        self.app.api = type('LocalAPI', (), {'url': lambda api, *args: str(self.audio)})()
        self.app.state['connected'] = True
        self.app.player = Mpv(self.app.mpv_event, ('--ao=null',))
        self.app.queue.replace([{'id': '1', 'title': 'One', 'duration': 5}, {'id': '2', 'title': 'Two', 'duration': 5}])
        self.client = None

    async def asyncTearDown(self):
        if self.client:
            self.client.disconnect()
        await self.app.close()
        self.directory.cleanup()

    async def until(self, predicate):
        async with asyncio.timeout(8):
            while not predicate():
                await asyncio.sleep(.05)

    async def test_real_mpv_play_pause_seek_next_and_stop_resume(self):
        await self.app.play_current()
        await self.until(lambda: self.app.state['playing'])
        await self.app.handle({'cmd': 'pause'})
        await self.until(lambda: not self.app.state['playing'])
        await self.app.handle({'cmd': 'seek', 'position': 2})
        self.assertAlmostEqual(self.app.state['position'], 2, delta=.1)
        await self.app.handle({'cmd': 'next'})
        await self.until(lambda: self.app.state['current']['id'] == '2' and self.app.state['playing'])
        await self.app.handle({'cmd': 'stop'})
        await self.until(lambda: not self.app.state['playing'])
        await self.app.handle({'cmd': 'play'})
        await self.until(lambda: self.app.state['playing'])
        self.assertEqual(self.app.state['error'], '')

    async def test_real_eof_advances_without_manual_next(self):
        await self.app.play_current()
        await self.until(lambda: self.app.state['playing'])
        await self.until(lambda: self.app.state['current']['id'] == '2' and self.app.state['playing'])
        self.assertEqual(self.app.state['error'], '')

    async def test_dbus_client_can_read_metadata_and_pause(self):
        self.app.mpris = await Mpris.connect(self.app)
        await self.app.play_current()
        await self.until(lambda: self.app.state['playing'])
        self.client = await MessageBus().connect()
        node = await self.client.introspect(NAME, PATH)
        proxy = self.client.get_proxy_object(NAME, PATH, node)
        player = proxy.get_interface('org.mpris.MediaPlayer2.Player')
        self.assertEqual((await player.get_metadata())['xesam:title'].value, 'One')
        await player.call_pause()
        await self.until(lambda: not self.app.state['playing'])
        self.assertEqual(await player.get_playback_status(), 'Paused')
        await player.set_volume(.4)
        await self.until(lambda: self.app.state['volume'] == 40)
