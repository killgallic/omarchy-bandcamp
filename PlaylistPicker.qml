import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
Dialog {
    id: root
    required property var service
    property var source: ({})
    property color foreground: '#d8dee9'
    property color surface: '#181c22'
    property color accent: '#81a1c1'
    property bool pendingOperation: false
    property bool observedBusy: false
    title: 'Add to playlist'
    modal: true; popupType: Popup.Item
    width: Math.min(420, parent.width - 32); height: Math.min(460, parent.height - 32)
    anchors.centerIn: parent
    palette.windowText: foreground; palette.text: foreground; palette.base: surface; palette.window: surface; palette.buttonText: foreground; palette.button: Qt.lighter(surface,1.3); palette.highlight: accent
    standardButtons: Dialog.Close
    onOpened: service.send('playlists')
    onClosed: { pendingOperation = false; observedBusy = false }
    Connections {
        target: root.service
        function onStateChanged() {
            if (!root.pendingOperation) return
            if (root.service.state.playlistBusy) root.observedBusy = true
            else if (root.observedBusy) {
                root.pendingOperation = false; root.observedBusy = false
                if (!root.service.state.playlistError) root.close()
            }
        }
    }
    ColumnLayout {
        anchors.fill: parent
        TextField { id: search; Layout.fillWidth: true; placeholderText: 'Find a playlist' }
        Text { text: root.service.state.playlistError || ''; visible: !!text; color: root.foreground; wrapMode: Text.Wrap; Layout.fillWidth: true }
        ListView {
            id: choices; objectName: 'playlistChoices'
            Layout.fillWidth: true; Layout.fillHeight: true; clip: true
            model: (root.service.state.playlists || []).filter(p => (p.name || '').toLowerCase().includes(search.text.toLowerCase()))
            ScrollBar.vertical: ScrollBar {}
            ScrollAssist { flickable: choices; wheelStep: (root.service.state.config || {}).wheel_scroll_pixels || 360; wheelAcceleration: (root.service.state.config || {}).wheel_acceleration !== false; accent: root.accent }
            delegate: ActionButton {
                required property var modelData
                width: ListView.view.width; text: (modelData.name || 'Untitled') + '  ·  ' + (modelData.songCount || 0)
                foreground: root.foreground; surface: root.surface; accent: root.accent
                enabled: !root.service.state.playlistBusy
                onClicked: { root.pendingOperation = true; root.service.send('add_to_playlist', {id:modelData.id, source:root.source}) }
            }
        }
        RowLayout {
            TextField { id: name; objectName: 'newPlaylistName'; Layout.fillWidth: true; placeholderText: 'New empty playlist' }
            ActionButton { objectName: 'createAndAdd'; text: 'Create & add'; foreground: root.foreground; surface: root.surface; accent: root.accent; enabled: !!name.text.trim() && !root.service.state.playlistBusy; onClicked: { root.pendingOperation = true; root.service.send('create_and_add', {name:name.text.trim(),source:root.source}) } }
        }
    }
}
