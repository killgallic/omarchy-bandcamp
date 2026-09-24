import QtQuick
Item {
    id: root
    property string text: ''
    property color color: 'white'
    property alias font: label.font
    property bool playing: false
    property bool reducedMotion: false
    property string mode: 'marquee'
    property real speed: 30
    readonly property bool scrolling: visible && playing && !reducedMotion && mode === 'marquee' && label.implicitWidth > width
    implicitHeight: label.implicitHeight
    clip: true
    onTextChanged: { motion.restart(); if (!scrolling) motion.stop() }
    Text {
        id: label; text: root.text; textFormat: Text.PlainText; color: root.color
        width: root.scrolling || root.mode === 'static' ? implicitWidth : root.width
        elide: root.mode === 'static' ? Text.ElideNone : Text.ElideRight
    }
    SequentialAnimation {
        id: motion; running: root.scrolling; loops: Animation.Infinite
        PropertyAction { target: label; property: 'x'; value: 0 }
        PauseAnimation { duration: 1500 }
        NumberAnimation { target: label; property: 'x'; to: Math.min(0, root.width - label.implicitWidth); duration: Math.max(1, (label.implicitWidth - root.width) / root.speed * 1000) }
        PauseAnimation { duration: 1500 }
    }
    onScrollingChanged: if (!scrolling) label.x = 0
}
