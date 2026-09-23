import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: root
    property var track: ({})
    property string actionText: ''
    signal actionClicked()
    rightPadding: actionText ? 90 : 8
    property int number: 0
    property bool selected: false
    property color foreground: '#d8dee9'
    property color muted: '#808994'
    property color accent: '#81a1c1'
    implicitHeight: 56
    Accessible.name: 'Play ' + (track.title || track.name || '')
    background: Rectangle { radius: 4; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.selected ? 0.17 : root.hovered ? 0.08 : 0); border.width: root.activeFocus ? 1 : 0; border.color: root.accent }
    ActionButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 6; visible: !!root.actionText; text: root.actionText; foreground: root.foreground; accent: root.accent; onClicked: root.actionClicked() }
    contentItem: RowLayout {
        spacing: 12
        Text { Layout.preferredWidth: 28; text: root.selected ? '▶' : root.number; color: root.selected ? root.accent : root.muted; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 12 }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 3
            Text { Layout.fillWidth: true; text: root.track.title || root.track.name || 'Untitled'; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.foreground; font.pixelSize: 14 }
            Text { Layout.fillWidth: true; text: root.track.artist || ''; textFormat: Text.PlainText; elide: Text.ElideRight; color: root.muted; font.pixelSize: 11 }
        }
        Text { text: Math.floor((root.track.duration || 0) / 60) + ':' + ('0' + Math.floor((root.track.duration || 0) % 60)).slice(-2); color: root.muted; font.pixelSize: 12 }
    }
}
