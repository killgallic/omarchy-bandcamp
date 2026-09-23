import json
import tempfile
import unittest
from pathlib import Path
from urllib.error import HTTPError

from bandcamp.metadata import MetadataCache


ALBUM = {'id': 'local', 'artist': 'An Artist', 'name': 'An Album'}
MBID = '12345678-1234-1234-1234-123456789abc'


def group(artist='An Artist', title='An Album', id=MBID):
    return {'id': id, 'title': title, 'artist-credit': [{'name': artist}]}


class MetadataTests(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'metadata.json'
        self.now = 10000000.0
        self.calls = []
        self.responses = []
        self.patches = []

    async def request(self, path, params):
        self.calls.append((self.now, path, params))
        response = self.responses.pop(0)
        if isinstance(response, Exception):
            raise response
        return response

    async def sleep(self, delay):
        self.now += delay

    def cache(self):
        return MetadataCache(self.path, request=self.request, clock=lambda: self.now,
                             sleep=self.sleep)

    async def enrich(self, cache, albums=None, enabled=lambda: True):
        return await cache.enrich(albums or [ALBUM], enabled,
                                  lambda id, tags: self.patches.append((id, tags)))

    async def test_disabled_never_reads_network_or_patches(self):
        result = await self.enrich(self.cache(), enabled=lambda: False)
        self.assertEqual(self.calls, [])
        self.assertEqual(self.patches, [])
        self.assertEqual(result['enriched'], 0)

    async def test_exact_match_tags_persist_and_second_run_is_cached(self):
        self.responses = [{'release-groups': [group(' AN  ARTIST ', 'an album')], 'count': 1},
                          {'tags': [{'name': 'ambient', 'count': 4}, {'name': 'ambient', 'count': 1}, {'name': 'noise', 'count': -1}]}]
        await self.enrich(self.cache())
        self.assertEqual(self.patches, [('local', ['ambient'])])
        self.assertGreaterEqual(self.calls[1][0] - self.calls[0][0], 1)
        result = await self.enrich(self.cache())
        self.assertEqual(result['cached'], 1)
        self.assertEqual(len(self.calls), 2)
        self.assertNotIn('An Artist', self.path.read_text())

    async def test_wrong_artist_and_ambiguous_matches_are_negative_cached(self):
        for groups in [[group('Someone Else')], [group(), group(id='22345678-1234-1234-1234-123456789abc')]]:
            self.responses = [{'release-groups': groups, 'count': len(groups)}]
            cache = self.cache()
            cache.entries = {}
            await self.enrich(cache)
            await self.enrich(cache)
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(self.patches, [])

    async def test_truncated_results_rejected(self):
        self.responses = [{'release-groups': [group()], 'count': 101}]
        await self.enrich(self.cache())
        self.assertEqual(self.patches, [])
        self.assertEqual(len(self.calls), 1)

    async def test_rate_limit_stops_run_and_respects_retry_after(self):
        self.responses = [HTTPError('https://musicbrainz.org', 429, 'limited', {'Retry-After': '120'}, None)]
        cache = self.cache()
        result = await self.enrich(cache, [ALBUM, dict(ALBUM, id='other', name='Other')])
        self.assertIn('later', result['notice'])
        self.assertEqual(len(self.calls), 1)
        await self.enrich(cache)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(cache.entries, {})

    async def test_disable_between_requests_prevents_lookup_and_patch(self):
        self.responses = [{'release-groups': [group()], 'count': 1}]
        await self.enrich(self.cache(), enabled=lambda: not self.calls)
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(self.patches, [])

    async def test_negative_cache_expires_after_seven_days(self):
        self.responses = [{'release-groups': [], 'count': 0}] * 2
        cache = self.cache()
        await self.enrich(cache)
        self.now += 7 * 86400 + 1
        await self.enrich(cache)
        self.assertEqual(len(self.calls), 2)

    async def test_corrupt_cache_does_not_break_enrichment(self):
        self.path.write_text('{"bad":42}')
        self.responses = [{'release-groups': [], 'count': 0}]
        await self.enrich(self.cache())
        self.assertEqual(len(self.calls), 1)

    async def test_positive_cache_expires_after_thirty_days(self):
        self.responses = [{'release-groups': [group()], 'count': 1},
                          {'tags': [{'name': 'ambient', 'count': 1}]},
                          {'release-groups': [], 'count': 0}]
        cache = self.cache()
        await self.enrich(cache)
        self.now += 8 * 86400
        await self.enrich(cache)
        self.assertEqual(len(self.calls), 2)
        self.now += 23 * 86400
        await self.enrich(cache)
        self.assertEqual(len(self.calls), 3)

    async def test_duplicate_album_names_share_cache_without_account_data(self):
        self.responses = [{'release-groups': [group()], 'count': 1},
                          {'tags': [{'name': 'ambient', 'count': 1}]}]
        await self.enrich(self.cache(), [ALBUM, dict(ALBUM, id='another-local-id')])
        self.assertEqual(len(self.calls), 2)
        self.assertEqual(len(self.patches), 2)
        self.assertNotIn('another-local-id', self.path.read_text())

    async def test_malformed_response_is_not_negative_cached(self):
        self.responses = [{'wrong': []}]
        cache = self.cache()
        result = await self.enrich(cache)
        self.assertEqual(cache.entries, {})
        self.assertIn('unavailable', result['notice'])

    async def test_cache_is_bounded_and_ignores_expired_entries(self):
        cache = self.cache()
        cache.entries = {format(i, '064x'): {'expires': self.now + 100, 'tags': ['x' * 64] * 32}
                         for i in range(1500)}
        cache.entries['f' * 64] = {'expires': self.now - 1, 'tags': ['expired']}
        cache._save()
        self.assertLessEqual(len(cache.entries), 1000)
        self.assertLessEqual(self.path.stat().st_size, 1024 * 1024)
        self.assertNotIn('expired', self.path.read_text())

    async def test_query_escapes_lucene_operators(self):
        self.responses = [{'release-groups': [], 'count': 0}]
        await self.enrich(self.cache(), [dict(ALBUM, name='A "quote" OR *')])
        query = self.calls[0][2]['query']
        self.assertIn('\\"quote\\"', query)
        self.assertIn('\\*', query)

    async def test_http_date_retry_after(self):
        from email.utils import formatdate
        self.responses = [HTTPError('https://musicbrainz.org', 503, 'busy',
                                   {'Retry-After': formatdate(self.now + 3600, usegmt=True)}, None)]
        cache = self.cache()
        await self.enrich(cache)
        self.assertEqual(cache._retry_at, self.now + 3600)

    async def test_cooldown_still_applies_cached_tags(self):
        self.responses = [{'release-groups': [group()], 'count': 1},
                          {'tags': [{'name': 'ambient', 'count': 1}]},
                          HTTPError('https://musicbrainz.org', 429, 'busy', {'Retry-After': '120'}, None)]
        cache = self.cache()
        await self.enrich(cache)
        self.patches.clear()
        await self.enrich(cache, [dict(ALBUM, id='missing', name='Unknown')])
        result = await self.enrich(cache, [dict(ALBUM, id='missing', name='Unknown'), ALBUM])
        self.assertEqual(self.patches, [('local', ['ambient'])])
        self.assertEqual(result['cached'], 1)
        self.assertEqual(len(self.calls), 3)
