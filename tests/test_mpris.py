import unittest
from bandcamp.mpris import metadata, track_path


class MetadataTests(unittest.TestCase):
    def test_metadata_does_not_publish_authenticated_urls(self):
        track = {'id': 'track/with:punctuation', 'title': 'Song', 'artist': 'Artist', 'album': 'Album',
                 'duration': '123.5', 'art': 'file:///tmp/cover.jpg',
                 'url': 'https://bandcamp.com/stream?password=secret'}
        result = metadata(track)
        self.assertEqual(result['mpris:length'].value, 123500000)
        self.assertEqual(result['xesam:artist'].value, ['Artist'])
        self.assertNotIn('xesam:url', result)
        self.assertNotIn('secret', repr(result))
        self.assertRegex(track_path(track), r'^/org/mpris/MediaPlayer2/track/[a-f0-9]+$')

    def test_empty_player_has_no_track(self):
        self.assertEqual(metadata({}), {})
