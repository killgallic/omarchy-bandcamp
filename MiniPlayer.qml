import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    required property var service
    property color foreground: '#d8dee9'
    property color background: '#181c22'
    property color accent: '#81a1c1'
    property color muted: '#808994'
    signal openRequested()
    signal quitRequested()
    color: background
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 10
            Text { Layout.fillWidth: true; text: 'bandcamp'; color: root.foreground; font.pixelSize: 16; font.bold: true; font.italic: true }
            ActionButton { text: root.service && root.service.state.connected ? 'Collection' : 'Sign in'; foreground: root.foreground; surface: root.background; accent: root.accent; implicitHeight: 30; onClicked: root.openRequested() }
            ActionButton { text: 'Quit'; foreground: root.foreground; surface: root.background; accent: root.accent; implicitHeight: 30; onClicked: root.quitRequested() }
        }
        Transport { Layout.fillWidth: true; Layout.fillHeight: true; compact: true; service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted }
    }
}
