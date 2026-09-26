import QtQuick
import QtQuick.Controls
Menu {
    id: root
    required property var service
    property var item: ({})
    property var source: ({})
    property int trackIndex: 0
    property int queueIndex: -1
    property color foreground: '#d8dee9'
    property color surface: '#181c22'
    property color accent: '#81a1c1'
    signal playlistRequested(var source)
    signal detailsRequested(var item, var source)
    popupType: Popup.Item
    palette.text: foreground; palette.windowText: foreground; palette.window: surface; palette.base: surface; palette.highlight: accent
    function showFor(target, record, selection, index, queueRow) {
        item = Object.assign({}, record)
        source = Object.assign({}, selection)
        trackIndex = index || 0
        queueIndex = queueRow === undefined ? -1 : queueRow
        popup(target, 0, target.height)
    }
    MenuItem { text: 'Play now'; onTriggered: root.service.send(root.queueIndex >= 0 ? 'play_index' : 'play_album', root.queueIndex >= 0 ? {index:root.queueIndex} : {id:root.source.kind === 'album' ? root.source.id : root.source.albumId,index:root.trackIndex,trackId:root.source.kind === 'track' ? root.source.id : ''}) }
    MenuItem { text: root.source.kind === 'album' ? 'Add album to queue' : 'Add track to queue'; onTriggered: root.service.send(root.source.kind === 'album' ? 'enqueue_album' : 'enqueue_track', {id:root.source.kind === 'album' ? root.source.id : root.source.albumId,index:root.trackIndex,trackId:root.source.id}) }
    MenuItem { text: 'Add to playlist…'; onTriggered: root.playlistRequested(Object.assign({}, root.source)) }
    MenuSeparator { visible: root.source.kind === 'album' }
    MenuItem { objectName: 'favouriteAction'; visible: root.source.kind === 'album'; height: visible ? implicitHeight : 0; text: ((root.service.state.favouriteIds || []).indexOf(String(root.source.id)) >= 0) ? 'Remove from favourites' : 'Add to favourites'; onTriggered: root.service.send('toggle_favourite', {id:root.source.id}) }
    MenuItem { objectName: 'hideAction'; visible: root.source.kind === 'album'; height: visible ? implicitHeight : 0; text: ((root.service.state.hiddenIds || []).indexOf(String(root.source.id)) >= 0) ? 'Unhide album' : 'Hide album'; onTriggered: root.service.send('toggle_hidden', {id:root.source.id}) }
    MenuSeparator {}
    MenuItem { text: root.source.kind === 'album' ? 'Album information' : 'Track information'; onTriggered: root.detailsRequested(root.item, root.source) }
    MenuItem { text: root.item.artistUrl ? 'Artist on Bandcamp ↗' : 'Search artist on Bandcamp ↗'; onTriggered: Qt.openUrlExternally(root.item.artistUrl || 'https://bandcamp.com/search?q=' + encodeURIComponent(root.item.artist || '')) }
    MenuItem { text: root.item.releaseUrl ? 'View / support release ↗' : 'Search release on Bandcamp ↗'; onTriggered: Qt.openUrlExternally(root.item.releaseUrl || 'https://bandcamp.com/search?q=' + encodeURIComponent((root.item.artist || '') + ' ' + (root.item.album || root.item.name || ''))) }
    MenuSeparator { visible: root.queueIndex >= 0 }
    MenuItem { visible: root.queueIndex >= 0; height: visible ? implicitHeight : 0; text: 'Remove from queue'; onTriggered: root.service.send('remove_queue', {index:root.queueIndex}) }
}
