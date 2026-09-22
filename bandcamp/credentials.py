"""Generated Subsonic credentials live in Secret Service, never config files."""
import json
import subprocess

ATTRIBUTES = ['application', 'omarchy-bandcamp']


def load():
    try:
        result = subprocess.run(['secret-tool', 'lookup', *ATTRIBUTES], capture_output=True,
                                text=True, timeout=5)
        data = json.loads(result.stdout) if result.returncode == 0 else {}
        if isinstance(data, dict) and data.get('username') and data.get('password'):
            return data
    except (OSError, ValueError, subprocess.TimeoutExpired):
        pass
    return None


def save(username, password):
    try:
        result = subprocess.run(['secret-tool', 'store', '--label=Omarchy Bandcamp', *ATTRIBUTES],
                                input=json.dumps({'username': username, 'password': password}),
                                capture_output=True, text=True, timeout=30)
        return result.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def clear():
    try:
        return subprocess.run(['secret-tool', 'clear', *ATTRIBUTES], capture_output=True, timeout=5).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False
