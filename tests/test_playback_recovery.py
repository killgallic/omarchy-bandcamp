import asyncio
import os
import tempfile
import unittest
from unittest.mock import patch, AsyncMock
from bandcamp.backend import App

class RecoveryTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.env = patch.dict(os.environ, {'XDG_CONFIG_HOME': self.directory.name, 'XDG_STATE_HOME': self.directory.name})
        self.env.start()
        self.app = App(emit=lambda event: None)
        self.app.api = type('API', (), {'url': lambda *args: 'fixture'})()
        self.app.queue.replace([{'id': 'one'}, {'id': 'two'}])
        self.app.player = type('Player', (), {'start': AsyncMock(), 'command': AsyncMock(), 'close': AsyncMock(), 'writer': True})()

    async def asyncTearDown(self):
        await self.app.close()
        self.env.stop()
        self.directory.cleanup()

    async def test_stop_during_load_does_not_start_audio_after_stop(self):
        reached, resume = asyncio.Event(), asyncio.Event()
        calls = []
        async def command(*args):
            calls.append(args)
            if args[:2] == ('set_property', 'volume'):
                reached.set()
                await resume.wait()
        self.app.player.command = command
        pending = asyncio.create_task(self.app.play_current())
        await reached.wait()
        await self.app.handle({'cmd': 'stop'})
        resume.set()
        await pending
        self.assertFalse(any(args[0] == 'loadfile' for args in calls))

    async def test_initial_cache_observation_keeps_loading_indicator(self):
        self.app.emit(loading=True)
        self.app.mpv_event({'event': 'property-change', 'name': 'paused-for-cache', 'data': False})
        self.assertTrue(self.app.state['loading'])

    async def test_stream_error_retries_same_track_then_exposes_error(self):
        self.app.config.values['stream_retries'] = 1
        self.app.mpv_event({'event': 'end-file', 'reason': 'error'})
        self.assertTrue(self.app.state['loading'])
        await self.app.retry_task
        self.assertEqual(self.app.queue.index, 0)
        self.assertTrue(any(call.args[0] == 'loadfile' for call in self.app.player.command.call_args_list))
        self.app.mpv_event({'event': 'end-file', 'reason': 'error'})
        self.assertFalse(self.app.state['loading'])
        self.assertTrue(self.app.state['error'])

    async def test_stop_cancels_scheduled_retry(self):
        self.app.mpv_event({'event': 'end-file', 'reason': 'error'})
        retry = self.app.retry_task
        await self.app.handle({'cmd': 'stop'})
        await asyncio.gather(retry, return_exceptions=True)
        self.assertFalse(any(call.args[0] == 'loadfile' for call in self.app.player.command.call_args_list))
        self.assertFalse(self.app.state['loading'])
