"""Read-only, silent real-stream transition diagnostic; no URLs in output."""
import asyncio,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from bandcamp import credentials
from bandcamp.api import BandcampAPI
from bandcamp.backend import App,public_item
from bandcamp.mpv import Mpv
async def main():
    saved=await asyncio.to_thread(credentials.load)
    if not saved: return
    api=BandcampAPI(saved['username'],saved['password'])
    albums=await asyncio.to_thread(api.albums)
    tracks=[]
    for album in albums[:4]:
        detail=await asyncio.to_thread(api.album,album['id'])
        tracks=detail.get('song',[])[:2]
        if len(tracks)==2: break
    app=App(emit=lambda event:None)
    def event(value):
        if value.get('event') in ('end-file','file-loaded','start-file','shutdown'):
            print(json.dumps({k:v for k,v in value.items() if k in ('event','reason','error','playlist_entry_id','playlist_insert_id','playlist_insert_num_entries')}),flush=True)
        app.mpv_event(value)
    app.api=api
    app.player=Mpv(event,('--ao=null',))
    app.queue.replace([public_item(t) for t in tracks])
    try:
        await app.play_current()
        async with asyncio.timeout(45):
            while not app.media_loaded: await asyncio.sleep(.1)
            print('First stream loaded; seeking near end.',flush=True)
            await app.player.command('seek',max(0,float(tracks[0]['duration'])-2),'absolute')
            while app.state['index']!=1 or not app.media_loaded: await asyncio.sleep(.1)
        print('Automatic next stream loaded.',flush=True)
    except Exception as e:
        print(json.dumps({'failure':type(e).__name__,'index':app.state['index'],'playing':app.state['playing'],'error':app.state['error']}),flush=True)
    finally: await app.close()
asyncio.run(main())
