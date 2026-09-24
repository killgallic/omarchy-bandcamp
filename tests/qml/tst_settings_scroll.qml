import QtQuick
import QtTest
import '../..'

TestCase {
    name: 'SettingsScroll'; when: windowShown; visible: true
    width: 620; height: 340
    QtObject {
        id: service
        property var state: ({config:{wheel_scroll_pixels:1200,wheel_acceleration:false}, metadataJob:{}, cacheStats:{}})
        function send(cmd, args) {}
    }
    SettingsView { id: settings; anchors.fill: parent; service: service }
    function test_wheel_speed_applies_in_settings() {
        const flickable = settings.contentItem
        verify(flickable.contentHeight > flickable.height + 300)
        flickable.contentY = 0
        mouseWheel(flickable, 120, 180, 0, -120)
        tryCompare(flickable, 'contentY', Math.min(1200, flickable.contentHeight - flickable.height), 1000)
    }
}
