import tempfile
import unittest
from pathlib import Path
from bandcamp.cache import Cache

class CacheControls(unittest.TestCase):
    def test_prune_and_clear_only_cache_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for i in range(4):
                (root / f'{i:064x}.img').write_bytes(b'x' * 40)
            (root / 'metadata.json').write_text('metadata')
            (root / 'unrelated.json').write_text('keep')
            cache = Cache(root)
            cache.prune_artwork(100)
            self.assertLessEqual(cache.stats()['artwork_bytes'], 100)
            cache.clear('artwork')
            self.assertEqual(cache.stats()['artwork_bytes'], 0)
            self.assertTrue((root / 'metadata.json').exists())
            cache.clear('metadata')
            self.assertFalse((root / 'metadata.json').exists())
            self.assertTrue((root / 'unrelated.json').exists())

    def test_total_budget_reserves_profile_metadata_and_collection(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            (root/'metadata.json').write_bytes(b'm'*40)
            (root/('profile-'+'a'*64+'.img')).write_bytes(b'p'*30)
            (root/('library-'+'b'*64+'.json')).write_bytes(b'c'*20)
            (root/('c'*64+'.img')).write_bytes(b'i'*40)
            (root/('d'*64+'.img')).write_bytes(b'i'*40)
            cache=Cache(root)
            cache.prune_total(120)
            self.assertLessEqual(cache.stats()['total_bytes'],120)
            self.assertEqual(cache.stats()['metadata_bytes'],40)
            self.assertEqual(cache.stats()['collection_bytes'],20)

    def test_many_account_snapshots_stay_within_total_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for i in range(9): (root/('library-'+f'{i:064x}'+'.json')).write_bytes(b'c'*(4*1024*1024))
            cache=Cache(root);cache.prune_total(32*1024*1024)
            self.assertLessEqual(cache.stats()['total_bytes'],32*1024*1024)
