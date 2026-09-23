import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: root
    required property var service
    property color foreground: '#d8dee9'
    property color surface: '#181c22'
    property color accent: '#81a1c1'
    palette.base: surface
    palette.window: surface
    palette.button: Qt.lighter(surface, 1.3)
    palette.text: foreground
    palette.windowText: foreground
    palette.buttonText: foreground
    palette.highlight: accent
    readonly property var config: service.state.config || ({})
    function configure(key, value) { const values = {}; values[key] = value; service.send('configure', {values: values}) }
    ColumnLayout {
        width: root.availableWidth; spacing: 16
        Text { text: 'Settings'; color: root.foreground; font.pixelSize: 27; font.bold: true }
        RowLayout {
            visible: root.config.show_discover_links !== false
            ActionButton { text: 'Discover music ↗'; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: Qt.openUrlExternally('https://bandcamp.com/discover') }
            ActionButton { text: 'Bandcamp Daily ↗'; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: Qt.openUrlExternally('https://daily.bandcamp.com/') }
        }
        Text { Layout.fillWidth: true; text: 'Public profile URL (for your photo)'; color: root.foreground }
        RowLayout {
            Layout.fillWidth: true
            TextField { id: profileUrl; Layout.fillWidth: true; text: root.config.profile_url || ''; placeholderText: 'https://bandcamp.com/yourname'; color: root.foreground }
            ActionButton { text: 'Save profile'; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.configure('profile_url', profileUrl.text.trim()) }
        }
        Text { Layout.fillWidth: true; text: (root.service.state.profile || {}).notice || ''; visible: !!text; color: root.foreground; wrapMode: Text.Wrap }
        Text { Layout.fillWidth: true; text: root.service.state.metadataNotice || ''; visible: !!text; color: root.foreground; wrapMode: Text.Wrap }
        CheckBox { text: 'Remember login securely'; checked: root.config.remember_login !== false; palette.windowText: root.foreground; onClicked: root.configure('remember_login', checked) }
        CheckBox { text: 'Enable mini player'; checked: root.config.mini_player_enabled !== false; palette.windowText: root.foreground; onClicked: root.configure('mini_player_enabled', checked) }
        RowLayout {
            Text { text: 'Mini player width'; color: root.foreground }
            SpinBox { from: 440; to: 900; stepSize: 20; value: root.config.mini_player_width || 460; onValueModified: root.configure('mini_player_width', value) }
            CheckBox { text: 'Show artwork'; checked: root.config.mini_show_artwork !== false; palette.windowText: root.foreground; onClicked: root.configure('mini_show_artwork', checked) }
        }
        RowLayout {
            Text { text: 'Bar display'; color: root.foreground }
            ComboBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; model: ['Icon', 'Track title', 'Icon and title']; currentIndex: Math.max(0, ['icon', 'title', 'icon_title'].indexOf(root.config.bar_display)); onActivated: root.configure('bar_display', ['icon', 'title', 'icon_title'][currentIndex]) }
        }
        RowLayout {
            Text { text: 'Bar click'; color: root.foreground }
            ComboBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; model: ['Mini player', 'Open library', 'Toggle library']; currentIndex: Math.max(0, ['mini', 'library', 'toggle_library'].indexOf(root.config.bar_click)); onActivated: root.configure('bar_click', ['mini', 'library', 'toggle_library'][currentIndex]) }
        }
        RowLayout {
            Text { text: 'Library width'; color: root.foreground }
            SpinBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; from: 700; to: 2200; stepSize: 50; value: root.config.large_player_width || 1000; editable: true; onValueModified: root.configure('large_player_width', value) }
            Text { text: 'Height'; color: root.foreground }
            SpinBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; from: 620; to: 1600; stepSize: 50; value: root.config.large_player_height || 760; editable: true; onValueModified: root.configure('large_player_height', value) }
        }
        CheckBox { text: 'Accelerate fast mouse-wheel scrolling'; checked: root.config.wheel_acceleration !== false; onClicked: root.configure('wheel_acceleration', checked) }
        RowLayout {
            Text { text: 'Mouse wheel pixels per notch'; color: root.foreground }
            SpinBox { from: 120; to: 1200; stepSize: 60; value: root.config.wheel_scroll_pixels || 360; onValueModified: root.configure('wheel_scroll_pixels', value) }
        }
        RowLayout {
            Text { text: 'Stream retry attempts'; color: root.foreground }
            SpinBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; from: 0; to: 5; value: root.config.stream_retries === undefined ? 2 : root.config.stream_retries; onValueModified: root.configure('stream_retries', value) }
        }
        CheckBox { text: 'Enrich tags with MusicBrainz'; checked: root.config.metadata_enrichment === true; palette.windowText: root.foreground; onClicked: root.configure('metadata_enrichment', checked) }
        Text { Layout.fillWidth: true; text: 'Optional: sends artist and album names to MusicBrainz and caches matches.'; color: root.foreground; wrapMode: Text.Wrap; font.pixelSize: 12 }
        CheckBox { text: 'Show discovery links'; checked: root.config.show_discover_links !== false; palette.windowText: root.foreground; onClicked: root.configure('show_discover_links', checked) }

    }
}
