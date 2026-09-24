import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Column {
    id: root
    required property var center
    property color foreground: '#d8dee9'
    property color background: '#181c22'
    property color accent: '#81a1c1'
    property color urgent: '#e06c75'
    property bool showHistory: false
    property int maximumVisible: 3
    readonly property var entries: center ? (showHistory ? center.history : center.toasts.slice(0, maximumVisible)) : []
    spacing: 8
    visible: entries.length > 0
    Repeater {
        model: root.entries
        delegate: FocusScope {
            id: toast
            required property var modelData
            width: root.width
            height: content.implicitHeight + 24
            readonly property bool paused: hover.hovered || activeFocus
            onPausedChanged: if (root.center) root.center.setPaused(modelData.id, paused)
            Accessible.role: Accessible.AlertMessage
            Accessible.name: modelData.message
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: root.background
                border.width: 1
                border.color: toast.modelData.level === 'error' || toast.modelData.level === 'warning' ? root.urgent : root.accent
            }
            HoverHandler { id: hover }
            RowLayout {
                id: content
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 12
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: toast.modelData.message
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.showHistory ? 100 : 4
                    elide: Text.ElideRight
                    color: root.foreground
                    font.pixelSize: 13
                }
                ActionButton {
                    visible: !!toast.modelData.action
                    text: toast.modelData.action ? toast.modelData.action.label : ''
                    foreground: root.foreground; surface: root.background; accent: root.accent
                    onClicked: root.center.activate(toast.modelData.id)
                }
                ActionButton {
                    objectName: 'dismissNotification'
                    text: '×'
                    Accessible.name: 'Dismiss notification'
                    foreground: root.foreground; surface: root.background; accent: root.accent
                    onClicked: root.center.dismiss(toast.modelData.id)
                }
            }
        }
    }
}
