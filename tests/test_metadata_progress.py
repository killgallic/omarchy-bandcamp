import tempfile
import unittest
from pathlib import Path
from bandcamp.metadata import MetadataCache

class MetadataProgress(unittest.IsolatedAsyncioTestCase):
    async def test_cached_tags_load_without_network_and_report_progress(self):
        with tempfile.TemporaryDirectory() as directory:
            async def request(path, params): raise AssertionError('network must not run')
            cache = MetadataCache(Path(directory)/'metadata.json', request=request)
            a = {'id':'a','artist':'A','name':'Album'}
            import hashlib, json
            key = hashlib.sha256(json.dumps(['a','album']).encode()).hexdigest()
            cache.entries[key] = {'expires':cache.clock()+100,'tags':['ambient']}
            patches,progress = [],[]
            result = await cache.enrich([a], lambda:True,lambda i,t:patches.append((i,t)), on_progress=progress.append, cached_only=True)
            self.assertEqual(patches, [('a',['ambient'])])
            self.assertEqual(result['cached'], 1)
            self.assertEqual(progress[-1]['processed'], 1)
            self.assertEqual(progress[-1]['total'], 1)
