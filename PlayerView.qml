import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var service
    property color foreground: '#d8dee9'
    property color background: '#181c22'
    property color accent: '#81a1c1'
    property color muted: '#808994'
    property string fontFamily: 'sans-serif'
    property string page: 'collection'
    property string filter: ''
    readonly property var state: service ? service.state : ({})
    readonly property var album: state.album || ({})
    readonly property var records: (state.albums || []).filter(a => ((a.name || a.title || '') + ' ' + (a.artist || '')).toLowerCase().indexOf(filter.toLowerCase()) >= 0)
    signal minimizeRequested()
    signal quitRequested()
    color: background
    component Action: ActionButton {
        foreground: root.foreground; surface: root.background; accent: root.accent
        font.family: root.fontFamily
    }
    component Copy: Text {
        color: root.foreground; font.family: root.fontFamily; font.pixelSize: 14
        textFormat: Text.PlainText
    }
    component Field: TextField {
        color: root.foreground
        placeholderTextColor: root.muted
        selectionColor: root.accent
        selectedTextColor: root.background
        font.family: root.fontFamily
        font.pixelSize: 14
        leftPadding: 14; rightPadding: 14
        implicitHeight: 44
        background: Rectangle {
            radius: 5
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
            border.color: parent.activeFocus ? root.accent : root.muted
            border.width: 1
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            spacing: 12
            Copy { text: 'bandcamp'; font.pixelSize: 24; font.bold: true; font.italic: true; font.letterSpacing: -1 }
            Copy { text: ' /  YOUR RECORDS'; color: root.muted; font.pixelSize: 10; font.letterSpacing: 2; visible: root.width > 650 }
            Item { Layout.fillWidth: true }
            Action { text: 'Mini'; Accessible.name: 'Open mini player'; onClicked: root.minimizeRequested() }
            Action { text: 'Quit'; onClicked: root.quitRequested() }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.muted; opacity: 0.2 }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: message.implicitHeight + 24
            visible: !!message.text
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
            Copy { id: message; anchors.fill: parent; anchors.margins: 12; text: (root.service ? root.service.processError : '') || root.state.error || root.state.notice || ''; wrapMode: Text.Wrap; font.pixelSize: 13 }
        }
        // Login fields live only while disconnected; no password survives login.
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            active: !root.state.connected
            visible: active
            sourceComponent: Component {
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 64, 410)
                        spacing: 16
                        Copy { text: 'Your collection.\nA little closer.'; font.pixelSize: 32; font.bold: true; lineHeight: 1.15 }
                        Copy { Layout.fillWidth: true; text: 'Enter the Subsonic username and password generated in Bandcamp Fan Settings.'; color: root.muted; wrapMode: Text.Wrap; lineHeight: 1.4 }
                        Action { text: 'Open Bandcamp Fan Settings'; onClicked: Qt.openUrlExternally('https://bandcamp.com/settings?pane=fan') }
                        Field { id: username; Layout.fillWidth: true; placeholderText: 'Generated username'; Accessible.name: 'Generated Subsonic username'; enabled: !root.state.busy; onAccepted: password.forceActiveFocus() }
                        Field { id: password; Layout.fillWidth: true; placeholderText: 'Generated password'; Accessible.name: 'Generated Subsonic password'; echoMode: TextInput.Password; enabled: !root.state.busy; onAccepted: if (login.enabled) login.clicked() }
                        CheckBox { id: remember; text: 'Remember securely on this computer'; checked: false; palette.windowText: root.foreground; palette.text: root.foreground; palette.highlight: root.accent }
                        Action {
                            id: login
                            Layout.fillWidth: true; implicitHeight: 44
                            text: root.state.busy ? 'Connecting…' : 'Open my collection'
                            emphasized: true
                            enabled: !root.state.busy && username.text.trim().length > 0 && password.text.length > 0
                            onClicked: { root.service.send('login', {username: username.text.trim(), password: password.text, remember: remember.checked}); password.clear() }
                        }
                        Copy { Layout.fillWidth: true; text: 'Use generated Subsonic credentials, not your regular Bandcamp password.'; font.pixelSize: 12; color: root.muted; wrapMode: Text.Wrap }
                    }
                }
            }
        }
        ColumnLayout {
            visible: !!root.state.connected
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.margins: 24
            spacing: 20
            RowLayout {
                Layout.fillWidth: true
                Action { text: 'Collection'; emphasized: root.page === 'collection'; onClicked: root.page = 'collection' }
                Action { text: 'Queue' + ((root.state.queue || []).length ? ' · ' + root.state.queue.length : ''); emphasized: root.page === 'queue'; onClicked: root.page = 'queue' }
                Item { Layout.fillWidth: true }
                Copy { text: root.state.busy ? 'Loading…' : ''; color: root.muted; font.pixelSize: 12 }
                Action { text: 'Refresh'; enabled: !root.state.busy; onClicked: root.service.send('refresh') }
                Action { text: 'Sign out'; enabled: !root.state.busy; onClicked: { root.page = 'collection'; root.service.send('logout') } }
            }
            RowLayout {
                visible: root.page === 'collection'
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 4
                    Copy { text: 'The collection'; font.pixelSize: 27; font.bold: true }
                    Copy { text: (root.state.albums || []).length + ' records, yours to play'; color: root.muted; font.pixelSize: 12 }
                }
                Item { Layout.fillWidth: true }
                Field { Layout.preferredWidth: Math.min(300, root.width * 0.35); placeholderText: 'Filter artist or album'; Accessible.name: 'Filter collection'; onTextChanged: root.filter = text }
            }
            StackLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                currentIndex: root.page === 'collection' ? 0 : root.page === 'album' ? 1 : 2
                Item {
                    GridView {
                        id: grid
                        anchors.fill: parent
                        clip: true
                        cellWidth: width / Math.max(2, Math.floor(width / 178))
                        cellHeight: cellWidth + 65
                        model: root.records
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Item {
                            required property var modelData
                            width: grid.cellWidth; height: grid.cellHeight
                            Column {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: 18
                                spacing: 8
                                Button {
                                    width: parent.width; height: width
                                    Accessible.name: 'Open ' + (modelData.name || modelData.title) + ' by ' + modelData.artist
                                    background: Artwork { source: modelData.art || ''; foreground: root.foreground }
                                    onClicked: { root.service.state = Object.assign({}, root.state, {album: null}); root.page = 'album'; root.service.send('album', {id: modelData.id}) }
                                    Rectangle { anchors.fill: parent; color: 'transparent'; border.width: parent.hovered || parent.activeFocus ? 2 : 0; border.color: root.accent }
                                }
                                Copy { width: parent.width; text: modelData.name || modelData.title || 'Untitled'; font.bold: true; elide: Text.ElideRight }
                                Copy { width: parent.width; text: modelData.artist || ''; color: root.muted; font.pixelSize: 12; elide: Text.ElideRight }
                            }
                        }
                    }
                    Copy { anchors.centerIn: parent; visible: root.records.length === 0; text: root.state.busy ? 'Loading your records…' : root.filter ? 'No records match this filter.' : 'No albums found. Refresh to try again.'; color: root.muted }
                }
                ColumnLayout {
                    spacing: 18
                    RowLayout {
                        Layout.fillWidth: true; spacing: 20
                        Artwork { Layout.preferredWidth: 116; Layout.preferredHeight: 116; source: root.album.art || ''; foreground: root.foreground }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            Copy { Layout.fillWidth: true; text: root.album.name || root.album.title || 'Loading album…'; font.pixelSize: 24; font.bold: true; elide: Text.ElideRight }
                            Copy { Layout.fillWidth: true; text: root.album.artist || ''; color: root.muted; elide: Text.ElideRight }
                            RowLayout {
                                Action { text: 'Play record'; emphasized: true; enabled: !!root.album.id && !root.state.busy; onClicked: root.service.send('play_album', {id: root.album.id, index: 0}) }
                                Action { text: '+ Queue'; enabled: !!root.album.id && !root.state.busy; onClicked: root.service.send('enqueue_album', {id: root.album.id}) }
                            }
                        }
                    }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 2
                        model: root.album.song || []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            foreground: root.foreground; muted: root.muted; accent: root.accent
                            track: modelData; number: index + 1
                            selected: root.state.current && root.state.current.id === modelData.id
                            onClicked: root.service.send('play_album', {id: root.album.id, index: index})
                        }
                    }
                }
                Item {
                    ListView {
                        anchors.fill: parent; clip: true; spacing: 2
                        model: root.state.queue || []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            foreground: root.foreground; muted: root.muted; accent: root.accent
                            track: modelData; number: index + 1; selected: root.state.index === index
                            onClicked: root.service.send('play_index', {index: index})
                        }
                    }
                    Copy { anchors.centerIn: parent; visible: !(root.state.queue || []).length; text: 'Your queue is empty. Pick a record to begin.'; color: root.muted }
                }
            }
        }
        Transport { Layout.fillWidth: true; visible: !!root.state.connected; service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted }
    }
}
