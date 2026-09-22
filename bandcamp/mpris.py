"""Linux media controls with public metadata only."""
import hashlib

from dbus_next import Variant, DBusError
from dbus_next.aio import MessageBus
from dbus_next.constants import PropertyAccess, NameFlag, RequestNameReply
from dbus_next.service import ServiceInterface, dbus_property, method, signal

PATH = '/org/mpris/MediaPlayer2'
NAME = 'org.mpris.MediaPlayer2.omarchy_bandcamp'


def track_path(track):
    if not track:
        return '/org/mpris/MediaPlayer2/TrackList/NoTrack'
    return PATH + '/track/' + hashlib.sha256(str(track['id']).encode()).hexdigest()


def metadata(track):
    if not track:
        return {}
    result = {'mpris:trackid': Variant('o', track_path(track)),
              'mpris:length': Variant('x', int(float(track.get('duration', 0) or 0) * 1_000_000)),
              'xesam:title': Variant('s', str(track.get('title', ''))),
              'xesam:artist': Variant('as', [str(track.get('artist', ''))]),
              'xesam:album': Variant('s', str(track.get('album', '')))}
    art = track.get('art', '')
    if art.startswith('file://'):
        result['mpris:artUrl'] = Variant('s', art)
    return result


class Root(ServiceInterface):
    def __init__(self, app):
        super().__init__('org.mpris.MediaPlayer2')
        self.app = app

    @method()
    def Raise(self):
        self.app.output({'event': 'raise'})

    @method()
    def Quit(self):
        raise DBusError('org.mpris.MediaPlayer2.Error.NotSupported', 'Use Quit in the player.')

    @dbus_property(access=PropertyAccess.READ)
    def CanQuit(self) -> 'b': return False
    @dbus_property(access=PropertyAccess.READ)
    def CanRaise(self) -> 'b': return True
    @dbus_property(access=PropertyAccess.READ)
    def HasTrackList(self) -> 'b': return False
    @dbus_property(access=PropertyAccess.READ)
    def Identity(self) -> 's': return 'Omarchy Bandcamp'
    @dbus_property(access=PropertyAccess.READ)
    def DesktopEntry(self) -> 's': return 'omarchy-bandcamp'
    @dbus_property(access=PropertyAccess.READ)
    def SupportedUriSchemes(self) -> 'as': return []
    @dbus_property(access=PropertyAccess.READ)
    def SupportedMimeTypes(self) -> 'as': return []


class Player(ServiceInterface):
    def __init__(self, app):
        super().__init__('org.mpris.MediaPlayer2.Player')
        self.app = app

    def command(self, cmd, **args):
        self.app.task(self.app.handle({'cmd': cmd, **args}))

    @method()
    def Next(self): self.command('next')
    @method()
    def Previous(self): self.command('previous')
    @method()
    def Pause(self): self.command('pause')
    @method()
    def PlayPause(self): self.command('toggle')
    @method()
    def Stop(self): self.command('stop')
    @method()
    def Play(self): self.command('play')
    @method()
    def Seek(self, Offset: 'x'):
        self.command('seek', position=self.app.state['position'] + Offset / 1_000_000)
    @method()
    def SetPosition(self, TrackId: 'o', Position: 'x'):
        if TrackId == track_path(self.app.state['current']) and Position >= 0:
            self.command('seek', position=Position / 1_000_000)
    @method()
    def OpenUri(self, Uri: 's'):
        raise DBusError('org.mpris.MediaPlayer2.Error.NotSupported', 'Choose an album from the collection.')
    @signal()
    def Seeked(self, Position: 'x') -> 'x': return Position

    @dbus_property(access=PropertyAccess.READ)
    def PlaybackStatus(self) -> 's':
        return 'Playing' if self.app.state['playing'] else 'Paused' if self.app.state['current'] else 'Stopped'
    @dbus_property()
    def LoopStatus(self) -> 's':
        return {'none': 'None', 'all': 'Playlist', 'one': 'Track'}[self.app.state['repeat']]
    @LoopStatus.setter
    def LoopStatus(self, value: 's'):
        mapping = {'None': 'none', 'Playlist': 'all', 'Track': 'one'}
        if value in mapping: self.command('repeat', mode=mapping[value])
    @dbus_property()
    def Rate(self) -> 'd': return 1.0
    @Rate.setter
    def Rate(self, value: 'd'):
        if value != 1.0:
            raise DBusError('org.freedesktop.DBus.Error.NotSupported', 'Playback rate is fixed.')
    @dbus_property()
    def Shuffle(self) -> 'b': return self.app.state['shuffle']
    @Shuffle.setter
    def Shuffle(self, value: 'b'): self.command('shuffle', enabled=value)
    @dbus_property(access=PropertyAccess.READ)
    def Metadata(self) -> 'a{sv}': return metadata(self.app.state['current'])
    @dbus_property()
    def Volume(self) -> 'd': return self.app.state['volume'] / 100.0
    @Volume.setter
    def Volume(self, value: 'd'): self.command('volume', value=value * 100)
    @dbus_property(access=PropertyAccess.READ)
    def Position(self) -> 'x': return int(self.app.state['position'] * 1_000_000)
    @dbus_property(access=PropertyAccess.READ)
    def MinimumRate(self) -> 'd': return 1.0
    @dbus_property(access=PropertyAccess.READ)
    def MaximumRate(self) -> 'd': return 1.0
    @dbus_property(access=PropertyAccess.READ)
    def CanGoNext(self) -> 'b':
        q = self.app.queue
        if not q.tracks:
            return False
        if q.repeat == 'all':
            return True
        return bool(q.remaining) if q.shuffle else q.index + 1 < len(q.tracks)
    @dbus_property(access=PropertyAccess.READ)
    def CanGoPrevious(self) -> 'b': return bool(self.app.queue.current)
    @dbus_property(access=PropertyAccess.READ)
    def CanPlay(self) -> 'b': return bool(self.app.queue.tracks) and self.app.state['connected']
    @dbus_property(access=PropertyAccess.READ)
    def CanPause(self) -> 'b': return bool(self.app.queue.current)
    @dbus_property(access=PropertyAccess.READ)
    def CanSeek(self) -> 'b': return self.app.state['duration'] > 0
    @dbus_property(access=PropertyAccess.READ)
    def CanControl(self) -> 'b': return True


class Mpris:
    def __init__(self, bus, app):
        self.bus = bus
        self.player = Player(app)
        bus.export(PATH, Root(app))
        bus.export(PATH, self.player)

    @classmethod
    async def connect(cls, app):
        bus = await MessageBus().connect()
        result = await bus.request_name(NAME, NameFlag.DO_NOT_QUEUE)
        if result != RequestNameReply.PRIMARY_OWNER:
            bus.disconnect()
            raise RuntimeError('Another Bandcamp player owns the media controls.')
        return cls(bus, app)

    def changed(self, patch):
        mapping = {'playing': 'PlaybackStatus', 'current': 'Metadata', 'volume': 'Volume',
                   'shuffle': 'Shuffle', 'repeat': 'LoopStatus'}
        props = {prop: getattr(self.player, prop) for key, prop in mapping.items() if key in patch}
        if any(key in patch for key in ('current', 'queue', 'index', 'repeat', 'shuffle', 'connected', 'duration')):
            for prop in ('CanGoNext', 'CanGoPrevious', 'CanPlay', 'CanPause', 'CanSeek'):
                props[prop] = getattr(self.player, prop)
        if props:
            self.player.emit_properties_changed(props)
