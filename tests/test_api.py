import hashlib
import json
import unittest
from urllib.parse import parse_qs, urlsplit

from bandcamp.api import BandcampAPI, APIError, decode_response


class APITests(unittest.TestCase):
    def test_auth_uses_fresh_salt_and_never_plain_password(self):
        api = BandcampAPI('fan name', 'secret & password')
        first = parse_qs(urlsplit(api.url('ping')).query)
        second = parse_qs(urlsplit(api.url('ping')).query)
        self.assertNotIn('p', first)
        self.assertEqual(first['u'], ['fan name'])
        self.assertNotEqual(first['s'], second['s'])
        self.assertEqual(first['t'][0], hashlib.md5(('secret & password' + first['s'][0]).encode()).hexdigest())

    def test_json_and_namespaced_xml_have_same_list_shape(self):
        expected = {'status': 'ok', 'albumList2': {'album': [{'id': 'a', 'name': 'An album'}]}}
        self.assertEqual(decode_response(json.dumps({'subsonic-response': expected}).encode()), expected)
        xml = b'<subsonic-response xmlns="http://subsonic.org/restapi" status="ok"><albumList2><album id="a" name="An album"/></albumList2></subsonic-response>'
        self.assertEqual(decode_response(xml), expected)

    def test_auth_error_is_safe_and_identifiable(self):
        with self.assertRaises(APIError) as caught:
            decode_response(b'{"subsonic-response":{"status":"failed","error":{"code":40,"message":"secret token"}}}')
        self.assertTrue(caught.exception.auth)
        self.assertNotIn('secret token', str(caught.exception))

    def test_album_pagination_includes_all_pages(self):
        calls = []
        def request(action, params):
            calls.append(params['offset'])
            items = [{'id': str(i), 'name': str(i)} for i in range(params['offset'], min(params['offset'] + 2, 5))]
            return {'albumList2': {'album': items}}
        api = BandcampAPI('u', 'p')
        api.request = request
        self.assertEqual([a['id'] for a in api.albums(page_size=2)], ['0', '1', '2', '3', '4'])
        self.assertEqual(calls, [0, 2, 4, 5])

    def test_repeating_page_does_not_loop_forever(self):
        api = BandcampAPI('u', 'p')
        api.request = lambda *args: {'albumList2': {'album': [{'id': 'a'}]}}
        with self.assertRaises(APIError):
            api.albums(page_size=1)

    def test_empty_xml_collection_is_empty(self):
        result = decode_response(b'<subsonic-response status="ok"><albumList2/></subsonic-response>')
        self.assertEqual(result['albumList2'], {})

    def test_invalid_response_does_not_reveal_body(self):
        with self.assertRaises(APIError) as caught:
            decode_response(b'<html>private response</html>')
        self.assertNotIn('private response', str(caught.exception))


if __name__ == '__main__':
    unittest.main()
