"""Bandcamp's official Subsonic beta, using fresh salted auth per request."""
import hashlib
import json
import secrets
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

BASE = 'https://bandcamp.com/api/subsonic/rest'


class APIError(Exception):
    def __init__(self, message, auth=False):
        super().__init__(message)
        self.auth = auth


def decode_response(data):
    try:
        if data.lstrip().startswith(b'<'):
            root = ET.fromstring(data)
            if root.tag.rsplit('}', 1)[-1] != 'subsonic-response':
                raise ValueError('Not Subsonic')
            list_children = {'albumList2': {'album'}, 'album': {'song'},
                             'playlists': {'playlist'}, 'playlist': {'entry'},
                             'artists': {'index'}, 'index': {'artist'}, 'artist': {'album'}, 'genres': {'genre'}}
            def convert(node):
                result = dict(node.attrib)
                if node.text and node.text.strip():
                    result["value"] = node.text.strip()
                name = node.tag.rsplit('}', 1)[-1]
                for child in node:
                    key = child.tag.rsplit('}', 1)[-1]
                    value = convert(child)
                    if key in list_children.get(name, set()):
                        result.setdefault(key, []).append(value)
                    else:
                        result[key] = value
                return result
            response = convert(root)
        else:
            response = json.loads(data)['subsonic-response']
        if not isinstance(response, dict) or response.get('status') not in ('ok', 'failed'):
            raise ValueError('Missing status')
    except (ValueError, KeyError, TypeError, ET.ParseError):
        raise APIError('Bandcamp returned an unexpected response. Please try again.') from None
    if response['status'] == 'failed':
        code = str(response.get('error', {}).get('code', ''))
        if code in ('40', '41', '42', '43', '44'):
            raise APIError('Login was not accepted. Use the Subsonic credentials from Bandcamp Fan Settings.', auth=True)
        raise APIError(f'Bandcamp could not complete this request (code {code or "unknown"}).')
    return response


class BandcampAPI:
    def __init__(self, username, password):
        self.username = username.strip()
        self._password = password

    def url(self, action, params=None):
        salt = secrets.token_hex(12)
        query = dict(params or {})
        query.update(u=self.username, t=hashlib.md5((self._password + salt).encode()).hexdigest(),
                     s=salt, v='1.16.1', c='OmarchyBandcamp', f='json')
        return f'{BASE}/{action}.view?{urllib.parse.urlencode(query, doseq=True)}'

    def fetch(self, action, params=None, limit=16 * 1024 * 1024, post=False):
        url = self.url(action, params)
        body = None
        if post:
            url, query = url.split('?', 1)
            body = query.encode()
        request = urllib.request.Request(url, data=body, headers={
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': 'OmarchyBandcamp/0.1', 'Accept': 'application/json, application/xml, */*'})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read(limit + 1)
                if len(data) > limit:
                    raise APIError('Bandcamp response was too large.')
                return data
        except urllib.error.HTTPError as error:
            if error.code in (401, 403):
                raise APIError('Bandcamp login expired or was rejected. Please sign in again.', auth=True) from None
            raise APIError(f'Bandcamp is unavailable (HTTP {error.code}). Please try again.') from None
        except (urllib.error.URLError, TimeoutError, OSError):
            raise APIError('Cannot reach Bandcamp. Check your connection and try again.') from None

    def request(self, action, params=None, post=False):
        return decode_response(self.fetch(action, params, **({"post": True} if post else {})))

    def albums(self, page_size=100):
        albums, seen, offset = [], set(), 0
        while True:
            response = self.request('getAlbumList2', {'type': 'alphabeticalByArtist', 'size': page_size, 'offset': offset})
            page = response.get('albumList2', {}).get('album', [])
            if not page:
                return albums
            fresh = [a for a in page if str(a['id']) not in seen]
            if not fresh:
                raise APIError('Bandcamp repeated a collection page. Please retry the refresh.')
            for album in fresh:
                album['id'] = str(album['id'])
                seen.add(album['id'])
                albums.append(album)
            offset += len(page)

    def album(self, album_id):
        album = self.request('getAlbum', {'id': album_id}).get('album', {})
        tracks = album.get('song', [])
        for track in tracks:
            track['id'] = str(track['id'])
            track['albumId'] = str(track.get('albumId') or album_id)
            track['album'] = track.get('album') or album.get('name', '')
            track['artist'] = track.get('artist') or album.get('artist', '')
            track['coverArt'] = track.get('coverArt') or album.get('coverArt', '')
        album['song'] = tracks
        return album

    def playlists(self):
        return self.request('getPlaylists').get('playlists', {}).get('playlist', [])

    def playlist(self, playlist_id):
        result = self.request('getPlaylist', {'id': playlist_id}).get('playlist', {})
        result.setdefault('entry', [])
        return result

    def create_playlist(self, name, song_ids):
        name = str(name).strip()
        if not name:
            raise ValueError('Enter a playlist name.')
        return self.request('createPlaylist', {'name': name, 'songId': list(song_ids)}, post=True).get('playlist', {})

    def rename_playlist(self, playlist_id, name):
        name = str(name).strip()
        if not name:
            raise ValueError('Enter a playlist name.')
        self.request('updatePlaylist', {'playlistId': playlist_id, 'name': name}, post=True)

    def append_playlist(self, playlist_id, song_ids):
        self.request('updatePlaylist', {'playlistId': playlist_id, 'songIdToAdd': list(song_ids)}, post=True)

    def remove_playlist_track(self, playlist_id, index):
        if index < 0:
            raise ValueError('Invalid playlist index.')
        self.request('updatePlaylist', {'playlistId': playlist_id, 'songIndexToRemove': index}, post=True)

    def replace_playlist_tracks(self, playlist_id, song_ids):
        self.request('createPlaylist', {'playlistId': playlist_id, 'songId': list(song_ids)}, post=True)

    def delete_playlist(self, playlist_id):
        self.request('deletePlaylist', {'id': playlist_id}, post=True)
