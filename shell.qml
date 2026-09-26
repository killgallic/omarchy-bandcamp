import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property bool expanded: true
    property bool exiting: false
    function quitPlayer() { player.requestQuit() }
    Theme { id: theme }
    Service {
        id: player
        Component.onCompleted: start()
        onRaiseRequested: root.expanded = true
        onQuitConfirmationRequested: { root.expanded = true; Qt.callLater(() => playerView.confirmQuit()) }
        onQuittingChanged: if (quitting) { root.exiting = true; shutdown.start() }
        onStateChanged: if (state.config.mini_player_enabled === false) root.expanded = true
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
        implicitWidth: player.state.config.large_player_width || 1000; implicitHeight: player.state.config.large_player_height || 760
        minimumSize: Qt.size(660, 620)
        color: theme.background
        onVisibleChanged: if (!visible && root.expanded && !root.exiting) root.expanded = false
        PlayerView {
            id: playerView
            anchors.fill: parent
            service: player
            foreground: theme.foreground; background: theme.background; accent: theme.accent; muted: theme.muted
            fontFamily: theme.fontFamily
            onQuitConfirmed: disableConfirmation => player.quit(disableConfirmation)
        }
    }
    FloatingWindow {
        id: mini
        title: 'Bandcamp — Now playing'
        visible: !root.expanded && !root.exiting
        implicitWidth: player.state.config.mini_player_width || 460; implicitHeight: 236
        minimumSize: Qt.size(440, 236)
        maximumSize: Qt.size(900, 236)
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
