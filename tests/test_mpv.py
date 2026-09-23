import asyncio
import unittest
from unittest.mock import AsyncMock, patch

from bandcamp.mpv import Mpv


class MpvStartupTests(unittest.IsolatedAsyncioTestCase):
    async def test_concurrent_start_waits_for_ready_connection(self):
        player = Mpv(lambda event: None)
        entered = asyncio.Event()
        release = asyncio.Event()
        calls = []
        async def startup():
            calls.append('start')
            entered.set()
            await release.wait()
            player.process = type('Process', (), {'returncode': None})()
            player.writer = type('Writer', (), {'is_closing': lambda self: False})()
            player.reader_task = asyncio.create_task(asyncio.sleep(60))
        with patch.object(player, '_start', startup):
            first = asyncio.create_task(player.start())
            await entered.wait()
            second = asyncio.create_task(player.start())
            await asyncio.sleep(0)
            self.assertFalse(second.done())
            release.set()
            await asyncio.gather(first, second)
        self.assertEqual(calls, ['start'])
        player.reader_task.cancel()
        await asyncio.gather(player.reader_task, return_exceptions=True)

    async def test_live_process_with_dead_ipc_is_restarted(self):
        player = Mpv(lambda event: None)
        player.process = type('Process', (), {'returncode': None})()
        player.writer = type('Writer', (), {'is_closing': lambda self: True})()
        player.reader_task = asyncio.create_task(asyncio.sleep(60))
        with patch.object(player, '_close', AsyncMock()) as close, patch.object(player, '_start', AsyncMock()) as start:
            await player.start()
            close.assert_awaited_once()
            start.assert_awaited_once()
        player.reader_task.cancel()
        await asyncio.gather(player.reader_task, return_exceptions=True)

    async def test_failed_start_cleans_partial_process(self):
        player = Mpv(lambda event: None)
        with patch.object(player, '_start', AsyncMock(side_effect=RuntimeError('failure'))), patch.object(player, '_close', AsyncMock()) as close:
            with self.assertRaises(RuntimeError):
                await player.start()
            close.assert_awaited_once()

    async def test_close_tolerates_process_exiting_before_terminate(self):
        from unittest.mock import Mock
        from types import SimpleNamespace
        player = Mpv(lambda event: None)
        player.process = SimpleNamespace(returncode=None, terminate=Mock(side_effect=ProcessLookupError), wait=AsyncMock())
        await player.close()
        self.assertIsNone(player.process)
