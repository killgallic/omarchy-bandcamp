.pragma library
var presets = {
    compact: '{Artist} — {Song Name}', track: '{Song Name}',
    full: '{Artist} — {Album} — {Song Name}', record: '{Artist} — {Album}'
}
function render(template, track, playing) {
    if (!track || !(track.title || track.name || track.artist)) return 'Bandcamp'
    var values = {'Artist': track.artist || '', 'Album': track.album || '',
                  'Song Name': track.title || track.name || '', 'State': playing ? 'Playing' : 'Paused'}
    var prepared = template.replace(/\{(Artist|Album|Song Name|State)\}/g, function(token, key) { return values[key] ? token : '' })
    prepared = prepared.replace(/(?:\s+[—–\-/|]\s+){2,}/g, ' — ').replace(/^\s*[—–\-/|]\s*|\s*[—–\-/|]\s*$/g, '').trim()
    var text = prepared.replace(/\{(Artist|Album|Song Name|State)\}/g, function(_, key) { return values[key] })
    return (!playing && template.indexOf('{State}') < 0 ? 'Ⅱ  ' : '') + (text || 'Bandcamp')
}
