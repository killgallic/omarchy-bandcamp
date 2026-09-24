import QtQuick
import QtTest
import '../..'

TestCase {
    name: 'Notifications'; when: windowShown; visible: true
    width: 600; height: 300
    NotificationCenter { id: center; autoTick: false }
    NotificationToast { id: toast; width: 460; center: center }
    function init() { mouseMove(this, 570, 280) }
    function cleanup() { center.clear() }
    function test_lifetimes_and_hover_pause() {
        center.push({id:'saved', level:'success', message:'Saved'})
        center.advance(2999)
        compare(center.toasts.length, 1)
        center.setPaused('saved', true)
        center.advance(9000)
        compare(center.toasts.length, 1)
        center.setPaused('saved', false)
        center.advance(1)
        compare(center.toasts.length, 0)
        center.push({id:'failed', level:'error', message:'Could not play'})
        center.advance(7999)
        compare(center.toasts.length, 1)
        center.advance(1)
        compare(center.toasts.length, 0)
        compare(center.history[0].id, 'failed')
        center.dismiss('failed')
        compare(center.history.length, 1)
    }
    function test_coalesce_duplicate_and_bounded_history() {
        center.push({id:'save1', code:'settings_saved', level:'success', message:'Settings saved'})
        center.push({id:'save1', code:'settings_saved', level:'success', message:'Settings saved'})
        compare(center.history.length, 1)
        compare(center.history[0].count, 1)
        center.push({id:'save2', code:'settings_saved', level:'success', message:'Settings saved'})
        compare(center.history.length, 1)
        compare(center.history[0].count, 2)
        for (let i=0;i<30;i++) center.push({id:'event'+i, message:'Message '+i})
        compare(center.history.length, 20)
        compare(center.toasts.length, 3)
    }
    function test_legacy_dedup_and_resolution() {
        center.push({level:'error', message:'Playback failed', code:'legacy_error'})
        center.push({id:'native', level:'error', message:'Playback failed', code:'playback_failed', resourceId:'track:1'})
        compare(center.history.length, 1)
        center.resolve('track:1')
        compare(center.history.length, 0)
    }
    function test_dismiss_button_and_safe_actions() {
        center.push({id:'dismiss', message:'Saved', action:{id:'run_shell', label:'Unsafe'}})
        compare(center.history[0].action, null)
        wait(20)
        const button = findChild(toast, 'dismissNotification')
        verify(button)
        mouseClick(button)
        compare(center.toasts.length, 0)
        compare(center.history.length, 0)
    }
    function test_real_hover_and_keyboard_focus_pause() {
        center.push({id:'hover', level:'success', message:'Saved'})
        wait(20)
        mouseMove(toast, 30, 20)
        center.advance(4000)
        compare(center.toasts.length, 1)
        mouseMove(this, 570, 280)
        const button = findChild(toast, 'dismissNotification')
        button.forceActiveFocus()
        center.advance(4000)
        compare(center.toasts.length, 1)
        button.focus = false
        toast.forceActiveFocus()
        center.advance(3000)
        compare(center.toasts.length, 0)
    }
    function test_legacy_state_only_emits_changes() {
        center.ingestState({notice:'Saved'}, {})
        center.ingestState({notice:'Saved'}, {notice:'Saved'})
        compare(center.history.length, 1)
        compare(center.history[0].count, 1)
        center.ingestState({error:'First failure'}, {})
        center.ingestState({error:'Second failure'}, {error:'First failure'})
        compare(center.history.length, 3)
        center.ingestState({error:''}, {error:'Second failure'})
        compare(center.history.length, 1)
    }

    Component {
        id: playerComponent
        PlayerView { width: 800; height: 700; service: notificationService }
    }
    QtObject {
        id: notificationService
        property var state: ({connected: true, albums: [], queue: []})
        property string processError: ''
        property var notifications: center
        function send(cmd, args) {}
    }
    function test_player_history_opens_and_retains_expired_errors() {
        const player = createTemporaryObject(playerComponent, this)
        verify(player)
        center.push({id:'history', level:'error', message:'Playback failed'})
        center.advance(8000)
        compare(center.toasts.length, 0)
        wait(20)
        const button = findChild(player, 'notificationHistoryButton')
        verify(button.visible)
        // Trigger the accessible button action without depending on the fixture viewport.
        button.clicked()
        const popup = findChild(player, 'notificationHistoryPopup')
        tryCompare(popup, 'opened', true)
        compare(center.history.length, 1)
        popup.close()
    }
    function test_history_wheel_uses_player_speed() {
        notificationService.state = Object.assign({}, notificationService.state, {config:{wheel_scroll_pixels:1200,wheel_acceleration:false}})
        const player = createTemporaryObject(playerComponent, this)
        verify(player)
        for (let i = 0; i < 20; i++) center.push({id:'item'+i, message:'A long notification about item '+i+' in the music collection'})
        findChild(player, 'notificationHistoryButton').clicked()
        const popup = findChild(player, 'notificationHistoryPopup')
        tryCompare(popup, 'opened', true)
        wait(50)
        const view = findChild(player, 'activityScroll')
        verify(view)
        const flickable = view.contentItem
        verify(flickable.contentHeight > flickable.height + 300)
        flickable.contentY = 0
        mouseWheel(flickable, 80, 80, 0, -120)
        compare(flickable.contentY, Math.min(1200, flickable.contentHeight - flickable.height))
        popup.close()
    }

}
