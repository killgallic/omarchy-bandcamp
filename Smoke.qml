import QtQuick
import Quickshell

ShellRoot {
    Service { id: player; Component.onCompleted: start() }
    Theme { id: theme }
    FloatingWindow {
        id: window
        visible: true
        implicitWidth: 1000; implicitHeight: 760
        PlayerView {
            id: view
            anchors.fill: parent
            service: player
            foreground: theme.foreground; background: theme.background
            accent: theme.accent; muted: theme.muted
        }
    }
    Timer {
        property int attempts: 0
        interval: 250; running: true; repeat: true
        onTriggered: {
            attempts++
            if (player.state.busy && attempts < 32) return
            stop()
            if (player.processError || !player.state.mpris) {
                console.error('SMOKE_FAILED: ' + (player.processError || 'Backend did not register MPRIS'))
                Qt.quit()
                return
            }
            view.grabToImage(result => {
                result.saveToFile(Quickshell.env('BANDCAMP_SCREENSHOT'))
                console.log('SMOKE_PASSED: native login and backend connected')
                player.quit()
                Qt.quit()
            })
        }
    }
}
