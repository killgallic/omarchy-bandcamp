"""Verified links from the first page of an explicitly supplied public fan profile."""
import json
import hashlib
import os
import time
from pathlib import Path
from collections import Counter
from html.parser import HTMLParser
from urllib.parse import urlsplit, urlunsplit
import urllib.request

class PublicCollection(HTMLParser):
    def __init__(self):
        super().__init__()
        self.items = []
    def handle_starttag(self, tag, attrs):
        for _, value in attrs:
            if value and len(value) <= 2_000_000 and 'item_cache' in value:
                try:
                    data = json.loads(value)
                    cache = data.get('item_cache', {}).get('collection', {})
                    if isinstance(cache, dict):
                        self.items = list(cache.values())[:100]
                        self.data = data
                except (ValueError, TypeError, AttributeError): pass

def canonical(value):
    if not isinstance(value, str): return ''
    parsed = urlsplit(value)
    host = (parsed.hostname or '').lower()
    if parsed.scheme != 'https' or not (host == 'bandcamp.com' or host.endswith('.bandcamp.com')) or parsed.username or parsed.password:
        return ''
    if not parsed.path.startswith(('/album/', '/track/')): return ''
    return urlunsplit(('https', host, parsed.path, '', ''))

def match_public_links(albums, public):
    def key(artist,title): return (str(artist).casefold().strip(),str(title).casefold().strip())
    counts = Counter(key(a.get('artist',''),a.get('name','')) for a in albums)
    public_counts = Counter(key(p.get('band_name',''),p.get('item_title','')) for p in public)
    lookup = {key(p.get('band_name',''),p.get('item_title','')):p for p in public}
    by_id = {}
    for item in public:
        if str(item.get('tralbum_type','')) == 'a' and str(item.get('tralbum_id','')).isdigit():
            by_id.setdefault('a:'+str(item['tralbum_id']),[]).append(item)
    links = {}
    for album in albums:
        ident = str(album.get('id',''))
        matches = by_id.get(ident,[])
        urls = {canonical(item.get('item_url')) for item in matches}
        urls.discard('')
        if len(urls)==1:
            url=next(iter(urls))
            source='Public Bandcamp collection · release ID'
        else:
            k=key(album.get('artist',''),album.get('name',''))
            if counts[k] != 1 or public_counts[k] != 1: continue
            url=canonical(lookup[k].get('item_url'))
            if not url: continue
            source='Public Bandcamp collection · artist/title'
        parsed=urlsplit(url)
        links[ident]={'releaseUrl':url,'artistUrl':urlunsplit(('https',parsed.netloc,'/','','')),'linkSource':source}
        dated=next((item.get('purchased') for item in matches if item.get('purchased')), None)
        if dated: links[ident]['purchasedAt']=str(dated)[:80]
    return links

def load_public_links(url, albums, account=''):
    """Fetch a public fan collection, then persist only verified canonical links."""
    if not url or urlsplit(url).netloc != 'bandcamp.com': return {}
    cache_root = Path(os.environ.get('XDG_CACHE_HOME', Path.home()/'.cache'))/'omarchy-bandcamp'
    cache_path = cache_root/('links-'+hashlib.sha256((account+':'+url).encode()).hexdigest()+'.json')
    try:
        if time.time()-cache_path.stat().st_mtime < 7*86400 and cache_path.stat().st_size < 2_000_000:
            saved=json.loads(cache_path.read_text())
            if saved.get('version')==3 and isinstance(saved.get('links'),dict):
                restored = {}
                for album in albums:
                    ident = str(album['id'])
                    item = saved['links'].get(ident)
                    if not isinstance(item,dict): continue
                    release = canonical(item.get('releaseUrl'))
                    if not release: continue
                    parsed = urlsplit(release)
                    restored[ident] = {'releaseUrl':release,
                                       'artistUrl':urlunsplit(('https',parsed.netloc,'/','','')),
                                       'linkSource':'Cached public Bandcamp collection'}
                    if isinstance(item.get('purchasedAt'),str):
                        restored[ident]['purchasedAt']=item['purchasedAt'][:80]
                return restored
    except (OSError,ValueError,TypeError,KeyError,AttributeError): pass
    request = urllib.request.Request(url, headers={'User-Agent':'OmarchyBandcamp/0.3'})
    with urllib.request.urlopen(request,timeout=15) as response:
        page=response.read(2_000_001)
    if len(page)>2_000_000: return {}
    parser=PublicCollection();parser.feed(page.decode('utf-8','replace'))
    public=list(parser.items)
    try:
        data=parser.data
        fan_id=data['fan_data']['fan_id']; token=data['collection_data']['last_token']
        target=min(int(data['collection_data'].get('item_count',len(public))),1000)
        seen={token}
        for _ in range(8):
            if len(public)>=target or not token: break
            payload=json.dumps({'fan_id':fan_id,'older_than_token':token,'count':100}).encode()
            req=urllib.request.Request('https://bandcamp.com/api/fancollection/1/collection_items',data=payload,headers={'Content-Type':'application/json','User-Agent':'OmarchyBandcamp/0.3'})
            with urllib.request.urlopen(req,timeout=15) as response:
                raw=response.read(2_000_001)
            if len(raw)>2_000_000: break
            result=json.loads(raw)
            items=result.get('items',[])
            if not isinstance(items,list) or not items: break
            public.extend(items[:100]);token=result.get('last_token','')
            if not result.get('more_available') or token in seen: break
            seen.add(token)
    except (OSError,ValueError,TypeError,KeyError,AttributeError):
        pass  # Initial public page still supplies some verified links.
    links=match_public_links(albums,public)
    try:
        cache_root.mkdir(parents=True,exist_ok=True,mode=0o700)
        temporary=cache_path.with_suffix('.tmp')
        temporary.write_text(json.dumps({'version':3,'links':links},separators=(',',':')))
        temporary.chmod(0o600);temporary.replace(cache_path)
    except OSError: pass
    return links
