"""Resolve explicit record selections without touching the playback queue."""
def source_tracks(api, source):
    if not isinstance(source, dict) or source.get('kind') not in ('album', 'track'):
        raise ValueError('Select an album or track.')
    album_id = source.get('id') if source['kind'] == 'album' else source.get('albumId')
    if not album_id:
        raise ValueError('Missing album.')
    tracks = api.album(str(album_id)).get('song', [])
    if source['kind'] == 'track':
        tracks = [track for track in tracks if str(track.get('id')) == str(source.get('id'))]
        if len(tracks) != 1:
            raise ValueError('Track is no longer available.')
    return tracks
