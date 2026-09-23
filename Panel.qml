import QtQuick
import Quickshell
import qs.Commons

Item {
    id: root
    property var shell: null
    property var manifest: null
    property var service: null
    property bool opened: false
    function open(payload) { if (service) service.start(); opened = true }
    function close() { opened = false }
    onOpenedChanged: if (service) service.libraryVisible = opened
    function requestClose() {
        if (shell && typeof shell.hide === 'function') shell.hide('its.bandcamp')
        else close()
    }
    Connections {
        target: root.service
        function onLibraryToggleRequested() {
            if (root.opened) root.requestClose()
            else if (root.shell) root.shell.summon('its.bandcamp', '{}')
            else root.open('{}')
        }
        function onRaiseRequested() {
            if (root.shell) root.shell.summon('its.bandcamp', '{}')
            else root.open('{}')
        }
    }
    FloatingWindow {
        title: 'Bandcamp — Collection'
        visible: root.opened
        implicitWidth: root.service ? root.service.state.config.large_player_width || 1000 : 1000
        implicitHeight: root.service ? root.service.state.config.large_player_height || 760 : 760
        minimumSize: Qt.size(660, 620)
        color: Color.background
        onVisibleChanged: if (!visible && root.opened) root.requestClose()
        PlayerView {
            anchors.fill: parent
            service: root.service
            foreground: Color.foreground; background: Color.background; accent: Color.accent; muted: Color.muted
            fontFamily: Style.font.family
            onMinimizeRequested: { root.requestClose(); if (root.service) root.service.miniRequested() }
            onQuitRequested: { if (root.service) root.service.quit(); root.requestClose() }
        }
    }
}
