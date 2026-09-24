import QtQuick

Item {
    id: root
    property string text: ''
    property color color: 'white'
    property alias font: ticker.font
    property bool playing: false
    property bool reducedMotion: false
    property string mode: 'marquee'
    property real speed: 30
    readonly property bool scrolling: visible && playing && !reducedMotion && mode === 'marquee' && ticker.implicitWidth > width
    implicitHeight: ticker.implicitHeight
    clip: true

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.scrolling
        width: root.width
        text: root.text
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        elide: Text.ElideRight
        color: root.color
        font: ticker.font
    }
    Text {
        id: ticker
        anchors.verticalCenter: parent.verticalCenter
        visible: root.scrolling
        width: implicitWidth
        text: root.text
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        color: root.color
    }
    SequentialAnimation {
        id: motion
        running: root.scrolling
        loops: Animation.Infinite
        PropertyAction { target: ticker; property: 'x'; value: 0 }
        PauseAnimation { duration: 1500 }
        NumberAnimation {
            target: ticker
            property: 'x'
            to: Math.min(0, root.width - ticker.implicitWidth)
            duration: Math.max(1, (ticker.implicitWidth - root.width) / Math.max(1, root.speed) * 1000)
        }
        PauseAnimation { duration: 1500 }
    }
    onTextChanged: if (scrolling) motion.restart()
    onScrollingChanged: if (!scrolling) ticker.x = 0
}
