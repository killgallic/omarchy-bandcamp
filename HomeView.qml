import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ScrollView {
    id: root
    required property var service
    property color foreground
    property color surface
    property color accent
    property color muted
    signal browseRequested(string query)
    signal albumRequested(var album)
    signal playlistsRequested()
    signal favouritesRequested()
    signal albumContextRequested(var target, var album)
    readonly property var recent: service.state.homeRecent || []
    readonly property var rediscover: service.state.homeRediscover || []
    readonly property var favourites: service.state.homeFavourites || []
    Component {
        id: scrollAssistComponent
        ScrollAssist {
            objectName: 'homeScroll'
            flickable: root.contentItem
            config: root.service.state.config || ({})
            accent: root.accent
        }
    }
    Component.onCompleted: scrollAssistComponent.createObject(root.contentItem)
    component Action: ActionButton { foreground: root.foreground; surface: root.surface; accent: root.accent }
    component Heading: Text { color: root.foreground; font.pixelSize: 22; font.bold: true }
    component Shelf: Flow {
        property var records: []
        Layout.fillWidth: true; spacing: 14
        Repeater {
            model: parent.records
            Item {
                required property var modelData
                width: Math.max(130, (root.availableWidth - 42) / 4); height: width + 52
                Column {
                    anchors.fill: parent
                    spacing: 6
                    Artwork { width: parent.width; height: width; source: modelData.art || ''; foreground: root.foreground }
                    Text { width: parent.width; text: modelData.name || modelData.title || ''; textFormat: Text.PlainText; color: root.foreground; elide: Text.ElideRight; font.bold: true }
                    Text { width: parent.width; text: modelData.artist || ''; textFormat: Text.PlainText; color: root.muted; elide: Text.ElideRight }
                }
                MouseArea { id: shelfMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: event => { if (event.button === Qt.RightButton) root.albumContextRequested(shelfMouse, modelData); else root.albumRequested(modelData) } }
            }
        }
    }
    ColumnLayout {
        width: root.availableWidth; spacing: 20
        Heading { text: 'Your music, and what comes next.' }
        TextField {
            Layout.fillWidth: true; placeholderText: 'Find an artist or album in your records'
            color: root.foreground; placeholderTextColor: root.muted
            selectionColor: root.accent; selectedTextColor: root.surface
            background: Rectangle { color: Qt.lighter(root.surface, 1.12); radius: 5; border.color: parent.activeFocus ? root.accent : root.muted; border.width: 1 }
            onTextEdited: root.browseRequested(text)
            onAccepted: root.browseRequested(text)
        }
        RowLayout {
            visible: !!(root.service.state.current || {}).id
            ColumnLayout {
                Heading { text: 'Continue listening' }
                Text { text: (root.service.state.current || {}).title || ''; textFormat: Text.PlainText; color: root.foreground }
            }
            Item { Layout.fillWidth: true }
            Action { text: root.service.state.playing ? 'Pause' : 'Resume'; onClicked: root.service.send('toggle') }
        }
        RowLayout {
            Heading { text: 'Favourites' }
            Item { Layout.fillWidth: true }
            Action { objectName: 'homeFavouritesButton'; text: 'View all'; onClicked: root.favouritesRequested() }
        }
        Text { visible: !root.favourites.length; text: 'Keep your best finds close. Favourite any album from its menu.'; color: root.muted }
        Shelf { objectName: 'homeFavouritesShelf'; records: root.favourites }
        RowLayout {
            Heading { text: 'Recently added' }
            Item { Layout.fillWidth: true }
            Action { text: 'Browse all records'; onClicked: root.browseRequested('') }
        }
        Shelf { records: root.recent }
        RowLayout {
            Heading { text: 'Your playlists' }
            Item { Layout.fillWidth: true }
            Action { text: 'New / manage playlists'; onClicked: root.playlistsRequested() }
        }
        Text { visible: !(root.service.state.playlists || []).length; text: 'No playlists yet. Create one from any record or track.'; color: root.muted }
        Flow {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: (root.service.state.playlists || []).slice(0,6)
                Action { required property var modelData; text: modelData.name || 'Untitled'; onClicked: { root.service.send('playlist', {id:modelData.id}); root.playlistsRequested() } }
            }
        }
        Heading { text: 'Rediscover your records' }
        Text { text: 'From your collection, using listening history in this app.'; color: root.muted }
        Shelf { records: root.rediscover }
        Heading { text: 'Explore and support' }
        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: 'Find your next favourite, read the stories, and support artists directly on Bandcamp.'; color: root.foreground }
        Flow {
            Layout.fillWidth: true; spacing: 10
            Action { text: 'Discover music ↗'; onClicked: Qt.openUrlExternally('https://bandcamp.com/discover') }
            Action { text: 'Bandcamp Daily ↗'; onClicked: Qt.openUrlExternally('https://daily.bandcamp.com/') }
            Action { text: 'Your Bandcamp profile ↗'; visible: !!(root.service.state.config || {}).profile_url; onClicked: Qt.openUrlExternally(root.service.state.config.profile_url) }
        }
    }
}
