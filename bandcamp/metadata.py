"""Optional public MusicBrainz tags; never receives account credentials.

API/rate policy: https://musicbrainz.org/doc/MusicBrainz_API
Searches names, then looks up unambiguous release groups with inc=tags.
The caller supplies live consent and owns cancellation/account generation checks.
"""
import asyncio
import hashlib
import json
import math
import os
import re
import tempfile
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from email.utils import parsedate_to_datetime
from pathlib import Path

BASE = 'https://musicbrainz.org/ws/2/'
USER_AGENT = 'OmarchyBandcamp/0.1 (personal desktop collection player)'
MAX_BYTES = 1024 * 1024
MAX_ENTRIES = 1000
POSITIVE_TTL = 30 * 86400
NEGATIVE_TTL = 7 * 86400
MBID = re.compile(r'^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$')


def normalize(value):
    return ' '.join(unicodedata.normalize('NFKC', str(value)).casefold().split())


def clean_tags(values):
    return list(dict.fromkeys(value.strip() for value in values
                             if isinstance(value, str) and 0 < len(value.strip()) <= 64))[:32]


class MetadataCache:
    def __init__(self, path=None, *, request=None, clock=time.time, sleep=asyncio.sleep):
        self.path = Path(path) if path is not None else Path(
            os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'omarchy-bandcamp' / 'metadata.json'
        self.request = request or self._request
        self.clock = clock
        self.sleep = sleep
        self.entries = {}
        self._next_request = 0
        self._retry_at = 0
        self._lock = asyncio.Lock()
        self._load()

    def _load(self):
        try:
            if self.path.stat().st_size > MAX_BYTES:
                return
            data = json.loads(self.path.read_text())
            if not isinstance(data, dict):
                return
            entries = data.get('entries', {})
            if not isinstance(entries, dict):
                return
            for key, entry in list(entries.items())[-MAX_ENTRIES:]:
                if (not isinstance(key, str) or not re.fullmatch('[0-9a-f]{64}', key)
                        or not isinstance(entry, dict) or not isinstance(entry.get('tags'), list)):
                    continue
                expires = entry.get('expires')
                if (isinstance(expires, (int, float)) and math.isfinite(expires)
                        and self.clock() < expires <= self.clock() + POSITIVE_TTL):
                    self.entries[key] = {'expires': expires, 'tags': clean_tags(entry['tags'])}
        except (OSError, ValueError, TypeError):
            pass

    def _save(self):
        kept = {}
        size = len(b'{"entries":{}}')
        for key, entry in reversed(list(self.entries.items())):
            if entry['expires'] <= self.clock():
                continue
            item_size = len(json.dumps({key: entry}, separators=(',', ':')).encode())
            if len(kept) >= MAX_ENTRIES or size + item_size > MAX_BYTES:
                continue
            kept[key] = entry
            size += item_size
        self.entries = dict(reversed(list(kept.items())))
        data = json.dumps({'entries': self.entries}, separators=(',', ':')).encode()
        temporary = None
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            with tempfile.NamedTemporaryFile(dir=self.path.parent, prefix='.metadata-', delete=False) as stream:
                temporary = stream.name
                stream.write(data)
            os.replace(temporary, self.path)
        except OSError:
            pass  # Cache persistence must not interrupt playback or enrichment.
        finally:
            if temporary and os.path.exists(temporary):
                try:
                    os.unlink(temporary)
                except OSError:
                    pass

    @staticmethod
    async def _request(path, params):
        def fetch():
            query = urllib.parse.urlencode(dict(params, fmt='json'))
            request = urllib.request.Request(BASE + path + '?' + query,
                                             headers={'User-Agent': USER_AGENT, 'Accept': 'application/json'})
            with urllib.request.urlopen(request, timeout=15) as response:
                data = response.read(MAX_BYTES + 1)
                if len(data) > MAX_BYTES:
                    raise ValueError('Metadata response too large')
                result = json.loads(data)
                if not isinstance(result, dict):
                    raise ValueError('Invalid metadata response')
                return result
        return await asyncio.to_thread(fetch)

    async def _get(self, path, params, enabled):
        delay = self._next_request - self.clock()
        if delay > 0:
            await self.sleep(delay)
        if not enabled():
            return None
        self._next_request = self.clock() + 1.05
        return await self.request(path, params)

    def _rate_limit(self, error):
        retry = error.headers.get('Retry-After', '') if error.headers else ''
        try:
            seconds = float(retry)
            if not math.isfinite(seconds):
                raise ValueError()
        except ValueError:
            try:
                seconds = parsedate_to_datetime(retry).timestamp() - self.clock()
            except (ValueError, TypeError, OverflowError):
                seconds = 60
        self._retry_at = self.clock() + max(60, seconds)

    async def enrich(self, albums, enabled, on_patch):
        """Apply tags serially while enabled(); return enriched/cached counts and notice.

        on_patch(album_id, list[str]) is synchronous. Disabled runs do not apply even
        cached tags. Network and parse errors never become cached negative matches.
        """
        result = {'enriched': 0, 'cached': 0, 'notice': ''}
        async with self._lock:
            if not enabled():
                return result
            for album in albums:
                if not enabled():
                    break
                artist = normalize(album.get('artist', ''))
                title = normalize(album.get('name') or album.get('title') or '')
                if not artist or not title or not album.get('id'):
                    continue
                key = hashlib.sha256(json.dumps([artist, title]).encode()).hexdigest()
                cached = self.entries.get(key)
                if cached and cached['expires'] > self.clock():
                    tags = cached['tags']
                    result['cached'] += 1
                else:
                    if self.clock() < self._retry_at:
                        result['notice'] = 'MusicBrainz is busy. Try enrichment again later.'
                        continue
                    try:
                        # Escape the complete Lucene phrase, never interpolate raw syntax.
                        escape = lambda value: re.sub(r'([+\-!(){}\[\]^"~*?:\\/&|])', r'\\\1', value)
                        query = f'releasegroup:"{escape(title)}" AND artistname:"{escape(artist)}"'
                        search = await self._get('release-group/', {'query': query, 'limit': 100}, enabled)
                        if search is None or not enabled():
                            break
                        groups = search.get('release-groups')
                        if not isinstance(groups, list):
                            raise ValueError('Invalid search')
                        matches = set()
                        for group in groups:
                            credit = ''.join(part.get('name', part.get('artist', {}).get('name', ''))
                                             + part.get('joinphrase', '') for part in group.get('artist-credit', []))
                            if normalize(group.get('title', '')) == title and normalize(credit) == artist:
                                id = group.get('id', '')
                                if MBID.fullmatch(id):
                                    matches.add(id)
                        tags = []
                        # Never accept a result set that may hide a second exact match.
                        if len(matches) == 1 and int(search.get('count', len(groups))) <= len(groups):
                            detail = await self._get('release-group/' + next(iter(matches)), {'inc': 'tags'}, enabled)
                            if detail is None or not enabled():
                                break
                            raw = detail.get('tags', [])
                            if not isinstance(raw, list):
                                raise ValueError('Invalid tags')
                            tags = clean_tags(tag.get('name') for tag in raw
                                              if isinstance(tag, dict) and int(tag.get('count', 0)) > 0)
                        self.entries[key] = {'expires': self.clock() + (POSITIVE_TTL if tags else NEGATIVE_TTL), 'tags': tags}
                        self._save()
                    except urllib.error.HTTPError as error:
                        if error.code in (429, 503) or (error.headers and error.headers.get('Retry-After')):
                            self._rate_limit(error)
                            result['notice'] = 'MusicBrainz is busy. Try enrichment again later.'
                            continue
                        else:
                            result['notice'] = 'MusicBrainz metadata is temporarily unavailable.'
                        break
                    except (OSError, ValueError, TypeError, KeyError, AttributeError):
                        result['notice'] = 'MusicBrainz metadata is temporarily unavailable.'
                        break
                if tags and enabled():
                    on_patch(album['id'], list(tags))
                    result['enriched'] += 1
            if not result['notice'] and enabled():
                result['notice'] = f"MusicBrainz tags available for {result['enriched']} records."
        return result
