import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
ColumnLayout {
    id: root
    required property var service
    property color foreground
    property color background
    property color accent
    property color muted
    readonly property var snapshot: service.state.cachedCollection || ({})
    readonly property var albums: snapshot.albums || []
    property string query: ''
    property var selectedArtists: []
    property var selectedGenres: []
    property string order: 'artist'
    readonly property var records: albums.filter(a =>
        ((a.name || '')+' '+(a.artist || '')).toLowerCase().includes(query.toLowerCase()) &&
        (!selectedArtists.length || selectedArtists.includes(a.artist)) &&
        (!selectedGenres.length || selectedGenres.includes(a.genre)))
        .slice().sort((a,b) => order === 'newest' ? (Date.parse(b.created || '') || 0) - (Date.parse(a.created || '') || 0) : String(a.artist || '').localeCompare(String(b.artist || '')) || String(a.name || '').localeCompare(String(b.name || '')))
    spacing: 12
    Text { text: 'Your cached collection'; color: root.foreground; font.pixelSize: 26; font.bold: true }
    Text { Layout.fillWidth: true; text: 'Bandcamp is unavailable. Browse saved records here; playback, playlists, and purchases need a connection.'; color: root.muted; wrapMode: Text.Wrap }
    RowLayout {
        Layout.fillWidth: true
        ActionButton { text: 'Reconnect'; enabled: !root.service.state.busy; foreground: root.foreground; surface: root.background; accent: root.accent; onClicked: root.service.send('reconnect') }
        ActionButton { text: 'Sign out'; foreground: root.foreground; surface: root.background; accent: root.accent; onClicked: root.service.send('logout') }
        Item { Layout.fillWidth: true }
        Text { text: root.records.length + ' / ' + root.albums.length + ' saved records'; color: root.muted }
    }
    TextField {
        Layout.fillWidth: true; placeholderText: 'Find an artist or album'; text: root.query
        onTextChanged: root.query = text; color: root.foreground; placeholderTextColor: root.muted
        background: Rectangle { color: Qt.lighter(root.background,1.12); radius: 4; border.color: parent.activeFocus ? root.accent : root.muted }
    }
    RowLayout {
        FilterDropdown { title: 'Artist'; options: Array.from(new Set(root.albums.map(a=>a.artist).filter(Boolean))).sort().map(v=>({value:v,label:v})); showCounts: false; selectedValues: root.selectedArtists; onSelectionChanged: values=>root.selectedArtists=values; foreground: root.foreground; surface: root.background; accent: root.accent }
        FilterDropdown { title: 'Genre'; options: Array.from(new Set(root.albums.map(a=>a.genre).filter(Boolean))).sort().map(v=>({value:v,label:v})); showCounts: false; selectedValues: root.selectedGenres; onSelectionChanged: values=>root.selectedGenres=values; foreground: root.foreground; surface: root.background; accent: root.accent }
        Item { Layout.fillWidth: true }
        ComboBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.background; palette.button: Qt.lighter(root.background, 1.2); model: ['Artist A–Z','Recently added']; currentIndex: root.order === 'newest' ? 1 : 0; onActivated: root.order = currentIndex === 1 ? 'newest' : 'artist' }
    }
    ListView {
        id: list
        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 6
        model: root.records
        ScrollBar.vertical: ScrollBar {}
        ScrollAssist { flickable: list; wheelStep: (root.service.state.config || {}).wheel_scroll_pixels || 360; wheelAcceleration: (root.service.state.config || {}).wheel_acceleration !== false; accent: root.accent }
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width; height: 54; radius: 4
            color: Qt.lighter(root.background,1.08)
            Column {
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 10
                Text { width: parent.width; text: modelData.name || ''; textFormat: Text.PlainText; color: root.foreground; elide: Text.ElideRight; font.bold: true }
                Text { width: parent.width; text: modelData.artist || ''; textFormat: Text.PlainText; color: root.muted; elide: Text.ElideRight }
            }
        }
        Text { anchors.centerIn: parent; visible: root.records.length === 0; text: 'No saved records match.'; color: root.muted }
    }
}
