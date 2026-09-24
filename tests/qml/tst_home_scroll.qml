import QtQuick
import QtTest
import '../..'

TestCase {
    name: 'HomeScroll'; when: windowShown; visible: true
    width: 620; height: 340
    QtObject {
        id: service
        property var state: ({config:{wheel_scroll_pixels:1200,wheel_acceleration:false},
            homeRecent:Array.from({length:60}, (_, i) => ({id:String(i),name:'Record ' + i,artist:'Artist'})),
            homeRediscover:[]})
        function send(cmd, args) {}
    }
    HomeView { id: home; anchors.fill: parent; service: service; foreground:'white'; surface:'#111111'; accent:'#55bbee'; muted:'#888888' }
    function test_wheel_speed_applies_on_home() {
        const flickable = home.contentItem
        verify(flickable.contentHeight > flickable.height + 1200)
        flickable.contentY = 0
        mouseWheel(flickable, 120, 180, 0, -120)
        wait(150)
        compare(flickable.contentY, 1200)
    }
}
