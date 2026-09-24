import QtQuick
import "TextFormat.js" as Format
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
    readonly property var metadataJob: service.state.metadataJob || ({})
    readonly property var cacheStats: service.state.cacheStats || ({})
    function configure(key, value) { const values = {}; values[key] = value; service.send('configure', {values: values}) }
    ColumnLayout {
        width: root.availableWidth; spacing: 16
        Text { text: 'Settings'; color: root.foreground; font.pixelSize: 27; font.bold: true }
        Text { text: 'Account'; color: root.foreground; font.pixelSize: 19; font.bold: true }
        Text { Layout.fillWidth: true; text: 'Public profile URL (for your photo)'; color: root.foreground }
        RowLayout {
            Layout.fillWidth: true
            TextField { id: profileUrl; Layout.fillWidth: true; text: root.config.profile_url || ''; placeholderText: 'https://bandcamp.com/yourname'; color: root.foreground }
            ActionButton { text: 'Save profile'; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.configure('profile_url', profileUrl.text.trim()) }
        }
        Text { Layout.fillWidth: true; text: (root.service.state.profile || {}).notice || ''; visible: !!text; color: root.foreground; wrapMode: Text.Wrap }
        Text { Layout.fillWidth: true; text: root.service.state.metadataNotice || ''; visible: !!text; color: root.foreground; wrapMode: Text.Wrap }
        CheckBox { text: 'Remember login securely'; checked: root.config.remember_login !== false; palette.windowText: root.foreground; onClicked: root.configure('remember_login', checked) }
        Text { text: 'Player windows'; color: root.foreground; font.pixelSize: 19; font.bold: true }
        CheckBox { text: 'Enable mini player'; checked: root.config.mini_player_enabled !== false; palette.windowText: root.foreground; onClicked: root.configure('mini_player_enabled', checked) }
        RowLayout {
            Text { text: 'Mini player width'; color: root.foreground }
            SpinBox { from: 440; to: 900; stepSize: 20; value: root.config.mini_player_width || 460; onValueModified: root.configure('mini_player_width', value) }
            CheckBox { text: 'Show artwork'; checked: root.config.mini_show_artwork !== false; palette.windowText: root.foreground; onClicked: root.configure('mini_show_artwork', checked) }
        }
        Text { text: 'Omarchy bar'; color: root.foreground; font.pixelSize: 19; font.bold: true }
        RowLayout {
            Text { text: 'Bar display'; color: root.foreground }
            ComboBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; model: ['Icon', 'Track title', 'Icon and title']; currentIndex: Math.max(0, ['icon', 'title', 'icon_title'].indexOf(root.config.bar_display)); onActivated: root.configure('bar_display', ['icon', 'title', 'icon_title'][currentIndex]) }
        }
        RowLayout {
            Text { text: 'Now playing format'; color: root.foreground }
            ComboBox {
                model: ['Artist — Song', 'Song', 'Artist — Album — Song', 'Artist — Album', 'Custom']
                currentIndex: Math.max(0, ['compact','track','full','record','custom'].indexOf(root.config.bar_preset || 'compact'))
                onActivated: root.configure('bar_preset', ['compact','track','full','record','custom'][currentIndex])
            }
        }
        RowLayout {
            visible: root.config.bar_preset === 'custom'; Layout.fillWidth: true
            TextField { id: customFormat; Layout.fillWidth: true; text: root.config.bar_format || '{Artist} — {Song Name}'; maximumLength: 240 }
            ActionButton { text: 'Save format'; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.configure('bar_format', customFormat.text) }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.foreground; textFormat: Text.PlainText; text: 'Preview: ' + Format.render(root.config.bar_preset === 'custom' ? customFormat.text : Format.presets[root.config.bar_preset || 'compact'], {artist:'Artist',album:'Album',title:'Song Name'}, true) }
        Text { visible: root.config.bar_preset === 'custom'; text: 'Fields: {Artist}, {Album}, {Song Name}, {State}'; color: root.foreground }
        RowLayout {
            Text { text: 'Overflow'; color: root.foreground }
            ComboBox { model: ['Scrolling text', 'Ellipsis', 'Clip']; currentIndex: Math.max(0, ['marquee','elide','static'].indexOf(root.config.bar_text_mode || 'marquee')); onActivated: root.configure('bar_text_mode', ['marquee','elide','static'][currentIndex]) }
            Text { text: 'Width'; color: root.foreground }
            SpinBox { from: 100; to: 600; stepSize: 20; value: root.config.bar_width || 240; onValueModified: root.configure('bar_width', value) }
            Text { text: 'px/s'; color: root.foreground }
            SpinBox { from: 10; to: 100; value: root.config.bar_scroll_speed || 30; onValueModified: root.configure('bar_scroll_speed', value) }
        }
        CheckBox { text: 'Reduce motion'; checked: root.config.reduced_motion === true; onClicked: root.configure('reduced_motion', checked) }
        Repeater {
            model: [{label: 'Left click', key: 'bar_left_action', fallback: 'library'}, {label: 'Right click', key: 'bar_right_action', fallback: 'mini'}]
            RowLayout {
                required property var modelData
                Text { text: modelData.label; color: root.foreground }
                ComboBox {
                    model: ['Full player', 'Mini player', 'Play / pause', 'Do nothing']
                    currentIndex: Math.max(0, ['library', 'mini', 'play_pause', 'none'].indexOf(root.config[modelData.key] || modelData.fallback))
                    onActivated: root.configure(modelData.key, ['library', 'mini', 'play_pause', 'none'][currentIndex])
                }
            }
        }
        RowLayout {
            Text { text: 'Library width'; color: root.foreground }
            SpinBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; from: 700; to: 2200; stepSize: 50; value: root.config.large_player_width || 1000; editable: true; onValueModified: root.configure('large_player_width', value) }
            Text { text: 'Height'; color: root.foreground }
            SpinBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; from: 620; to: 1600; stepSize: 50; value: root.config.large_player_height || 760; editable: true; onValueModified: root.configure('large_player_height', value) }
        }
        Text { text: 'Scrolling & playback'; color: root.foreground; font.pixelSize: 19; font.bold: true }
        CheckBox { text: 'Accelerate fast mouse-wheel scrolling'; checked: root.config.wheel_acceleration !== false; onClicked: root.configure('wheel_acceleration', checked) }
        RowLayout {
            Text { text: 'Mouse speed'; color: root.foreground }
            Slider {
                id: wheelSpeed; Layout.fillWidth: true; from: 120; to: 1200; stepSize: 60
                value: root.config.wheel_scroll_pixels || 360
                onMoved: wheelSave.restart()
                onPressedChanged: if (!pressed) wheelSave.restart()
                Timer { id: wheelSave; interval: 300; onTriggered: if (!wheelSpeed.pressed) root.configure('wheel_scroll_pixels', Math.round(wheelSpeed.value)) }
            }
            Text { text: Math.round(wheelSpeed.value) + ' px / notch'; color: root.foreground }
        }
        RowLayout {
            Text { text: 'Stream retry attempts'; color: root.foreground }
            SpinBox { palette.text: root.foreground; palette.buttonText: root.foreground; palette.base: root.surface; palette.button: Qt.lighter(root.surface, 1.3); palette.window: root.surface; palette.highlight: root.accent; from: 0; to: 5; value: root.config.stream_retries === undefined ? 2 : root.config.stream_retries; onValueModified: root.configure('stream_retries', value) }
        }
        Text { text: 'Collection tags'; color: root.foreground; font.pixelSize: 19; font.bold: true }
        CheckBox { text: 'Enrich tags with MusicBrainz'; checked: root.config.metadata_enrichment === true; palette.windowText: root.foreground; onClicked: root.configure('metadata_enrichment', checked) }
        Text { Layout.fillWidth: true; text: 'Optional: sends artist and album names to MusicBrainz and caches matches.'; color: root.foreground; wrapMode: Text.Wrap; font.pixelSize: 12 }
        RowLayout {
            visible: root.config.metadata_enrichment === true
            ActionButton { text: root.service.state.metadataBusy ? 'Scanning…' : 'Generate tags'; enabled: !root.service.state.metadataBusy; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.service.send('generate_tags', {mode:'missing'}) }
            ActionButton { text: 'Refresh all'; enabled: !root.service.state.metadataBusy; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.service.send('generate_tags', {mode:'all'}) }
            ActionButton { text: 'Cancel'; visible: root.service.state.metadataBusy === true; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.service.send('cancel_tags') }
        }
        ProgressBar { Layout.fillWidth: true; visible: root.service.state.metadataBusy === true; from: 0; to: Math.max(1, (root.service.state.metadataJob || {}).total || 1); value: (root.service.state.metadataJob || {}).processed || 0 }
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.foreground
            visible: root.config.metadata_enrichment === true
            text: {
                const job = root.metadataJob || {}
                return job.status === 'running' ? 'Scanning ' + (job.processed || 0) + ' / ' + (job.total || 0) + ' records · ' + (job.enriched || 0) + ' tagged · ' + (job.cached || 0) + ' cached'
                    : job.status === 'complete' ? 'Last scan: ' + (job.lastCompletedAt ? new Date(job.lastCompletedAt * 1000).toLocaleString() : 'just now') + ' · ' + (job.enriched || 0) + ' tagged · ' + (job.cached || 0) + ' cached · ' + (job.unmatched || 0) + ' unmatched · ' + (job.ambiguous || 0) + ' ambiguous'
                    : 'MusicBrainz is enabled. Generate tags to scan your collection; cached tags load automatically.'
            }
        }
        Text { text: 'Local cache'; color: root.foreground; font.pixelSize: 19; font.bold: true }
        RowLayout {
            Text { text: 'Total cache limit'; color: root.foreground }
            SpinBox { from: 32; to: 2048; stepSize: 32; value: root.config.cache_budget_mb || 256; onValueModified: root.configure('cache_budget_mb', value) }
            Text { text: 'MiB'; color: root.foreground }
            ActionButton { text: 'Inspect'; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.service.send('cache_stats') }
        }
        RowLayout {
            Text { text: 'Collection snapshot lifetime'; color: root.foreground }
            SpinBox { from: 1; to: 1440; value: root.config.cache_ttl_minutes || 15; onValueModified: root.configure('cache_ttl_minutes', value) }
            Text { text: 'minutes'; color: root.foreground }
        }
        Text {
            color: root.foreground
            text: {
                const stats = root.cacheStats || {}
                return 'Total ' + Math.round((stats.total_bytes || 0) / 1048576) + ' MiB · Artwork ' + Math.round((stats.artwork_bytes || 0) / 1048576) + ' MiB · Profile ' + Math.round((stats.profile_bytes || 0) / 1024) + ' KiB · Tags ' + Math.round((stats.metadata_bytes || 0) / 1024) + ' KiB · Collection ' + Math.round((stats.collection_bytes || 0) / 1024) + ' KiB'
            }
        }
        Flow {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: [{name:'Clear artwork',category:'artwork'},{name:'Clear profile photo',category:'profile'},{name:'Clear MusicBrainz tags',category:'metadata'},{name:'Clear collection preview',category:'collection'}]
                ActionButton { required property var modelData; text: modelData.name; foreground: root.foreground; surface: root.surface; accent: root.accent; onClicked: root.service.send('clear_cache', {category:modelData.category}) }
            }
        }
        Text { Layout.fillWidth: true; text: 'Cache controls only remove downloaded images and tag matches. Playlists, listening history, and login stay saved.'; color: root.foreground; wrapMode: Text.Wrap; font.pixelSize: 12 }

    }
}
