import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'ScrollAssist'; when: windowShown; visible: true
    width: 400; height: 300
    Flickable { id: list; anchors.fill: parent; contentHeight: 2000
        ScrollAssist { id: assist; flickable: list }
    }
    function init() { assist.resetWheel() }
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
        compare(list.contentY, 560)
        assist.resetWheel()
        assist.wheelStep = 600
        mouseWheel(list, 100, 100, 0, -120)
        compare(list.contentY, 1160)
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
}
