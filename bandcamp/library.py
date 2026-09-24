"""Account-separated, bounded snapshot for a read-only collection preview."""
import hashlib
import json
import os
import tempfile
import time
from pathlib import Path

FIELDS = ('id','name','artist','coverArt','songCount','year','genre','created','playCount')
MAX_BYTES = 4 * 1024 * 1024
class LibraryCache:
    def __init__(self, root=None):
        self.root = Path(root) if root else Path(os.environ.get('XDG_CACHE_HOME',Path.home()/'.cache'))/'omarchy-bandcamp'
    def path(self, account):
        return self.root/('library-'+hashlib.sha256(account.encode()).hexdigest()+'.json')
    def load(self, account):
        try:
            path=self.path(account)
            if path.stat().st_size > MAX_BYTES: return None
            data=json.loads(path.read_text())
            if (not isinstance(data,dict) or data.get('version') != 1 or not isinstance(data.get('albums'),list)
                or not isinstance(data.get('updatedAt'),(int,float)) or len(data['albums'])>100000): return None
            return {'albums':[{key:value for key,value in album.items() if key in FIELDS} for album in data['albums'] if isinstance(album,dict) and isinstance(album.get('id'),str) and album.get('id')],'updatedAt':data['updatedAt']}
        except (OSError,ValueError,TypeError,KeyError,AttributeError): return None
    def save(self, account, albums):
        data=json.dumps({'version':1,'updatedAt':int(time.time()),'albums':[{key:value for key,value in album.items() if key in FIELDS} for album in albums]},separators=(',',':')).encode()
        if len(data)>MAX_BYTES: return
        self.root.mkdir(mode=0o700,parents=True,exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=self.root,delete=False) as output:
            temporary=Path(output.name)
            try:
                output.write(data)
                output.flush();os.fsync(output.fileno())
                temporary.chmod(0o600)
                temporary.replace(self.path(account))
            finally: temporary.unlink(missing_ok=True)
    def clear(self):
        for path in self.root.glob('library-'+'[0-9a-f]'*64+'.json'):
            path.unlink(missing_ok=True)
