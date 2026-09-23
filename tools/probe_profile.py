"""Read-only profile capability check, without logging account identifiers."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from bandcamp import credentials
from bandcamp.api import BandcampAPI,APIError
saved=credentials.load()
if not saved: raise SystemExit('No remembered login')
api=BandcampAPI(saved['username'],saved['password'])
try:
    data=api.request('getUser',{'username':api.username})
    print(json.dumps({'user_fields':sorted(data.get('user',{}))}))
except APIError as e: print(str(e))
try:
    data=api.fetch('getAvatar',{'username':api.username},limit=4*1024*1024)
    print(json.dumps({'avatar_image':data.startswith((b'\xff\xd8',b'\x89PNG',b'RIFF')),'size':len(data)}))
except APIError as e: print(str(e))
import urllib.request,urllib.parse,re
try:
    user=api.request('getUser',{'username':api.username}).get('user',{})
    name=user.get('username','')
    print(json.dumps({'returned_username_matches_login':name==api.username}))
    url='https://bandcamp.com/'+urllib.parse.quote(name,safe='')
    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'OmarchyBandcamp/0.2'}),timeout=15) as response:
        page=response.read(2*1024*1024).decode()
    print(json.dumps({'profile_has_og_image':bool(re.search('property="og:image"',page)),'profile_has_fan_data': 'fan_data' in page}))
except Exception as e: print(json.dumps({'public_profile_error_type':type(e).__name__}))
