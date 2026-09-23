import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null
    readonly property string directory: manifest && manifest.__sourceDir
        ? String(manifest.__sourceDir) : decodeURIComponent(Qt.resolvedUrl('.').toString().replace(/^file:\/\//, '')).replace(/\/$/, '')
    property var state: ({starting: true, config: {}, connected: false, busy: false, error: '', albums: [], album: null,
        queue: [], index: -1, playing: false, position: 0, duration: 0, volume: 75,
        shuffle: false, repeat: 'none', current: null})
    property string processError: ''
    property bool quitting: false
    property bool libraryVisible: false
    signal libraryToggleRequested()
    signal miniRequested()
    signal raiseRequested()
    signal stopped()
    function start() {
        if (!backend.running) { quitting = false; processError = ''; backend.running = true }
    }
    function send(cmd, args) {
        if (!backend.running) {
            processError = 'The player stopped. Reopen Bandcamp to reconnect.'
            return
        }
        var message = Object.assign({}, args || {}, {cmd: cmd})
        backend.write(JSON.stringify(message) + '\n')
    }
    function quit() { quitting = true; send('quit') }
    Process {
        id: backend
        command: [root.directory + '/bin/backend']
        running: true
        stdinEnabled: true
        onStarted: root.processError = ''
        stdout: SplitParser {
            onRead: data => {
                try {
                    var event = JSON.parse(data)
                    if (event.event === 'state') { root.state = Object.assign({}, root.state, event.state); root.processError = '' }
                    else if (event.event === 'raise') root.raiseRequested()
                } catch (_) { root.processError = 'The player returned an unreadable response.' }
            }
        }
        // Backend diagnostics never contain credentials; keep them out of the UI.
        stderr: SplitParser { onRead: data => {} }
        onExited: (code, status) => {
            if (!root.quitting) root.processError = 'The player stopped. Reopen Bandcamp to reconnect.'
            root.stopped()
        }
    }
}
