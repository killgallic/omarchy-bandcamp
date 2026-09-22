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
                             'artists': {'index'}, 'index': {'artist'}, 'artist': {'album'}}
            def convert(node):
                result = dict(node.attrib)
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
        return f'{BASE}/{action}.view?{urllib.parse.urlencode(query)}'

    def fetch(self, action, params=None, limit=16 * 1024 * 1024):
        request = urllib.request.Request(self.url(action, params), headers={
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

    def request(self, action, params=None):
        return decode_response(self.fetch(action, params))

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
            track['album'] = track.get('album') or album.get('name', '')
            track['artist'] = track.get('artist') or album.get('artist', '')
            track['coverArt'] = track.get('coverArt') or album.get('coverArt', '')
        album['song'] = tracks
        return album
