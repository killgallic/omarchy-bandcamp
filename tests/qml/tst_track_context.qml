import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'TrackContext'; when: windowShown; visible: true
    width: 600; height: 120
    TrackRow { id: row; width: 590; track: ({title:'One',artist:'Artist'}); actionText:'Remove' }
    SignalSpy { id: context; target: row; signalName:'contextRequested' }
    SignalSpy { id: playback; target: row; signalName:'clicked' }
    SignalSpy { id: action; target: row; signalName:'actionClicked' }
    function init() { context.clear(); playback.clear(); action.clear() }
    function test_mouse_context_preserves_left_playback_and_action() {
        mouseClick(row, 100, 25, Qt.RightButton)
        compare(context.count, 1)
        compare(playback.count, 0)
        mouseClick(row, 100, 25, Qt.LeftButton)
        compare(playback.count, 1)
        mouseClick(findChild(row, 'trackAction'))
        compare(action.count, 1)
        compare(playback.count, 1)
        mouseClick(findChild(row, 'trackOverflow'))
        compare(context.count, 2)
        compare(playback.count, 1)
    }
    function test_keyboard_context() {
        row.forceActiveFocus()
        keyClick(Qt.Key_F10, Qt.ShiftModifier)
        keyClick(Qt.Key_Menu)
        compare(context.count, 2)
        compare(playback.count, 0)
    }
}
