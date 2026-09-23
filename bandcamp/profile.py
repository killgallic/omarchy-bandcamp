"""Cache a public Bandcamp profile photo; authenticated URLs never reach QML."""
import hashlib
from html.parser import HTMLParser
import os
from pathlib import Path
import time
import urllib.parse
import urllib.request

class ProfileImage(HTMLParser):
    def __init__(self):
        super().__init__()
        self.image = ''
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'meta' and attrs.get('property') == 'og:image':
            self.image = attrs.get('content', '')

def load_profile(api, url=''):
    if not url:
        return {'art': '', 'notice': 'Add your public Bandcamp profile URL in Settings to show your photo.'}
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != 'https' or parsed.netloc != 'bandcamp.com':
        return {'art': ''}
    cache = Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'omarchy-bandcamp'
    path = cache / ('profile-' + hashlib.sha256(url.encode()).hexdigest() + '.img')
    try:
        if not path.exists() or time.time() - path.stat().st_mtime > 7 * 86400:
            request = urllib.request.Request(url, headers={'User-Agent': 'OmarchyBandcamp/0.2'})
            with urllib.request.urlopen(request, timeout=15) as response:
                page = response.read(2 * 1024 * 1024).decode('utf-8')
            parser = ProfileImage()
            parser.feed(page)
            image_url = urllib.parse.urlsplit(parser.image)
            if image_url.scheme != 'https' or image_url.hostname != 'f4.bcbits.com':
                return {'art': '', 'url': url, 'notice': 'No profile image was available.'}
            with urllib.request.urlopen(parser.image, timeout=15) as response:
                data = response.read(4 * 1024 * 1024 + 1)
            if len(data) > 4 * 1024 * 1024 or not data.startswith((b'\xff\xd8', b'\x89PNG', b'RIFF')):
                return {'art': '', 'url': url}
            cache.mkdir(parents=True, exist_ok=True)
            temporary = path.with_suffix('.tmp')
            temporary.write_bytes(data)
            temporary.chmod(0o600)
            temporary.replace(path)
        return {'art': path.as_uri(), 'url': url}
    except (OSError, ValueError, UnicodeError):
        return {'art': path.as_uri() if path.exists() else '', 'url': url,
                'notice': 'The public profile photo could not be refreshed.'}
