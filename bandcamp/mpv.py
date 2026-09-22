"""One owned mpv process, with a private IPC socket and no secret argv."""
import asyncio
import json
import tempfile
from pathlib import Path


class Mpv:
    def __init__(self, on_event, extra_args=()):
        self.on_event = on_event
        self.extra_args = extra_args
        self.process = None
        self.writer = None
        self.reader_task = None
        self.pending = {}
        self.serial = 0
        self.directory = None

    async def start(self):
        if self.process and self.process.returncode is None:
            return
        self.directory = tempfile.TemporaryDirectory(prefix='omarchy-bandcamp-')
        socket = str(Path(self.directory.name) / 'mpv.sock')
        self.process = await asyncio.create_subprocess_exec(
            'mpv', '--no-config', '--load-scripts=no', '--idle=yes', '--no-video',
            '--no-terminal', '--audio-client-name=Omarchy Bandcamp',
            '--input-ipc-server=' + socket, *self.extra_args,
            stdin=asyncio.subprocess.DEVNULL, stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL)
        for _ in range(100):
            if self.process.returncode is not None:
                raise RuntimeError('The audio player could not start.')
            try:
                reader, self.writer = await asyncio.open_unix_connection(socket)
                break
            except (FileNotFoundError, ConnectionRefusedError):
                await asyncio.sleep(.05)
        else:
            await self.close()
            raise RuntimeError('The audio player did not become ready.')
        self.reader_task = asyncio.create_task(self.read_events(reader))
        for index, prop in enumerate(('time-pos', 'duration', 'pause', 'volume', 'idle-active')):
            await self.command('observe_property', index, prop)

    async def read_events(self, reader):
        try:
            while line := await reader.readline():
                data = json.loads(line)
                future = self.pending.pop(data.get('request_id'), None)
                if future is not None and not future.done():
                    if data.get('error') == 'success':
                        future.set_result(data.get('data'))
                    else:
                        future.set_exception(RuntimeError('The audio player could not complete that action.'))
                elif data.get('event'):
                    self.on_event(data)
        finally:
            for future in self.pending.values():
                if not future.done():
                    future.set_exception(RuntimeError('The audio player disconnected.'))
            self.pending.clear()
            self.on_event({'event': 'shutdown'})

    async def command(self, *args):
        if not self.writer:
            raise RuntimeError('The audio player is not running.')
        self.serial += 1
        serial = self.serial
        future = asyncio.get_running_loop().create_future()
        self.pending[serial] = future
        try:
            self.writer.write((json.dumps({'command': args, 'request_id': serial}) + '\n').encode())
            await self.writer.drain()
            return await asyncio.wait_for(future, timeout=10)
        finally:
            self.pending.pop(serial, None)

    async def close(self):
        if self.writer:
            self.writer.close()
            self.writer = None
        if self.process and self.process.returncode is None:
            self.process.terminate()
            try:
                await asyncio.wait_for(self.process.wait(), 3)
            except asyncio.TimeoutError:
                self.process.kill()
                await self.process.wait()
        if self.reader_task:
            self.reader_task.cancel()
            await asyncio.gather(self.reader_task, return_exceptions=True)
            self.reader_task = None
        if self.directory:
            self.directory.cleanup()
