"""Cached metadata should not rebuild the collection once per record."""
import os
import tempfile
import unittest
from unittest.mock import patch

from bandcamp.backend import App


class FakeMetadataCache:
    async def enrich(self, albums, enabled, on_patch, on_progress=None, **kwargs):
        for index, album in enumerate(albums):
            on_patch(album['id'], ['tag-' + str(index)])
            if on_progress:
                on_progress({'processed': index + 1, 'total': len(albums), 'enriched': index + 1})
        return {'notice': 'Tags ready', 'processed': len(albums), 'total': len(albums), 'enriched': len(albums)}


class MetadataBatchingTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.environment = patch.dict(os.environ, {'XDG_CONFIG_HOME': self.directory.name, 'XDG_CACHE_HOME': self.directory.name,
                                                    'XDG_STATE_HOME': self.directory.name})
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.events = []
        self.app = App(emit=self.events.append)
        self.app.api = object()
        self.app.generation = 1
        self.app.config.values['metadata_enrichment'] = True
        self.app.state['albums'] = [{'id': str(i), 'name': 'Album ' + str(i), 'artist': 'Artist'} for i in range(30)]
        self.app.metadata_cache = FakeMetadataCache()

    async def asyncTearDown(self):
        await self.app.close()

    async def test_cached_tags_patch_collection_once(self):
        self.app.start_metadata(mode='cached')
        await self.app.metadata_task
        album_events = [e['state']['albums'] for e in self.events if e.get('event') == 'state' and 'albums' in e['state']]
        self.assertEqual(len(album_events), 1)
        self.assertEqual(len([a for a in album_events[0] if a.get('tags')]), 30)
