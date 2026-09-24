import QtQuick
import QtQuick.Window

Item {
    id: root
    required property Flickable flickable
    parent: flickable
    anchors.fill: parent
    z: 10
    property bool scrolling: false
    property real wheelStep: 360
    property bool wheelAcceleration: true
    property real lastWheelTime: 0
    property int lastWheelDirection: 0
    property int wheelBurst: 0
    function shouldHandleWheel(deviceType, pixels) {
        // Some discrete mice arrive as TouchPad devices on Wayland. Pixel deltas
        // distinguish a smooth gesture, which should keep native scrolling.
        return deviceType !== PointerDevice.TouchPad || pixels === 0
    }
    function resetWheel() { lastWheelTime = 0; lastWheelDirection = 0; wheelBurst = 0 }
    function mouseWheelDistance(angle, pixels, now) {
        // Mouse wheels can supply both deltas: prefer their angle so the configured
        // distance is not bypassed by the small pixel delta on high-resolution mice.
        // Some mice send several small angle or pixel deltas per wheel motion.
        // A concave curve keeps those events useful at the chosen speed while a
        // standard 120-unit notch still travels exactly wheelStep pixels.
        const units = angle ? -angle / 120 : -pixels / 15
        const base = Math.sign(units) * Math.pow(Math.abs(units), 0.55) * wheelStep
        if (!base) return 0
        const direction = Math.sign(base)
        const elapsed = now - lastWheelTime
        if (!wheelAcceleration || direction !== lastWheelDirection || elapsed > 260 || elapsed < 0)
            wheelBurst = 0
        else if (elapsed <= 160)
            wheelBurst = Math.min(5, wheelBurst + 1)
        else
            wheelBurst = Math.max(0, wheelBurst - 1)
        lastWheelTime = now
        lastWheelDirection = direction
        const boost = wheelAcceleration ? Math.min(5, Math.pow(1.45, wheelBurst)) : 1
        return direction * Math.min(wheelStep * 5, Math.abs(base) * boost)
    }
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
    onEnabledChanged: if (!enabled) { stop(); resetWheel() }
    onVisibleChanged: if (!visible) { stop(); resetWheel() }
    Shortcut { sequence: 'Escape'; enabled: root.scrolling; onActivated: root.stop() }
    WheelHandler {
        objectName: 'discreteWheelHandler'
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            root.stop()
            if (!root.shouldHandleWheel(event.device.type, event.pixelDelta.y)) {
                event.accepted = false
                return
            }
            root.flickable.cancelFlick()
            root.scrollBy(root.mouseWheelDistance(event.angleDelta.y, event.pixelDelta.y, Date.now()))
            event.accepted = true
        }
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
            if (!root.Window.window || !root.Window.window.active) { root.stop(); return }
            const distance = root.pointerY - root.anchorY
            const speed = Math.sign(distance) * Math.min(24, Math.max(0, Math.abs(distance) - 12) * 0.12)
            root.scrollBy(speed)
        }
    }
    Rectangle {
        visible: root.scrolling; x: root.width / 2 - 12; y: root.anchorY - 12
        width: 24; height: 24; radius: 12; color: root.accent
        Text { anchors.centerIn: parent; text: '↕'; color: (root.accent.r * 0.299 + root.accent.g * 0.587 + root.accent.b * 0.114) > 0.5 ? Qt.darker(root.accent, 4) : Qt.lighter(root.accent, 4) }
    }
}
