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
    readonly property alias notifications: notificationCenter
    NotificationCenter {
        id: notificationCenter
        onActionRequested: action => root.send(action === 'skip' ? 'next' : action)
    }
    onProcessErrorChanged: {
        if (processError) notificationCenter.push({level: 'error', code: 'backend_process', message: processError})
    }
    function receive(event) {
        if (event.event === 'state') {
            if ((event.state.connected === false && state.connected === true) ||
                (event.state.username && state.username && event.state.username !== state.username)) notificationCenter.clear()
            notificationCenter.ingestState(event.state, state)
            state = Object.assign({}, state, event.state)
            processError = ''
        } else if (event.event === 'notification') {
            const value = event.notification
            if (value && value.resolved) notificationCenter.resolve(value.resourceId)
            else notificationCenter.push(value)
        } else if (event.event === 'raise') raiseRequested()
    }
    signal libraryToggleRequested()
    signal miniRequested()
    signal homeRequested()
    signal raiseRequested()
    signal stopped()
    function start() {
        if (!backend.running) { notificationCenter.clear(); quitting = false; processError = ''; state = Object.assign({}, state, {setupRequired:false, starting:true}); backend.running = true }
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
                    root.receive(event)
                } catch (_) { root.processError = 'The player returned an unreadable response.' }
            }
        }
        // Backend diagnostics never contain credentials; keep them out of the UI.
        stderr: SplitParser { onRead: data => {} }
        onExited: (code, status) => {
            if (!root.quitting) {
                notificationCenter.clear()
                root.processError = code === 1 && !root.state.connected ? 'Setup needed: run bin/setup in the Omarchy Bandcamp directory, then reopen the player.' : 'The player stopped. Reopen Bandcamp to reconnect.'
                root.state = Object.assign({}, root.state, {starting: false, setupRequired: code === 1 && !root.state.connected})
            }
            root.stopped()
        }
    }
}
