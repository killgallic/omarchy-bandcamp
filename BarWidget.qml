import QtQuick
import "TextFormat.js" as Format
import Quickshell
import qs.Ui as Ui
import qs.Commons

Ui.BarWidget {
    id: root
    moduleName: 'killgallic.bandcamp'
    readonly property var player: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    readonly property var config: player ? player.state.config || ({}) : ({})
    readonly property bool hasTrack: !!(player && player.state.current && (player.state.current.id || player.state.current.title || player.state.current.name))
    property bool popupOpen: false
    readonly property bool opened: popupOpen
    visible: !!player && player.active
    function open() { if (config.mini_player_enabled === false) { openLibrary(); return }; if (player) player.start(); popupOpen = true }
    function runAction(action) {
        if (action === 'mini' && config.mini_player_enabled === false) action = 'library'
        if (action === 'mini') {
            toggle()
        } else if (action === 'library') {
            close()
            if (player && player.libraryVisible) player.libraryToggleRequested()
            else openLibrary()
        } else if (action === 'play_pause' && player) player.send('toggle')
    }
    function close() { popupOpen = false }
    function toggle() { if (popupOpen) close(); else open() }
    function openLibrary() {
        close()
        if (bar && bar.shell) bar.shell.summon(moduleName, '{}')
    }
    Connections {
        target: root.player
        function onStateChanged() { if (root.config.mini_player_enabled === false) root.close() }
        function onActiveChanged() { if (!root.player.active) root.close() }
    }
    implicitWidth: !visible ? 0 : vertical ? barSize : (config.bar_display === 'icon' ? 42 :
        (!hasTrack && config.bar_compact_when_idle !== false
            ? Math.min(config.bar_width || 240, Math.ceil(idleText.implicitWidth) + (config.bar_display === 'title' ? 24 : 49))
            : (config.bar_width || 240)))
    implicitHeight: barSize
    Text { id: idleText; visible: false; text: 'Bandcamp'; font.family: Style.font.family; font.pixelSize: Style.font.body }
    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7
        Image {
            visible: root.vertical || root.config.bar_display !== 'title'
            width: 18; height: 12
            anchors.verticalCenter: parent.verticalCenter
            source: 'assets/bandcamp.svg'
            sourceSize: Qt.size(54, 36)
            smooth: true
        }
        NowPlayingText {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.vertical && root.config.bar_display !== 'icon'
            width: Math.max(40, root.width - (root.config.bar_display === 'title' ? 24 : 49))
            text: Format.render(root.config.bar_preset === 'custom' ? root.config.bar_format : Format.presets[root.config.bar_preset || 'compact'], root.player ? root.player.state.current : null, root.player && root.player.state.playing)
            playing: root.player && root.player.state.playing
            reducedMotion: root.config.reduced_motion === true
            mode: root.config.bar_text_mode || 'marquee'
            speed: root.config.bar_scroll_speed || 30
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: event => {
            if (event.button === Qt.MiddleButton) { if (root.player) root.player.send('toggle') }
            else root.runAction(event.button === Qt.RightButton ? (root.config.bar_right_action || 'mini') : (root.config.bar_left_action || 'library'))
        }
        onWheel: event => { if (root.player) root.player.send(event.angleDelta.y > 0 ? 'previous' : 'next') }
    }
    // Use the host's popup coordinator and outside-click handling.
    Ui.KeyboardPanel {
        anchorItem: root
        bar: root.bar
        owner: root
        open: root.popupOpen
        contentWidth: fittedContentWidth(root.config.mini_player_width || 460)
        contentHeight: fittedContentHeight(236)
        MiniPlayer {
            anchors.fill: parent
            service: root.player
            foreground: Color.foreground; background: Color.background; accent: Color.accent; muted: Color.muted
            onOpenRequested: root.openLibrary()
            onQuitRequested: { if (root.player) root.player.requestQuit(); root.close() }
        }
    }
}
