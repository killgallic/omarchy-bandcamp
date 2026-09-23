import QtQuick
Item {
    id: root
    property color color: '#1da0c3'
    implicitWidth: 24; implicitHeight: 24
    Canvas {
        id: drawing
        anchors.fill: parent
        onPaint: {
            const ctx = getContext('2d')
            ctx.reset()
            ctx.fillStyle = root.color
            ctx.beginPath()
            ctx.moveTo(width * 0.27, height * 0.25)
            ctx.lineTo(width, height * 0.25)
            ctx.lineTo(width * 0.73, height * 0.75)
            ctx.lineTo(0, height * 0.75)
            ctx.closePath()
            ctx.fill()
        }
        Connections { target: root; function onColorChanged() { drawing.requestPaint() } }
    }
}
