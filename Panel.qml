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
    function requestClose() {
        if (shell && typeof shell.hide === 'function') shell.hide('its.bandcamp')
        else close()
    }
    Connections {
        target: root.service
        function onRaiseRequested() {
            if (root.shell) root.shell.summon('its.bandcamp', '{}')
            else root.open('{}')
        }
    }
    FloatingWindow {
        title: 'Bandcamp — Collection'
        visible: root.opened
        implicitWidth: 1000; implicitHeight: 760
        minimumSize: Qt.size(660, 620)
        color: Color.background
        onVisibleChanged: if (!visible && root.opened) root.requestClose()
        PlayerView {
            anchors.fill: parent
            service: root.service
            foreground: Color.foreground; background: Color.background; accent: Color.accent; muted: Color.muted
            fontFamily: Style.font.family
            onMinimizeRequested: root.requestClose()
            onQuitRequested: { if (root.service) root.service.quit(); root.requestClose() }
        }
    }
}
