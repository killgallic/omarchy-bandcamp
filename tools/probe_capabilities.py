"""Read-only capability probe; never print credentials or authenticated URLs."""
import json
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bandcamp import credentials
from bandcamp.api import BandcampAPI, APIError

saved = credentials.load()
if not saved:
    print('No remembered app login; capability probing needs a saved login.')
    raise SystemExit(0)
api = BandcampAPI(saved['username'], saved['password'])
for kind in ('alphabeticalByArtist', 'newest', 'frequent', 'recent'):
    try:
        result = api.request('getAlbumList2', {'type': kind, 'size': 3, 'offset': 0})
        items = result.get('albumList2', {}).get('album', [])
        print(json.dumps({'sort': kind, 'count': len(items), 'fields': sorted(set().union(*(i.keys() for i in items))),
                          'has_genre': any(bool(i.get('genre')) for i in items), 'has_tags': any(bool(i.get('tags')) for i in items)}))
    except APIError as error:
        print(json.dumps({'sort': kind, 'error': str(error)}))
for action in ('getGenres', 'getPlaylists'):
    try:
        result = api.request(action)
        print(json.dumps({'endpoint': action, 'fields': sorted(result), 'counts': {k: len(v) for k,v in result.items() if isinstance(v, (list, dict))}}))
    except APIError as error:
        print(json.dumps({'endpoint': action, 'error': str(error)}))
try:
    sample = api.request('getAlbumList2', {'type': 'alphabeticalByArtist', 'size': 3, 'offset': 0}).get('albumList2', {}).get('album', [])
    if sample:
        details = api.album(sample[0]['id'])
        print(json.dumps({'album_detail_fields': sorted(details), 'track_fields': sorted(set().union(*(x.keys() for x in details.get('song', []))))}))
        print(json.dumps({'genre_examples': [x.get('genre') for x in sample], 'created_formats': [str(x.get('created', ''))[:10] for x in sample]}))
        try:
            info = api.request('getAlbumInfo2', {'id': sample[0]['id']})
            print(json.dumps({'album_info_fields': sorted(info), 'info_keys': {k: sorted(v) for k,v in info.items() if isinstance(v, dict)}}))
        except APIError as e:
            print(json.dumps({'album_info_error': str(e)}))
    import urllib.request, urllib.parse
    full = urllib.parse.urlsplit(api.url('getPlaylists'))
    req = urllib.request.Request(urllib.parse.urlunsplit((full.scheme,full.netloc,full.path,'','')), data=full.query.encode(), headers={'Content-Type':'application/x-www-form-urlencoded'})
    from bandcamp.api import decode_response
    with urllib.request.urlopen(req, timeout=20) as response:
        print(json.dumps({'form_post_status': decode_response(response.read())['status']}))
except Exception as e:
    print(json.dumps({'probe_error_type': type(e).__name__}))
