import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property color foreground: '#d8dee9'
    property color background: '#181c22'
    property color accent: '#81a1c1'
    readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.65)
    property string fontFamily: 'sans-serif'
    property FileView colors: FileView {
        path: (Quickshell.env('XDG_STATE_HOME') || Quickshell.env('HOME') + '/.local/state') + '/omarchy/current/theme/colors.toml'
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var lines = text().split('\n')
            for (var i = 0; i < lines.length; i++) {
                var match = lines[i].match(/^\s*(foreground|background|accent)\s*=\s*["'](#[0-9a-fA-F]{6})["']/)
                if (match) root[match[1]] = match[2]
            }
        }
    }
}
