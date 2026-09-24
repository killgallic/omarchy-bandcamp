import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'ScrollAssist'; when: windowShown; visible: true
    width: 400; height: 300
    Flickable { id: list; anchors.fill: parent; contentHeight: 2000
        ScrollAssist { id: assist; flickable: list }
    }
    function init() {
        assist.resetWheel()
        assist.wheelStep = 360
        assist.wheelAcceleration = true
        assist.reducedMotion = false
        list.contentHeight = 2000
        list.contentY = 0
    }
    function test_bounds() {
        list.contentY = 0
        assist.scrollBy(-120)
        compare(list.contentY, 0)
        assist.scrollBy(120)
        compare(list.contentY, 120)
        assist.scrollBy(10000)
        compare(list.contentY, 1700)
    }
    function test_pointer_motion_and_wheel_cancel() {
        list.contentY = 200
        mouseClick(list, 100, 100, Qt.MiddleButton)
        mouseMove(list, 100, 220)
        wait(80)
        verify(list.contentY > 200)
        mouseWheel(list, 100, 220, 0, -120)
        verify(!assist.scrolling)
        assist.resetWheel()
        list.contentY = 200
        mouseWheel(list, 100, 100, 0, -120)
        tryCompare(list, 'contentY', 560, 1000)
        assist.resetWheel()
        assist.wheelStep = 600
        mouseWheel(list, 100, 100, 0, -120)
        tryCompare(list, 'contentY', 1160, 1000)
        assist.wheelStep = 360
    }
    function test_fast_wheel_accelerates_and_pause_or_reverse_resets() {
        assist.resetWheel()
        const first = assist.mouseWheelDistance(-120, -15, 1000)
        const second = assist.mouseWheelDistance(-120, -15, 1080)
        const third = assist.mouseWheelDistance(-120, -15, 1160)
        compare(first, 360)
        verify(second > first)
        verify(third > second)
        compare(assist.mouseWheelDistance(-120, -15, 1600), 360)
        compare(assist.mouseWheelDistance(120, 15, 1650), -360)
        for (let i = 0; i < 30; i++) verify(Math.abs(assist.mouseWheelDistance(120, 15, 1700 + i * 20)) <= 1800)
        assist.wheelAcceleration = false
        compare(assist.mouseWheelDistance(120, 15, 2400), -360)
        compare(assist.mouseWheelDistance(120, 15, 2420), -360)
        assist.wheelAcceleration = true
        assist.resetWheel()
    }
    function test_middle_toggle_and_cancel() {
        mouseClick(list, 100, 100, Qt.MiddleButton)
        verify(assist.scrolling)
        mouseClick(list, 100, 100, Qt.MiddleButton)
        verify(!assist.scrolling)
        mouseClick(list, 100, 100, Qt.MiddleButton)
        assist.enabled = false
        verify(!assist.scrolling)
        assist.enabled = true
    }
    function test_high_resolution_wheel_respects_speed() {
        assist.wheelStep = 1200
        assist.wheelAcceleration = false
        assist.resetWheel()
        verify(assist.mouseWheelDistance(-15, -2, 1000) >= 300)
        assist.resetWheel()
        verify(assist.mouseWheelDistance(0, -2, 1000) >= 200)
        assist.wheelStep = 360
        assist.wheelAcceleration = true
    }
    function test_discrete_touchpad_classified_wheel_uses_mouse_path() {
        const handler = findChild(assist, 'discreteWheelHandler')
        verify(handler)
        verify((handler.acceptedDevices & PointerDevice.TouchPad) !== 0)
        verify(assist.shouldHandleWheel(PointerDevice.TouchPad, 0))
        verify(!assist.shouldHandleWheel(PointerDevice.TouchPad, 12))
        verify(assist.shouldHandleWheel(PointerDevice.Mouse, 12))
    }
    function test_wheel_notches_animate_to_accumulated_target() {
        assist.wheelAcceleration = false
        assist.resetWheel()
        list.contentY = 0
        mouseWheel(list, 100, 100, 0, -120)
        const motion = findChild(assist, 'wheelMotion')
        verify(motion && motion.running)
        verify(list.contentY < 360)
        mouseWheel(list, 100, 100, 0, -120)
        compare(assist.wheelTarget, 720)
        tryVerify(() => !motion.running, 1000)
        compare(list.contentY, 720)
        assist.wheelAcceleration = true
    }
    function test_reduced_motion_moves_immediately() {
        assist.reducedMotion = true
        assist.wheelAcceleration = false
        list.contentY = 0
        mouseWheel(list, 100, 100, 0, -120)
        compare(list.contentY, 360)
        assist.reducedMotion = false
        assist.wheelAcceleration = true
    }
    function test_reversing_wheel_uses_current_position() {
        assist.wheelAcceleration = false
        assist.wheelStep = 1200
        list.contentHeight = 6000
        list.contentY = 0
        assist.resetWheel()
        mouseWheel(list, 100, 100, 0, -120)
        mouseWheel(list, 100, 100, 0, -120)
        wait(50)
        const position = list.contentY
        verify(position > 0 && position < 1200)
        mouseWheel(list, 100, 100, 0, 120)
        verify(assist.wheelTarget < position)
        tryCompare(list, 'contentY', 0, 1000)
        list.contentHeight = 2000
        assist.wheelStep = 360
        assist.wheelAcceleration = true
    }
}
