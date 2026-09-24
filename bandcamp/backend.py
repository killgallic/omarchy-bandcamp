"""Own the account, collection and playback; communicate over private pipes."""
import asyncio
import hashlib
import json
import math
import os
from pathlib import Path
import signal
import sys
import time
from email.utils import parsedate_to_datetime
from datetime import datetime
from .config import Config

from .api import BandcampAPI, APIError
from . import credentials
from .mpv import Mpv
from .queue import Queue
from .library import LibraryCache


def public_item(item):
    keys = ('id', 'name', 'title', 'artist', 'album', 'duration', 'coverArt',
            'songCount', 'year', 'track', 'art', 'albumId', 'genre', 'genres', 'tags', 'created', 'playCount', 'releaseUrl', 'artistUrl', 'linkSource', 'purchasedAt')
    return {key: item[key] for key in keys if key in item}


def date_value(value):
    value = str(value or '')
    try:
        return parsedate_to_datetime(value).timestamp()
    except (ValueError, TypeError, OverflowError):
        try:
            return datetime.fromisoformat(value.replace('Z', '+00:00')).timestamp()
        except (ValueError, OverflowError):
            return 0


class App:
    def __init__(self, emit=None):
        self.output = emit or (lambda event: print(json.dumps(event), flush=True))
        self.api = None
        self.config = Config()
        self.queue = Queue()
        self.state = dict(connected=False, username='', busy=False, error='', notice='',
                          albums=[], album=None, queue=[], index=-1, playing=False,
                          position=0, duration=0, volume=75, shuffle=False, repeat='none',
                          current={}, mpris=False, starting=True, loading=False, playbackStatus='',
                          config=self.config.values.copy(), configPath=str(self.config.path),
                          playlists=[], playlist=None, playlistBusy=False, playlistError='',
                          collectionOrder='artist', collectionNotice='', history={}, tagSource='Bandcamp genres',
                          profile={}, metadataBusy=False, metadataNotice='', metadataJob={}, cacheStats={}, cachedCollection=None, offline=False,
                          homeRecent=[], homeRediscover=[])
        self.player = Mpv(self.mpv_event)
        self.network_lock = asyncio.Lock()
        self.stop = asyncio.Event()
        self.tasks = set()
        self.mpris = None
        self.generation = 0
        self.last_position = -1
        self.media_loaded = False
        self.play_generation = 0
        self.retry_attempt = 0
        self.retry_task = None
        self.load_timeout = None
        self.listen_seconds = 0
        self.listen_tick = None
        self.listen_recorded = False
        self.metadata_task = None
        self.metadata_cache = None
        self.notification_serial = 0

    def emit(self, **patch):
        if 'albums' in patch or 'history' in patch:
            albums = patch.get('albums', self.state['albums'])
            history = patch.get('history', self.state['history'])
            patch['homeRecent'] = sorted(albums, key=lambda a: (-date_value(a.get('created')), str(a.get('id', ''))))[:8]
            patch['homeRediscover'] = sorted(albums, key=lambda a: (history.get(str(a.get('id')), {}).get('lastPlayed', 0), str(a.get('id', ''))))[:4]
        self.state.update(patch)
        self.output({'event': 'state', 'state': patch or self.state.copy()})
        if self.mpris:
            self.mpris.changed(patch)

    def notify(self, level, code, message, resource_id='', action=None):
        self.notification_serial += 1
        self.output({'event':'notification', 'notification':{
            'id':str(self.notification_serial), 'level':level, 'code':code,
            'message':message, 'resourceId':resource_id, 'action':action}})

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
        saved = await asyncio.to_thread(credentials.load) if self.config.values['remember_login'] else None
        if saved:
            preview = await asyncio.to_thread(LibraryCache().load, saved['username'])
            if preview: self.emit(cachedCollection={**preview, 'stale':time.time()-preview['updatedAt'] > self.config.values['cache_ttl_minutes']*60})
            await self.handle({'cmd': 'login', **saved, 'cached_reconnect': True})
        else:
            self.emit(busy=False)
        self.emit(starting=False)
        if self.config.notice:
            self.emit(notice=self.config.notice)

    async def handle(self, message):
        try:
            if not isinstance(message, dict):
                raise ValueError()
            cmd = message.get('cmd')
            if cmd in ('login', 'refresh', 'album', 'play_album', 'enqueue_album', 'enqueue_track', 'logout'):
                async with self.network_lock:
                    await self.network_command(cmd, message)
                return
            if cmd in ('playlists', 'playlist', 'play_playlist', 'save_playlist', 'append_playlist',
                       'rename_playlist', 'remove_playlist_track', 'move_playlist_track', 'delete_playlist',
                       'create_playlist', 'create_and_add', 'add_to_playlist'):
                async with self.network_lock:
                    await self.playlist_command(cmd, message)
                return
            if cmd == 'reconnect':
                saved = await asyncio.to_thread(credentials.load)
                if saved:
                    async with self.network_lock:
                        await self.network_command('login', {**saved, 'cached_reconnect':True})
                else:
                    self.emit(error='No saved login is available. Sign in again.', offline=False)
                return
            if cmd == 'configure':
                async with self.network_lock:
                    values = message['values']
                    self.config.validate(values)
                    keyring_notice = ''
                    if 'remember_login' in values:
                        if not values['remember_login']:
                            if not await asyncio.to_thread(credentials.clear):
                                keyring_notice = 'Remember login is off, but the old keyring entry could not be removed.'
                        elif self.api and not await asyncio.to_thread(credentials.save, self.api.username, self.api._password):
                            self.emit(notice='The desktop keyring could not remember this login.')
                            return
                    await asyncio.to_thread(self.config.update, values)
                    if 'cache_budget_mb' in values:
                        from .cache import Cache
                        await asyncio.to_thread(Cache().prune_total, self.config.values['cache_budget_mb'] * 1024 * 1024)
                    self.emit(config=self.config.values.copy(), notice=keyring_notice)
                    self.notify('warning' if keyring_notice else 'success', 'settings_saved', keyring_notice or 'Settings saved', 'settings')
                    if 'metadata_enrichment' in values:
                        if not values['metadata_enrichment'] and self.metadata_task: self.metadata_task.cancel()
                        self.start_metadata(mode='cached')
                    if 'profile_url' in values and self.api:
                        self.task(self.load_profile(self.api, self.generation))
                        self.task(self.load_links(self.api, self.generation))
            elif cmd == 'cache_stats':
                from .cache import Cache
                self.emit(cacheStats=await asyncio.to_thread(Cache().stats))
            elif cmd == 'clear_cache':
                from .cache import Cache
                category = message['category']
                await asyncio.to_thread(Cache().clear, category)
                if category == 'metadata': self.metadata_cache = None
                self.emit(cacheStats=await asyncio.to_thread(Cache().stats), notice='Cache cleared.')
            elif cmd == 'generate_tags':
                if self.config.values['metadata_enrichment'] and self.api:
                    self.start_metadata(mode=message.get('mode', 'missing'))
                else:
                    self.emit(metadataNotice='Enable MusicBrainz tags in Settings first.')
            elif cmd == 'cancel_tags':
                if self.metadata_task: self.metadata_task.cancel()
                self.emit(metadataBusy=False, metadataJob={**self.state['metadataJob'], 'status':'cancelled'})
            elif cmd == 'collection_order':
                if message['order'] not in ('artist', 'album', 'newest', 'recent_purchased', 'most_played', 'recent_played'):
                    raise ValueError()
                self.emit(collectionOrder=message['order'])
                self.sort_collection()
            elif cmd == 'retry':
                await self.play_current()
            elif cmd == 'remove_queue':
                was_active = self.state['playing'] or self.state['loading']
                removed_current = self.queue.remove(int(message['index']))
                if removed_current:
                    self.cancel_loading()
                    if self.player.writer:
                        await self.player.command('stop')
                    self.media_loaded = False
                    self.emit(current=self.queue.current.copy(), playing=False, position=0, duration=0)
                    if self.queue.current and was_active:
                        await self.play_current()
                self.emit(queue=self.queue.tracks.copy(), index=self.queue.index)
            elif cmd == 'hello':
                self.emit()
            elif cmd == 'quit':
                self.stop.set()
            elif cmd == 'play_index':
                self.queue.select(int(message['index']))
                await self.play_current()
            elif cmd in ('toggle', 'play', 'pause'):
                if self.state['loading'] and cmd in ('toggle', 'pause'):
                    self.cancel_loading()
                    if self.player.writer:
                        await self.player.command('stop')
                    self.emit(playing=False)
                    return
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
                self.cancel_loading()
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
                self.cancel_loading()
                self.api = None
                self.generation += 1
                if self.player.writer:
                    await self.player.command('stop')
                self.emit(connected=False, playing=False)
            if cmd == 'login' and message.get('cached_reconnect') and not error.auth and self.state.get('cachedCollection'):
                self.emit(offline=True)
            self.emit(error=str(error), busy=False)
        except (ValueError, TypeError, KeyError, IndexError):
            self.emit(error='That action is not available. Please try again.', busy=False)
        except (RuntimeError, OSError, asyncio.TimeoutError):
            self.emit(error='The player could not complete that action. Please try again.', busy=False)

    async def network_command(self, cmd, message):
        if cmd == 'logout':
            self.generation += 1
            self.cancel_loading()
            self.api = None
            await self.player.close()
            self.queue = Queue()
            cleared = await asyncio.to_thread(credentials.clear)
            self.emit(connected=False, offline=False, cachedCollection=None, username='', albums=[], album=None, queue=[], index=-1,
                      current={}, playing=False, position=0, duration=0, busy=False, error='',
                      profile={}, playlists=[], playlist=None, history={},
                      notice='' if cleared else 'Could not clear the desktop keyring. Remove the Omarchy Bandcamp entry there if it was saved.')
            return
        self.emit(busy=True, error='', **({'album': None} if cmd == 'album' else {}))
        try:
            if cmd == 'login':
                username = str(message.get('username', '')).strip()
                password = str(message.get('password', ''))
                if not username or not password:
                    raise APIError('Enter your generated Subsonic username and password.')
                if 'profile_url' in message:
                    self.config.validate({'profile_url': message['profile_url']})
                api = BandcampAPI(username, password)
                # Bandcamp ping may succeed without auth. Collection access proves login.
                cached = await asyncio.to_thread(LibraryCache().load, username)
                fresh = cached and time.time() - cached['updatedAt'] <= self.config.values['cache_ttl_minutes'] * 60
                loaded_playlists = None
                if fresh:
                    loaded_playlists = await asyncio.to_thread(api.playlists)  # Prove credentials before showing cached records.
                    albums = cached['albums']
                else:
                    albums = await asyncio.to_thread(api.albums)
                self.generation += 1
                self.cancel_loading()
                self.api = api
                self.queue = Queue()
                await self.player.close()
                self.player = Mpv(self.mpv_event)
                self.emit(cachedCollection=None, offline=False, connected=True, username=username, albums=[public_item(a) for a in albums],
                          album=None, queue=[], index=-1, current={}, playing=False, position=0,
                          duration=0, error='', notice='', playlists=loaded_playlists or [], playlist=None, profile={}, history={}, playlistError='')
                if 'profile_url' in message:
                    self.config.update({'profile_url': message['profile_url']})
                    self.emit(config=self.config.values.copy())
                if not fresh: self.task(asyncio.to_thread(LibraryCache().save, username, albums))
                self.load_history()
                self.sort_collection()
                self.task(self.load_profile(api, self.generation))
                self.task(self.load_links(api, self.generation))
                self.start_metadata(mode='cached')
                if 'remember' in message:
                    self.config.update({'remember_login': bool(message['remember'])})
                    self.emit(config=self.config.values.copy())
                    if not message['remember']:
                        if not await asyncio.to_thread(credentials.clear):
                            self.emit(notice='Remember login is off, but the old keyring entry could not be removed.')
                if message.get('remember'):
                    if not await asyncio.to_thread(credentials.save, username, password):
                        self.emit(notice='Connected for this session. The desktop keyring could not save the login.')
                self.task(self.load_artwork(api, self.generation))
                if loaded_playlists is None: self.task(self.load_playlists(api, self.generation))
            else:
                if not self.api:
                    raise APIError('Sign in to load your collection.', auth=True)
                if cmd == 'refresh':
                    albums = await asyncio.to_thread(self.api.albums)
                    self.emit(albums=[public_item(a) for a in albums])
                    self.sort_collection()
                    self.task(asyncio.to_thread(LibraryCache().save, self.api.username, albums))
                    self.generation += 1
                    self.start_metadata(mode='cached')
                    self.task(self.load_artwork(self.api, self.generation))
                    self.task(self.load_links(self.api, self.generation))
                else:
                    album = await asyncio.to_thread(self.api.album, str(message['id']))
                    album = {**public_item(album), 'song': [public_item(t) for t in album.get('song', [])]}
                    linked = next((a for a in self.state['albums'] if str(a.get('id')) == str(album.get('id'))), {})
                    album.update({key:linked[key] for key in ('releaseUrl','artistUrl','linkSource', 'purchasedAt') if key in linked})
                    art = await self.artwork(self.api, album.get('coverArt'))
                    if art:
                        album['art'] = art
                        for track in album['song']:
                            track['art'] = art
                    if cmd == 'album':
                        self.emit(album=album)
                    elif cmd == 'play_album':
                        play_index = next((i for i, t in enumerate(album['song']) if str(t.get('id')) == str(message['trackId'])), -1) if message.get('trackId') else int(message.get('index', 0))
                        if not 0 <= play_index < len(album['song']): raise ValueError('Track is no longer available.')
                        self.queue.replace(album['song'], play_index)
                        await self.play_current()
                    elif cmd in ('enqueue_album', 'enqueue_track'):
                        tracks = album['song']
                        if cmd == 'enqueue_track':
                            index = next((i for i, t in enumerate(tracks) if str(t.get('id')) == str(message['trackId'])), -1) if message.get('trackId') else int(message['index'])
                            if not 0 <= index < len(tracks):
                                raise ValueError()
                            tracks = [tracks[index]]
                        self.queue.append(tracks)
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
                from .cache import Cache
                Cache(cache).prune_total(self.config.values['cache_budget_mb'] * 1024 * 1024)
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
            mapping = {str(a['id']): a.get('art', '') for a in chunk}
            self.emit(albums=[{**a, **({'art': mapping[str(a['id'])]} if str(a['id']) in mapping else {})} for a in self.state['albums']])

    def cancel_loading(self):
        self.play_generation += 1
        for task in (self.retry_task, self.load_timeout):
            if task and task is not asyncio.current_task():
                task.cancel()
        self.retry_task = self.load_timeout = None
        self.emit(loading=False, playbackStatus='')

    async def play_current(self, retry=False):
        if not self.api or not self.queue.current:
            raise APIError('Sign in and choose an album to play.')
        if not retry:
            self.cancel_loading()
            self.retry_attempt = 0
            self.listen_seconds = 0
            self.listen_recorded = False
        self.listen_tick = None
        token = self.play_generation
        api, player, track = self.api, self.player, self.queue.current.copy()
        self.media_loaded = False
        self.last_position = -1
        self.emit(current=self.queue.current.copy(), index=self.queue.index,
                  queue=self.queue.tracks.copy(), position=0, playing=False, loading=True,
                  playbackStatus='Retrying stream…' if retry else 'Loading stream…',
                  duration=float(self.queue.current.get('duration', 0) or 0), error='')
        try:
            await player.start()
            if token != self.play_generation:
                return
            await player.command('set_property', 'volume', self.state['volume'])
            if token != self.play_generation:
                return
            await player.command('loadfile', api.url('stream', {'id': track['id']}), 'replace')
            if token != self.play_generation:
                return
            await player.command('set_property', 'pause', False)
            if token == self.play_generation and not self.media_loaded:
                if self.load_timeout:
                    self.load_timeout.cancel()
                self.load_timeout = self.task(self.stream_timeout(token))
        except (APIError, RuntimeError, OSError, asyncio.TimeoutError):
            if token == self.play_generation:
                self.stream_failed()

    async def stream_timeout(self, token):
        await asyncio.sleep(30)
        if token == self.play_generation and not self.media_loaded:
            if self.player.writer:
                await self.player.command('stop')
            self.stream_failed()

    def stream_failed(self):
        self.media_loaded = False
        if self.load_timeout and self.load_timeout is not asyncio.current_task():
            self.load_timeout.cancel()
        if self.retry_task and not self.retry_task.done():
            return
        if self.retry_attempt < self.config.values['stream_retries'] and self.api and self.queue.current:
            self.retry_attempt += 1
            self.emit(playing=False, loading=True, playbackStatus=f'Retrying stream ({self.retry_attempt}/{self.config.values["stream_retries"]})…')
            self.retry_task = self.task(self.retry_stream(self.play_generation, self.retry_attempt))
        else:
            self.emit(playing=False, loading=False, playbackStatus='Stream failed',
                      error='This track could not be streamed after retrying. Retry or choose another track.')
            self.notify('error', 'stream_failed', 'This track could not be streamed. Retry or skip it.', str(self.queue.current.get('id','')), {'id':'retry'})

    async def retry_stream(self, token, attempt):
        await asyncio.sleep(min(2 ** (attempt - 1), 8))
        self.retry_task = None
        if token == self.play_generation and self.api:
            await self.play_current(retry=True)

    def mpv_event(self, event):
        kind = event.get('event')
        if kind == 'property-change':
            name, value = event.get('name'), event.get('data')
            if value is None:
                return
            if name == 'paused-for-cache' and self.media_loaded:
                self.emit(loading=bool(value), playbackStatus='Buffering…' if value else '')
            elif name == 'time-pos':
                now = time.monotonic()
                if self.listen_tick is not None and self.state['playing'] and not self.state['loading']:
                    self.listen_seconds += min(2, now - self.listen_tick)
                self.listen_tick = now
                self.record_listen()
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
            if self.load_timeout:
                self.load_timeout.cancel()
            self.emit(playing=True, loading=False, playbackStatus='', error='')
            self.output({'event':'notification', 'notification':{'resolved':True, 'resourceId':str(self.queue.current.get('id',''))}})
        elif kind == 'end-file':
            self.media_loaded = False
            if event.get('reason') == 'eof':
                self.task(self.finished(self.play_generation))
            elif event.get('reason') == 'error':
                self.stream_failed()
        elif kind == 'shutdown':
            self.media_loaded = False
            self.emit(playing=False)

    async def finished(self, token=None):
        if token is not None and token != self.play_generation:
            return
        if self.queue.advance(automatic=True):
            try:
                await self.play_current()
            except (APIError, RuntimeError, OSError):
                self.emit(playing=False, error='The next track could not be played.')
        else:
            self.emit(playing=False, loading=False, playbackStatus='', position=self.state['duration'])

    async def playlist_command(self, cmd, message):
        if not self.api:
            raise APIError('Sign in to manage playlists.', auth=True)
        self.emit(playlistBusy=True, playlistError='')
        try:
            playlist_id = str(message.get('id', ''))
            if cmd == 'playlists':
                self.emit(playlists=await asyncio.to_thread(self.api.playlists))
                return
            if cmd in ('playlist', 'play_playlist'):
                playlist = await asyncio.to_thread(self.api.playlist, playlist_id)
                playlist['entry'] = [public_item(t) for t in playlist['entry']]
                self.emit(playlist=playlist)
                if cmd == 'play_playlist':
                    self.queue.replace(playlist['entry'], int(message.get('index', 0)))
                    await self.play_current()
                return
            ids = [str(t['id']) for t in self.queue.tracks]
            if cmd in ('save_playlist', 'append_playlist') and not ids:
                raise ValueError('Add tracks to the queue first.')
            if cmd in ('save_playlist', 'create_playlist', 'create_and_add'):
                if cmd == 'create_playlist':
                    ids = []
                elif cmd == 'create_and_add':
                    from .playlists import source_tracks
                    tracks = await asyncio.to_thread(source_tracks, self.api, message['source'])
                    ids = [str(t['id']) for t in tracks]
                created = await asyncio.to_thread(self.api.create_playlist, message['name'], ids)
                playlist_id = str(created.get('id', ''))
            elif cmd == 'add_to_playlist':
                from .playlists import source_tracks
                tracks = await asyncio.to_thread(source_tracks, self.api, message['source'])
                await asyncio.to_thread(self.api.append_playlist, playlist_id, [str(t['id']) for t in tracks])
            elif cmd == 'append_playlist':
                await asyncio.to_thread(self.api.append_playlist, playlist_id, ids)
            elif cmd == 'rename_playlist':
                await asyncio.to_thread(self.api.rename_playlist, playlist_id, message['name'])
            elif cmd in ('remove_playlist_track', 'move_playlist_track'):
                playlist = await asyncio.to_thread(self.api.playlist, playlist_id)
                tracks = playlist['entry']
                index = int(message['index'])
                if not 0 <= index < len(tracks):
                    raise ValueError('Track is no longer in this playlist.')
                if cmd == 'remove_playlist_track':
                    await asyncio.to_thread(self.api.remove_playlist_track, playlist_id, index)
                else:
                    direction = int(message['direction'])
                    target = index + direction
                    if direction not in (-1, 1) or not 0 <= target < len(tracks):
                        raise ValueError('Track cannot move further.')
                    tracks[index], tracks[target] = tracks[target], tracks[index]
                    await asyncio.to_thread(self.api.replace_playlist_tracks, playlist_id, [t['id'] for t in tracks])
            elif cmd == 'delete_playlist':
                await asyncio.to_thread(self.api.delete_playlist, playlist_id)
                self.emit(playlist=None)
                playlist_id = ''
            if playlist_id:
                playlist = await asyncio.to_thread(self.api.playlist, playlist_id)
                playlist['entry'] = [public_item(t) for t in playlist['entry']]
                self.emit(playlist=playlist)
            self.emit(playlists=await asyncio.to_thread(self.api.playlists))
        except (APIError, ValueError, KeyError, IndexError) as error:
            if isinstance(error, APIError) and error.auth:
                raise
            message = str(error) if isinstance(error, APIError) else 'Check the playlist name or selected track and try again.'
            self.emit(playlistError=message)
            self.notify('error', 'playlist_operation_failed', message, playlist_id, {'id':'refresh'})
        finally:
            self.emit(playlistBusy=False)

    def history_path(self):
        name = hashlib.sha256(self.api.username.encode()).hexdigest()
        return Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'omarchy-bandcamp' / (name + '.json')

    def load_history(self):
        try:
            history = json.loads(self.history_path().read_text())
            if not isinstance(history, dict):
                history = {}
            history = {key: value for key, value in history.items() if isinstance(value, dict) and isinstance(value.get('plays'), int) and isinstance(value.get('lastPlayed'), (int, float))}
        except (OSError, ValueError):
            history = {}
        self.emit(history=history)

    def record_listen(self):
        duration = self.state['duration']
        album_id = str(self.queue.current.get('albumId', ''))
        if self.listen_recorded or not album_id or not self.api or duration <= 0 or self.listen_seconds < min(240, duration / 2):
            return
        self.listen_recorded = True
        history = dict(self.state['history'])
        old = history.get(album_id, {})
        history[album_id] = {'plays': old.get('plays', 0) + 1, 'lastPlayed': time.time()}
        self.emit(history=history)
        path = self.history_path()
        def save():
            path.parent.mkdir(parents=True, exist_ok=True)
            temporary = path.with_suffix('.tmp')
            temporary.write_text(json.dumps(history))
            temporary.chmod(0o600)
            temporary.replace(path)
        async def persist():
            try:
                await asyncio.to_thread(save)
            except OSError:
                self.emit(notice='Listening history could not be saved.')
        self.task(persist())
        if self.state['collectionOrder'] in ('most_played', 'recent_played'):
            self.sort_collection()

    def sort_collection(self):
        order = self.state['collectionOrder']
        history = self.state['history']
        def key(album):
            artist = str(album.get('artist', '')).casefold()
            title = str(album.get('name', '')).casefold()
            if order == 'album':
                return title, artist
            if order == 'newest':
                return -date_value(album.get('created')), artist, title
            if order == 'recent_purchased':
                return -date_value(album.get('purchasedAt')), artist, title
            if order in ('most_played', 'recent_played'):
                value = history.get(str(album['id']), {}).get('plays' if order == 'most_played' else 'lastPlayed', 0)
                return -value, artist, title
            return artist, title
        notice = 'Listening history recorded by this app.' if order in ('most_played', 'recent_played') else 'Collection-added dates supplied by Bandcamp; these may differ from purchase dates.' if order == 'newest' else 'Purchase dates from your public Bandcamp collection where available; unmatched records follow.' if order == 'recent_purchased' else ''
        self.emit(albums=sorted(self.state['albums'], key=key), collectionNotice=notice)

    def start_metadata(self, mode='cached'):
        if self.metadata_task:
            self.metadata_task.cancel()
        if not self.config.values['metadata_enrichment'] or not self.api:
            self.emit(metadataBusy=False)
            return
        generation = self.generation
        async def run():
            from .metadata import MetadataCache
            if self.metadata_cache is None:
                self.metadata_cache = MetadataCache()
            self.emit(metadataBusy=mode != 'cached', metadataJob={'status':'running' if mode != 'cached' else 'cached', 'total':len(self.state['albums']), 'processed':0})
            def progress(result):
                if generation == self.generation and (result['processed'] % 10 == 0 or result['processed'] == result['total']):
                    self.emit(metadataJob={'status':'running' if mode != 'cached' else 'cached', **result})
            def patch(album_id, tags):
                if generation == self.generation:
                    self.emit(albums=[{**a, 'tags': tags} if str(a['id']) == str(album_id) else a for a in self.state['albums']], tagSource='Bandcamp genres + MusicBrainz tags')
            try:
                result = await self.metadata_cache.enrich(self.state['albums'], lambda: self.config.values['metadata_enrichment'] and generation == self.generation, patch, on_progress=progress, cached_only=mode == 'cached', force=mode == 'all')
                self.emit(metadataNotice=result.get('notice', ''), metadataJob={'status':'complete', **result, 'lastCompletedAt':int(time.time())})
            except (OSError, ValueError):
                self.emit(metadataNotice='Metadata enrichment is unavailable; your collection still works.')
            finally:
                from .cache import Cache
                await asyncio.to_thread(Cache().prune_total, self.config.values['cache_budget_mb'] * 1024 * 1024)
                self.emit(metadataBusy=False)
        self.metadata_task = self.task(run())

    async def load_playlists(self, api, generation):
        try:
            playlists = await asyncio.to_thread(api.playlists)
        except (APIError, OSError, ValueError):
            return
        if generation == self.generation and api is self.api:
            self.emit(playlists=playlists)

    async def load_links(self, api, generation):
        from .links import load_public_links
        url = self.config.values['profile_url']
        try:
            links = await asyncio.to_thread(load_public_links, url, list(self.state['albums']), api.username)
        except (OSError, ValueError, UnicodeError):
            return
        if generation == self.generation and api is self.api and url == self.config.values['profile_url']:
            from .cache import Cache
            await asyncio.to_thread(Cache().prune_total, self.config.values['cache_budget_mb'] * 1024 * 1024)
            self.emit(albums=[{**album, **links.get(str(album['id']), {})} for album in self.state['albums']])
            if self.state['collectionOrder'] == 'recent_purchased': self.sort_collection()
            detail = self.state.get('album')
            if detail and str(detail.get('id')) in links:
                self.emit(album={**detail, **links[str(detail['id'])]})

    async def load_profile(self, api, generation):
        from .profile import load_profile
        url = self.config.values['profile_url']
        profile = await asyncio.to_thread(load_profile, api, url)
        if generation == self.generation and url == self.config.values['profile_url']:
            from .cache import Cache
            await asyncio.to_thread(Cache().prune_total, self.config.values['cache_budget_mb'] * 1024 * 1024)
            self.emit(profile=profile)

    async def close(self):
        self.cancel_loading()
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
