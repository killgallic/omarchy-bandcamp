import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'ScrollAssist'; when: windowShown; visible: true
    width: 400; height: 300
    Flickable { id: list; anchors.fill: parent; contentHeight: 2000
        ScrollAssist { id: assist; flickable: list }
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
        list.contentY = 200
        mouseWheel(list, 100, 100, 0, -120)
        compare(list.contentY, 320)
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
}
