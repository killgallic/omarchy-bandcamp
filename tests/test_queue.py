import unittest
from bandcamp.queue import Queue


class QueueTests(unittest.TestCase):
    def setUp(self):
        self.q = Queue()
        self.tracks = [{'id': str(i)} for i in range(3)]

    def test_eof_stops_at_end_without_restarting(self):
        self.q.replace(self.tracks, 2)
        self.assertIsNone(self.q.advance())
        self.assertEqual(self.q.index, 2)

    def test_repeat_one_applies_to_eof_but_not_manual_next(self):
        self.q.replace(self.tracks, 0)
        self.q.repeat = 'one'
        self.assertEqual(self.q.advance(automatic=True)['id'], '0')
        self.assertEqual(self.q.advance()['id'], '1')

    def test_repeat_all_wraps(self):
        self.q.replace(self.tracks, 2)
        self.q.repeat = 'all'
        self.assertEqual(self.q.advance()['id'], '0')

    def test_shuffle_does_not_repeat_current_and_visits_all(self):
        self.q.replace(self.tracks, 0)
        self.q.set_shuffle(True)
        played = ['0', self.q.advance()['id'], self.q.advance()['id']]
        self.assertEqual(set(played), {'0', '1', '2'})
        self.assertIsNone(self.q.advance())

    def test_invalid_index_does_not_corrupt_queue(self):
        self.q.replace(self.tracks, 1)
        with self.assertRaises(ValueError):
            self.q.select(-1)
        self.assertEqual(self.q.current['id'], '1')

    def test_enqueue_keeps_current(self):
        self.q.replace(self.tracks[:1], 0)
        self.q.append(self.tracks[1:])
        self.assertEqual(self.q.current['id'], '0')
        self.assertEqual(self.q.advance()['id'], '1')

    def test_previous_tracks_shuffle_history(self):
        self.q.replace(self.tracks, 0)
        self.q.set_shuffle(True)
        self.q.advance()
        self.assertEqual(self.q.previous()['id'], '0')
