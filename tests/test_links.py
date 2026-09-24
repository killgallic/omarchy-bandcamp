import unittest
from bandcamp.links import match_public_links
class LinkTests(unittest.TestCase):
    def test_only_unique_exact_public_matches_and_safe_urls(self):
        albums=[{'id':'1','artist':'A','name':'An Album'},{'id':'2','artist':'B','name':'Ambiguous'},{'id':'3','artist':'B','name':'Ambiguous'}]
        public=[{'band_name':'A','item_title':'An Album','item_url':'https://a.bandcamp.com/album/an-album'},
                {'band_name':'B','item_title':'Ambiguous','item_url':'https://b.bandcamp.com/album/ambiguous'},
                {'band_name':'A','item_title':'Wrong','item_url':'https://evil.example/album/wrong'}]
        result=match_public_links(albums,public)
        self.assertEqual(result['1']['releaseUrl'],'https://a.bandcamp.com/album/an-album')
        self.assertEqual(result['1']['artistUrl'],'https://a.bandcamp.com/')
        self.assertNotIn('2',result)
        self.assertNotIn('3',result)
    def test_subsonic_release_id_matches_public_tralbum_id_even_if_title_differs(self):
        album={'id':'a:12345','artist':'Original credit','name':'Different edition'}
        public=[{'tralbum_type':'a','tralbum_id':12345,'band_name':'Label','item_title':'Release', 'item_url':'https://label.bandcamp.com/album/release'}]
        self.assertEqual(match_public_links([album],public)['a:12345']['releaseUrl'],public[0]['item_url'])
