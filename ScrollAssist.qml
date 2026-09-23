import QtQuick
import QtQuick.Window

Item {
    id: root
    required property Flickable flickable
    parent: flickable
    anchors.fill: parent
    z: 10
    property bool scrolling: false
    property real anchorY: 0
    property real pointerY: 0
    property color accent: '#81a1c1'
    signal scrolled()
    function stop() { scrolling = false }
    function scrollBy(delta) {
        const low = flickable.originY
        const high = low + Math.max(0, flickable.contentHeight - flickable.height)
        flickable.contentY = Math.max(low, Math.min(high, flickable.contentY + delta))
        scrolled()
    }
    onEnabledChanged: if (!enabled) stop()
    onVisibleChanged: if (!visible) stop()
    Connections {
        target: root.Window.window
        function onActiveChanged() { if (!root.Window.window.active) root.stop() }
    }
    Shortcut { sequence: 'Escape'; enabled: root.scrolling; onActivated: root.stop() }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        onWheel: event => {
            root.stop()
            // Pixel deltas are trackpad motion; retain their native distance.
            if (event.pixelDelta.y) root.scrollBy(-event.pixelDelta.y)
            else root.scrollBy(-event.angleDelta.y)
            event.accepted = true
        }
    }
    WheelHandler {
        acceptedDevices: PointerDevice.TouchPad
        blocking: false
        onWheel: event => { root.stop(); event.accepted = false }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: root.scrolling ? Qt.AllButtons : Qt.MiddleButton
        hoverEnabled: true
        propagateComposedEvents: true
        onPositionChanged: mouse => root.pointerY = mouse.y
        onPressed: mouse => {
            if (root.scrolling) root.stop()
            else if (mouse.button === Qt.MiddleButton) {
                root.flickable.cancelFlick()
                root.anchorY = mouse.y; root.pointerY = mouse.y
                root.scrolling = true
            }
        }
    }
    Timer {
        interval: 16; repeat: true; running: root.scrolling && root.enabled && root.visible
        onTriggered: {
            const distance = root.pointerY - root.anchorY
            const speed = Math.sign(distance) * Math.min(24, Math.max(0, Math.abs(distance) - 12) * 0.12)
            root.scrollBy(speed)
        }
    }
    Rectangle {
        visible: root.scrolling; x: root.width / 2 - 12; y: root.anchorY - 12
        width: 24; height: 24; radius: 12; color: root.accent
        Text { anchors.centerIn: parent; text: '↕'; color: '#181c22' }
    }
}
