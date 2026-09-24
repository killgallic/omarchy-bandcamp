import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

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
            BandcampIcon { color: root.accent; width: 20; height: 20 }
            BusyIndicator { Layout.preferredWidth: 18; Layout.preferredHeight: 18; running: Boolean(root.service && root.service.state && root.service.state.loading); visible: running }
            ActionButton { text: 'Retry'; visible: root.service && !!root.service.state.error; foreground: root.foreground; surface: root.background; accent: root.accent; implicitHeight: 30; onClicked: root.service.send('retry') }
            ActionButton { Layout.fillWidth: true; text: 'bandcamp'; foreground: root.foreground; surface: root.background; accent: root.accent; onClicked: { root.service.homeRequested(); root.openRequested() } }
            ActionButton { text: root.service && root.service.state.connected ? 'Home' : 'Sign in'; foreground: root.foreground; surface: root.background; accent: root.accent; implicitHeight: 30; onClicked: { root.service.homeRequested(); root.openRequested() } }
            ActionButton { text: 'Quit'; foreground: root.foreground; surface: root.background; accent: root.accent; implicitHeight: 30; onClicked: root.quitRequested() }
        }
        Transport { Layout.fillWidth: true; Layout.fillHeight: true; compact: true; service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted }
    }
    NotificationToast {
        maximumVisible: 1
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 8
        z: 20
        center: root.service && root.service.notifications ? root.service.notifications : null
        foreground: root.foreground; background: root.background; accent: root.accent
    }

}
