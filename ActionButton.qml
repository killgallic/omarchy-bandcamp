import QtQuick
import QtQuick.Controls

Button {
    id: root
    property color foreground: '#d8dee9'
    property color surface: '#181c22'
    property color accent: '#81a1c1'
    property bool emphasized: false
    implicitHeight: 36
    implicitWidth: Math.max(36, contentItem.implicitWidth + 24)
    hoverEnabled: true
    font.pixelSize: 13
    contentItem: Text {
        text: root.text
        textFormat: Text.PlainText
        font: root.font
        color: root.emphasized ? root.surface : root.foreground
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.4
    }
    background: Rectangle {
        radius: 5
        color: root.emphasized ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.down ? 0.18 : root.hovered ? 0.1 : 0.045)
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10)
    }
}
