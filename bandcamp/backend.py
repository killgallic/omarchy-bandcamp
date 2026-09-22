"""Own the account, collection and playback; communicate over private pipes."""
import asyncio
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import sys

from .api import BandcampAPI, APIError
from . import credentials
from .mpv import Mpv
from .queue import Queue


def public_item(item):
    keys = ('id', 'name', 'title', 'artist', 'album', 'duration', 'coverArt',
            'songCount', 'year', 'track', 'art')
    return {key: item[key] for key in keys if key in item}


class App:
    def __init__(self, emit=None):
        self.output = emit or (lambda event: print(json.dumps(event), flush=True))
        self.api = None
        self.queue = Queue()
        self.state = dict(connected=False, username='', busy=False, error='', notice='',
                          albums=[], album=None, queue=[], index=-1, playing=False,
                          position=0, duration=0, volume=75, shuffle=False, repeat='none',
                          current={}, mpris=False)
        self.player = Mpv(self.mpv_event)
        self.network_lock = asyncio.Lock()
        self.stop = asyncio.Event()
        self.tasks = set()
        self.mpris = None
        self.generation = 0
        self.last_position = -1
        self.media_loaded = False

    def emit(self, **patch):
        self.state.update(patch)
        self.output({'event': 'state', 'state': patch or self.state.copy()})
        if self.mpris:
            self.mpris.changed(patch)

    def task(self, coroutine):
        task = asyncio.create_task(coroutine)
        self.tasks.add(task)
        task.add_done_callback(self.tasks.discard)
        return task

    async def start(self):
        self.emit()
        self.emit(busy=True)
        try:
            from .mpris import Mpris
            self.mpris = await Mpris.connect(self)
            self.emit(mpris=True)
        except Exception:
            self.mpris = None
            self.emit(notice='Desktop media controls are unavailable in this session.')
        saved = await asyncio.to_thread(credentials.load)
        if saved:
            await self.handle({'cmd': 'login', **saved})
        else:
            self.emit(busy=False)

    async def handle(self, message):
        try:
            if not isinstance(message, dict):
                raise ValueError()
            cmd = message.get('cmd')
            if cmd in ('login', 'refresh', 'album', 'play_album', 'enqueue_album', 'logout'):
                async with self.network_lock:
                    await self.network_command(cmd, message)
                return
            if cmd == 'hello':
                self.emit()
            elif cmd == 'quit':
                self.stop.set()
            elif cmd == 'play_index':
                self.queue.select(int(message['index']))
                await self.play_current()
            elif cmd in ('toggle', 'play', 'pause'):
                if not self.queue.current:
                    if self.queue.tracks and cmd != 'pause':
                        self.queue.select(0)
                        await self.play_current()
                    return
                if self.state['playing'] and cmd != 'play':
                    await self.player.command('set_property', 'pause', True)
                elif not self.state['playing'] and cmd != 'pause':
                    if not self.media_loaded or not self.player.writer:
                        await self.play_current()
                    else:
                        await self.player.command('set_property', 'pause', False)
            elif cmd == 'stop':
                if self.player.writer:
                    await self.player.command('stop')
                self.emit(playing=False, position=0)
                self.media_loaded = False
            elif cmd == 'next':
                if self.queue.advance():
                    await self.play_current()
            elif cmd == 'previous':
                if self.state['position'] > 3 and self.player.writer:
                    await self.player.command('seek', 0, 'absolute')
                elif self.queue.previous():
                    await self.play_current()
            elif cmd == 'seek':
                position = float(message['position'])
                if not math.isfinite(position):
                    raise ValueError()
                if self.player.writer:
                    position = max(0, min(self.state['duration'], position))
                    await self.player.command('seek', position, 'absolute')
                    self.emit(position=position)
                    if self.mpris:
                        self.mpris.player.Seeked(int(position * 1_000_000))
            elif cmd == 'volume':
                volume = float(message['value'])
                if not math.isfinite(volume):
                    raise ValueError()
                volume = max(0, min(100, volume))
                if self.player.writer:
                    await self.player.command('set_property', 'volume', volume)
                self.emit(volume=volume)
            elif cmd == 'shuffle':
                self.queue.set_shuffle(bool(message['enabled']))
                self.emit(shuffle=self.queue.shuffle)
            elif cmd == 'repeat':
                if message['mode'] not in ('none', 'all', 'one'):
                    raise ValueError()
                self.queue.repeat = message['mode']
                self.emit(repeat=self.queue.repeat)
            else:
                raise ValueError()
        except APIError as error:
            if error.auth:
                self.api = None
                self.generation += 1
                if self.player.writer:
                    await self.player.command('stop')
                self.emit(connected=False, playing=False)
            self.emit(error=str(error), busy=False)
        except (ValueError, TypeError, KeyError, IndexError):
            self.emit(error='That action is not available. Please try again.', busy=False)
        except (RuntimeError, OSError, asyncio.TimeoutError):
            self.emit(error='The player could not complete that action. Please try again.', busy=False)

    async def network_command(self, cmd, message):
        if cmd == 'logout':
            self.generation += 1
            self.api = None
            await self.player.close()
            self.queue = Queue()
            cleared = await asyncio.to_thread(credentials.clear)
            self.emit(connected=False, username='', albums=[], album=None, queue=[], index=-1,
                      current={}, playing=False, position=0, duration=0, busy=False, error='',
                      notice='' if cleared else 'Could not clear the desktop keyring. Remove the Omarchy Bandcamp entry there if it was saved.')
            return
        self.emit(busy=True, error='', **({'album': None} if cmd == 'album' else {}))
        try:
            if cmd == 'login':
                username = str(message.get('username', '')).strip()
                password = str(message.get('password', ''))
                if not username or not password:
                    raise APIError('Enter your generated Subsonic username and password.')
                api = BandcampAPI(username, password)
                # Bandcamp ping may succeed without auth. Collection access proves login.
                albums = await asyncio.to_thread(api.albums)
                self.generation += 1
                self.api = api
                self.queue = Queue()
                await self.player.close()
                self.player = Mpv(self.mpv_event)
                self.emit(connected=True, username=username, albums=[public_item(a) for a in albums],
                          album=None, queue=[], index=-1, current={}, playing=False, position=0,
                          duration=0, error='', notice='')
                if message.get('remember'):
                    if not await asyncio.to_thread(credentials.save, username, password):
                        self.emit(notice='Connected for this session. The desktop keyring could not save the login.')
                self.task(self.load_artwork(api, self.generation))
            else:
                if not self.api:
                    raise APIError('Sign in to load your collection.', auth=True)
                if cmd == 'refresh':
                    albums = await asyncio.to_thread(self.api.albums)
                    self.emit(albums=[public_item(a) for a in albums])
                    self.generation += 1
                    self.task(self.load_artwork(self.api, self.generation))
                else:
                    album = await asyncio.to_thread(self.api.album, str(message['id']))
                    album = {**public_item(album), 'song': [public_item(t) for t in album.get('song', [])]}
                    art = await self.artwork(self.api, album.get('coverArt'))
                    if art:
                        album['art'] = art
                        for track in album['song']:
                            track['art'] = art
                    if cmd == 'album':
                        self.emit(album=album)
                    elif cmd == 'play_album':
                        self.queue.replace(album['song'], int(message.get('index', 0)))
                        await self.play_current()
                    elif cmd == 'enqueue_album':
                        self.queue.append(album['song'])
                        self.emit(queue=self.queue.tracks.copy())
        finally:
            self.emit(busy=False)

    async def artwork(self, api, cover_id):
        if not cover_id:
            return ''
        cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'omarchy-bandcamp'
        name = hashlib.sha256((api.username + ':' + str(cover_id)).encode()).hexdigest() + '.img'
        path = cache / name
        def fetch():
            cache.mkdir(mode=0o700, parents=True, exist_ok=True)
            if not path.exists():
                data = api.fetch('getCoverArt', {'id': cover_id, 'size': 400}, limit=8 * 1024 * 1024)
                if not (data.startswith(b'\xff\xd8') or data.startswith(b'\x89PNG') or data.startswith(b'RIFF')):
                    return ''
                temporary = path.with_suffix('.tmp')
                temporary.write_bytes(data)
                temporary.chmod(0o600)
                temporary.replace(path)
            return path.as_uri()
        try:
            return await asyncio.to_thread(fetch)
        except (APIError, OSError):
            return ''

    async def load_artwork(self, api, generation):
        albums = [dict(a) for a in self.state['albums']]
        for start in range(0, len(albums), 8):
            if generation != self.generation:
                return
            chunk = albums[start:start + 8]
            arts = await asyncio.gather(*(self.artwork(api, a.get('coverArt')) for a in chunk))
            if generation != self.generation:
                return
            for album, art in zip(chunk, arts):
                album['art'] = art
            self.emit(albums=albums.copy())

    async def play_current(self):
        if not self.api or not self.queue.current:
            raise APIError('Sign in and choose an album to play.')
        await self.player.start()
        await self.player.command('set_property', 'volume', self.state['volume'])
        self.last_position = -1
        self.media_loaded = False
        self.emit(current=self.queue.current.copy(), index=self.queue.index,
                  queue=self.queue.tracks.copy(), position=0,
                  duration=float(self.queue.current.get('duration', 0) or 0), error='')
        await self.player.command('loadfile', self.api.url('stream', {'id': self.queue.current['id']}), 'replace')
        await self.player.command('set_property', 'pause', False)

    def mpv_event(self, event):
        kind = event.get('event')
        if kind == 'property-change':
            name, value = event.get('name'), event.get('data')
            if value is None:
                return
            if name == 'time-pos':
                second = int(value)
                if second != self.last_position:
                    self.last_position = second
                    self.emit(position=float(value))
            elif name == 'duration':
                self.emit(duration=float(value))
            elif name == 'pause' and self.media_loaded:
                self.emit(playing=not value)
            elif name == 'volume':
                self.emit(volume=float(value))
            elif name == 'idle-active' and value:
                self.emit(playing=False)
        elif kind == 'file-loaded':
            self.media_loaded = True
            self.emit(playing=True)
        elif kind == 'end-file':
            self.media_loaded = False
            if event.get('reason') == 'eof':
                self.task(self.finished())
            elif event.get('reason') == 'error':
                self.emit(playing=False, error='This track could not be streamed. Retry it, or refresh your collection.')
        elif kind == 'shutdown':
            self.media_loaded = False
            self.emit(playing=False)

    async def finished(self):
        if self.queue.advance(automatic=True):
            try:
                await self.play_current()
            except (APIError, RuntimeError, OSError):
                self.emit(playing=False, error='The next track could not be played.')
        else:
            self.emit(playing=False, position=self.state['duration'])

    async def close(self):
        for task in list(self.tasks):
            task.cancel()
        if self.tasks:
            await asyncio.gather(*self.tasks, return_exceptions=True)
        await self.player.close()
        if self.mpris:
            self.mpris.bus.disconnect()


async def main():
    app = App()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, app.stop.set)
    reader = asyncio.StreamReader(limit=1024 * 1024)
    transport, _ = await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(reader), sys.stdin)
    async def commands():
        while line := await reader.readline():
            try:
                message = json.loads(line)
            except (ValueError, UnicodeError):
                app.emit(error='Unreadable player command.')
                continue
            app.task(app.handle(message))
        app.stop.set()
    input_task = asyncio.create_task(commands())
    startup = asyncio.create_task(app.start())
    try:
        await app.stop.wait()
    finally:
        input_task.cancel()
        startup.cancel()
        await asyncio.gather(input_task, startup, return_exceptions=True)
        await app.close()
        transport.close()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except BrokenPipeError:
        pass
