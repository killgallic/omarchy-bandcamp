import QtQuick
import Quickshell
import qs.Ui as Ui
import qs.Commons

Ui.BarWidget {
    id: root
    moduleName: 'its.bandcamp'
    readonly property var player: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    property bool popupOpen: false
    readonly property bool opened: popupOpen
    function open() { if (player) player.start(); popupOpen = true }
    function close() { popupOpen = false }
    function toggle() { if (popupOpen) close(); else open() }
    function openLibrary() {
        close()
        if (bar && bar.shell) bar.shell.summon(moduleName, '{}')
    }
    implicitWidth: vertical ? barSize : Math.min(220, label.implicitWidth + 24)
    implicitHeight: barSize
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(196, implicitWidth)
        text: root.vertical ? 'bc' : root.player && root.player.state.current && root.player.state.current.title ? (root.player.state.playing ? '▶  ' : 'Ⅱ  ') + root.player.state.current.title : 'bandcamp'
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.body
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.MiddleButton) { if (root.player) root.player.send('toggle') }
            else if (event.button === Qt.RightButton) root.openLibrary()
            else root.toggle()
        }
        onWheel: event => { if (root.player) root.player.send(event.angleDelta.y > 0 ? 'previous' : 'next') }
    }
    // Use the host's popup coordinator and outside-click handling.
    Ui.KeyboardPanel {
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        contentWidth: fittedContentWidth(440)
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
