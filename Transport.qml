import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var service
    property color foreground: '#d8dee9'
    property color background: '#181c22'
    property color accent: '#81a1c1'
    property color muted: '#808994'
    property bool compact: false
    readonly property var state: service ? service.state : ({})
    readonly property var current: state.current || ({})
    color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.035)
    implicitHeight: compact ? 186 : 148
    function time(value) {
        var n = Math.max(0, Math.floor(Number(value) || 0))
        return Math.floor(n / 60) + ':' + ('0' + n % 60).slice(-2)
    }
    component Action: ActionButton {
        foreground: root.foreground; surface: root.background; accent: root.accent
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 7
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Artwork { visible: !root.compact || (root.state.config || {}).mini_show_artwork !== false; Layout.preferredWidth: 44; Layout.preferredHeight: 44; source: root.current.art || ''; foreground: root.foreground }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { Layout.fillWidth: true; text: root.current.title || 'Nothing playing'; color: root.foreground; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; textFormat: Text.PlainText }
                Text { Layout.fillWidth: true; text: root.current.artist || 'Choose a record from your collection'; color: root.muted; font.pixelSize: 12; elide: Text.ElideRight; textFormat: Text.PlainText }
            }
            Action { text: '|◀'; Accessible.name: 'Previous track'; enabled: !!root.current.id; onClicked: root.service.send('previous') }
            Action { text: root.state.playing ? 'Ⅱ' : '▶'; Accessible.name: root.state.playing ? 'Pause' : 'Play'; emphasized: true; enabled: !!(root.state.queue || []).length; onClicked: root.service.send('toggle') }
            Action { text: '▶|'; Accessible.name: 'Next track'; enabled: !!(root.state.queue || []).length; onClicked: root.service.send('next') }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.time(seek.pressed ? seek.value : root.state.position); color: root.muted; font.pixelSize: 11; font.family: 'monospace' }
            Slider {
                id: seek
                Layout.fillWidth: true
                from: 0; to: Math.max(1, root.state.duration || 0)
                value: root.state.position || 0
                enabled: !!root.state.current && root.state.duration > 0
                palette.highlight: root.accent
                Accessible.name: 'Playback position'
                onPressedChanged: if (!pressed && enabled) root.service.send('seek', {position: value})
                Keys.onReleased: event => { if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) root.service.send('seek', {position: value}) }
            }
            Text { text: root.time(root.state.duration); color: root.muted; font.pixelSize: 11; font.family: 'monospace' }
        }
        RowLayout {
            Layout.fillWidth: true
            Action { text: 'Shuffle'; emphasized: !!root.state.shuffle; implicitHeight: 28; onClicked: root.service.send('shuffle', {enabled: !root.state.shuffle}) }
            Action { text: root.state.repeat === 'one' ? 'Repeat 1' : root.state.repeat === 'all' ? 'Repeat all' : 'Repeat'; emphasized: root.state.repeat !== 'none'; implicitHeight: 28; onClicked: root.service.send('repeat', {mode: root.state.repeat === 'none' ? 'all' : root.state.repeat === 'all' ? 'one' : 'none'}) }
            Item { Layout.fillWidth: true }
            Text { text: 'VOL'; color: root.muted; font.pixelSize: 10; font.letterSpacing: 1 }
            Slider { Layout.preferredWidth: root.compact ? 75 : 110; from: 0; to: 100; value: root.state.volume === undefined ? 75 : root.state.volume; palette.highlight: root.accent; Accessible.name: 'Volume'; onMoved: root.service.send('volume', {value: Math.round(value)}) }
        }
    }
}
