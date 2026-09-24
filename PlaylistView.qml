import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property var service
    property color foreground: '#d8dee9'
    property color background: '#181c22'
    property color accent: '#81a1c1'
    property color muted: '#808994'
    property bool active: true
    readonly property var state: service.state
    readonly property var playlist: state.playlist || ({})
    signal itemContextRequested(var target, var item, var source, int index)
    property int selection: -1
    property var managedPlaylist: ({})
    onPlaylistChanged: selection = -1
    component Action: ActionButton { foreground: root.foreground; surface: root.background; accent: root.accent; enabled: !root.state.playlistBusy }
    spacing: 12
    RowLayout {
        Layout.fillWidth: true
        Text { text: 'Synced playlists'; color: root.foreground; font.pixelSize: 27; font.bold: true }
        Item { Layout.fillWidth: true }
        Action { text: 'Refresh'; onClicked: root.service.send('playlists') }
    }
    Text { Layout.fillWidth: true; text: root.state.playlistBusy ? 'Updating Bandcamp…' : root.state.playlistError || 'Saved to your Bandcamp account'; color: root.state.playlistError ? root.accent : root.muted; wrapMode: Text.Wrap }
    RowLayout {
        TextField { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.background; palette.button: Qt.lighter(root.background, 1.3); palette.window: root.background; palette.highlight: root.accent; id: name; objectName: 'newPlaylistName'; Layout.fillWidth: true; placeholderText: 'New playlist name'; Accessible.name: 'Playlist name'; color: root.foreground }
        Action { objectName: 'createPlaylist'; text: 'Create'; enabled: !root.state.playlistBusy && name.text.trim().length > 0; onClicked: root.service.send('create_playlist', {name: name.text.trim()}) }
        Action { objectName: 'saveQueuePlaylist'; text: 'Save queue'; enabled: !root.state.playlistBusy && name.text.trim().length > 0 && (root.state.queue || []).length > 0; onClicked: root.service.send('save_playlist', {name: name.text.trim()}) }
    }
    RowLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 18
        ListView {
            id: playlists; Layout.preferredWidth: Math.max(160, root.width * 0.26); Layout.fillHeight: true; clip: true; spacing: 4
            model: root.state.playlists || []
            ScrollBar.vertical: ScrollBar {}
            ScrollAssist { wheelAcceleration: (root.state.config || {}).wheel_acceleration !== false; wheelStep: (root.state.config || {}).wheel_scroll_pixels || 360; flickable: playlists; enabled: root.active; accent: root.accent }
            delegate: Action {
                required property var modelData
                width: ListView.view.width; text: modelData.name || 'Untitled'; emphasized: root.playlist.id === modelData.id
                onClicked: root.service.send('playlist', {id: modelData.id})
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            Text { Layout.fillWidth: true; text: root.playlist.name || 'Choose a playlist'; textFormat: Text.PlainText; color: root.foreground; font.pixelSize: 20; elide: Text.ElideRight }
            RowLayout {
                visible: !!root.playlist.id
                Action { objectName: 'playPlaylist'; text: 'Play'; enabled: !root.state.playlistBusy && (root.playlist.entry || []).length > 0; onClicked: root.service.send('play_playlist', {id: root.playlist.id, index: 0}) }
                Action { text: 'Append queue'; enabled: !root.state.playlistBusy && (root.state.queue || []).length > 0; onClicked: root.service.send('append_playlist', {id: root.playlist.id}) }
                Item { Layout.fillWidth: true }
                Action { id: overflow; objectName: 'playlistOverflow'; text: '⋯'; Accessible.name: 'Playlist actions'; onClicked: { root.managedPlaylist = {id: root.playlist.id, name: root.playlist.name}; playlistMenu.popup(overflow, 0, overflow.height) } }
            }
            ListView {
                id: tracks; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                model: root.playlist.entry || []
                ScrollBar.vertical: ScrollBar {}
                ScrollAssist { wheelAcceleration: (root.state.config || {}).wheel_acceleration !== false; wheelStep: (root.state.config || {}).wheel_scroll_pixels || 360; flickable: tracks; enabled: root.active; accent: root.accent }
                Text { anchors.centerIn: parent; visible: !!root.playlist.id && !(root.playlist.entry || []).length; text: 'This playlist is empty. Add tracks from your collection.'; width: parent.width - 24; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; color: root.muted; font.pixelSize: 13 }
                delegate: TrackRow {
                    required property var modelData
                    required property int index
                    width: ListView.view.width; track: modelData; number: index + 1; selected: index === root.selection
                    foreground: root.foreground; muted: root.muted; accent: root.accent
                    Accessible.name: 'Select ' + (modelData.title || 'track')
                    onClicked: root.selection = index
                    onDoubleClicked: root.service.send('play_playlist', {id: root.playlist.id, index: index})
                    onContextRequested: root.itemContextRequested(this, modelData, {kind:'track',id:modelData.id,albumId:modelData.albumId}, index)
                }
            }
            RowLayout {
                visible: root.selection >= 0
                Action { text: 'Play selected'; onClicked: root.service.send('play_playlist', {id: root.playlist.id, index: root.selection}) }
                Action { text: '↑'; Accessible.name: 'Move track up'; enabled: !root.state.playlistBusy && root.selection > 0; onClicked: root.service.send('move_playlist_track', {id: root.playlist.id, index: root.selection, direction: -1}) }
                Action { text: '↓'; Accessible.name: 'Move track down'; enabled: !root.state.playlistBusy && root.selection < (root.playlist.entry || []).length - 1; onClicked: root.service.send('move_playlist_track', {id: root.playlist.id, index: root.selection, direction: 1}) }
                Action { text: 'Remove'; onClicked: root.service.send('remove_playlist_track', {id: root.playlist.id, index: root.selection}) }
            }
        }
    }
    Menu {
        id: playlistMenu
        palette.window: root.background; palette.text: root.foreground; palette.highlight: root.accent
        MenuItem { text: 'Rename…'; objectName: 'renamePlaylistMenuItem'; onTriggered: { playlistMenu.close(); renameDialog.open() } }
        MenuSeparator {}
        MenuItem { text: 'Delete playlist…'; objectName: 'deletePlaylistMenuItem'; onTriggered: { playlistMenu.close(); deleteDialog.open() } }
    }
    Dialog {
        id: renameDialog
        objectName: 'renamePlaylistDialog'
        title: 'Rename playlist'
        anchors.centerIn: parent
        width: Math.min(440, root.width - 32)
        modal: true
        closePolicy: Popup.CloseOnEscape
        palette.window: root.background; palette.windowText: root.foreground; palette.text: root.foreground; palette.base: root.background
        onOpened: { rename.text = root.managedPlaylist.name || ''; rename.forceActiveFocus(); rename.selectAll() }
        contentItem: TextField { id: rename; objectName: 'renamePlaylistName'; color: root.foreground; Accessible.name: 'New playlist name' }
        footer: Item {
            implicitHeight: 62
            RowLayout {
                anchors.fill: parent; anchors.margins: 12
                Action { text: 'Cancel'; onClicked: renameDialog.close() }
                Item { Layout.fillWidth: true }
                Action { objectName: 'confirmRenamePlaylist'; text: 'Rename'; enabled: !root.state.playlistBusy && rename.text.trim().length > 0; onClicked: { root.service.send('rename_playlist', {id: root.managedPlaylist.id, name: rename.text.trim()}); renameDialog.close() } }
            }
        }
    }
    Dialog {
        id: deleteDialog
        objectName: 'deletePlaylistDialog'
        title: 'Delete “' + (root.managedPlaylist.name || 'Untitled') + '”?'
        anchors.centerIn: parent
        width: Math.min(460, root.width - 32)
        height: 220
        modal: true
        closePolicy: Popup.CloseOnEscape
        palette.window: root.background; palette.windowText: root.foreground; palette.text: root.foreground
        onOpened: cancelDelete.forceActiveFocus()
        contentItem: Text {
            text: 'This removes the playlist from your Bandcamp account. Your purchased music stays in your collection.'
            width: deleteDialog.width - 32; height: 64
            textFormat: Text.PlainText; wrapMode: Text.Wrap; color: root.foreground; font.pixelSize: 14
        }
        footer: Item {
            implicitHeight: 68
            RowLayout {
                anchors.fill: parent; anchors.margins: 14
                Action { id: cancelDelete; objectName: 'cancelDeletePlaylist'; text: 'Cancel'; enabled: true; onClicked: deleteDialog.close(); Keys.onReturnPressed: event => { deleteDialog.close(); event.accepted = true }; Keys.onEnterPressed: event => { deleteDialog.close(); event.accepted = true } }
                Item { Layout.fillWidth: true }
                Action { objectName: 'confirmDeletePlaylist'; text: 'Delete playlist'; onClicked: { root.service.send('delete_playlist', {id: root.managedPlaylist.id}); deleteDialog.close() } }
            }
        }
    }

}
