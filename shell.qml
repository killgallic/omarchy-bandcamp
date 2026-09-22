import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property bool expanded: true
    property bool exiting: false
    function quitPlayer() { exiting = true; player.quit(); shutdown.start() }
    Theme { id: theme }
    Service {
        id: player
        onRaiseRequested: root.expanded = true
        onStopped: if (root.exiting) Qt.quit()
    }
    Timer { id: shutdown; interval: 2000; onTriggered: Qt.quit() }
    IpcHandler {
        target: 'bandcamp'
        function open(): void { root.expanded = true }
        function toggle(): void { root.expanded = !root.expanded }
        function quit(): void { root.quitPlayer() }
    }
    FloatingWindow {
        id: library
        title: 'Bandcamp — Collection'
        visible: root.expanded && !root.exiting
        implicitWidth: 1000; implicitHeight: 760
        minimumSize: Qt.size(660, 620)
        color: theme.background
        onVisibleChanged: if (!visible && root.expanded && !root.exiting) root.expanded = false
        PlayerView {
            anchors.fill: parent
            service: player
            foreground: theme.foreground; background: theme.background; accent: theme.accent; muted: theme.muted
            fontFamily: theme.fontFamily
            onMinimizeRequested: root.expanded = false
            onQuitRequested: root.quitPlayer()
        }
    }
    FloatingWindow {
        id: mini
        title: 'Bandcamp — Now playing'
        visible: !root.expanded && !root.exiting
        implicitWidth: 460; implicitHeight: 236
        minimumSize: Qt.size(440, 236)
        maximumSize: Qt.size(650, 236)
        color: theme.background
        // Closing the mini returns to the library so the process remains reachable.
        onVisibleChanged: if (!visible && !root.expanded && !root.exiting) root.expanded = true
        MiniPlayer {
            anchors.fill: parent
            service: player
            foreground: theme.foreground; background: theme.background; accent: theme.accent; muted: theme.muted
            onOpenRequested: root.expanded = true
            onQuitRequested: root.quitPlayer()
        }
    }
}
