import QtQuick

Rectangle {
    id: root
    property string source: ''
    property color foreground: '#d8dee9'
    property color background: '#252a32'
    color: background
    clip: true
    Text {
        anchors.centerIn: parent
        text: 'bc'
        color: root.foreground
        opacity: 0.25
        font.pixelSize: Math.max(16, root.width * 0.25)
        font.italic: true
        font.bold: true
    }
    Image {
        anchors.fill: parent
        source: root.source
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.min(600, root.width * 2), Math.min(600, root.height * 2))
    }
}
