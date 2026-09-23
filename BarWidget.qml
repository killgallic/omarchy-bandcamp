import QtQuick
import Quickshell
import qs.Ui as Ui
import qs.Commons

Ui.BarWidget {
    id: root
    moduleName: 'its.bandcamp'
    readonly property var player: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    readonly property var config: player ? player.state.config || ({}) : ({})
    property bool popupOpen: false
    readonly property bool opened: popupOpen
    function open() { if (config.mini_player_enabled === false) { openLibrary(); return }; if (player) player.start(); popupOpen = true }
    function close() { popupOpen = false }
    function toggle() { if (popupOpen) close(); else open() }
    function openLibrary() {
        close()
        if (bar && bar.shell) bar.shell.summon(moduleName, '{}')
    }
    Connections {
        target: root.player
        function onMiniRequested() { root.open() }
        function onStateChanged() { if (root.config.mini_player_enabled === false) root.close() }
    }
    implicitWidth: vertical ? barSize : Math.min(240, content.implicitWidth + 24)
    implicitHeight: barSize
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 9
        Image {
            visible: root.vertical || root.config.bar_display !== 'title'
            width: 28; height: 18
            anchors.verticalCenter: parent.verticalCenter
            source: 'assets/bandcamp.svg'
            sourceSize: Qt.size(56, 36)
            smooth: true
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical && root.config.bar_display !== 'icon'
            width: Math.min(186, implicitWidth)
            text: root.player && root.player.state.current && root.player.state.current.title ? (root.player.state.playing ? '▶  ' : 'Ⅱ  ') + root.player.state.current.title : 'bandcamp'
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.MiddleButton) { if (root.player) root.player.send('toggle') }
            else if (event.button === Qt.RightButton) root.openLibrary()
            else if (root.config.bar_click === 'mini') root.toggle()
            else if (root.config.bar_click === 'library') root.openLibrary()
            else { root.close(); if (root.player && root.player.libraryVisible) root.player.libraryToggleRequested(); else root.openLibrary() }
        }
        onWheel: event => { if (root.player) root.player.send(event.angleDelta.y > 0 ? 'previous' : 'next') }
    }
    // Use the host's popup coordinator and outside-click handling.
    Ui.KeyboardPanel {
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        contentWidth: fittedContentWidth(root.config.mini_player_width || 460)
        contentHeight: fittedContentHeight(236)
        MiniPlayer {
            anchors.fill: parent
            service: root.player
            foreground: Color.foreground; background: Color.background; accent: Color.accent; muted: Color.muted
            onOpenRequested: root.openLibrary()
            onQuitRequested: { if (root.player) root.player.quit(); root.close() }
        }
    }
}
