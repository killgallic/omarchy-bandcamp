import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var service
    property color foreground: '#d8dee9'
    property color background: '#181c22'
    property color accent: '#81a1c1'
    property color muted: '#808994'
    property string fontFamily: 'sans-serif'
    property bool showErrors: false
    property string page: 'collection'
    property string filter: ''
    property var selectedArtists: []
    property var selectedGenres: []
    property var selectedTags: []
    readonly property var state: service ? service.state : ({})
    readonly property var libraryAlbums: state.albums || []
    readonly property var album: state.album || ({})
    readonly property var records: libraryAlbums.filter(a => matches(a, ''))
    readonly property var artistOptions: facetOptions('Artist')
    readonly property var genreOptions: facetOptions('Genre')
    readonly property var tagOptions: facetOptions('Tags')
    readonly property var activeFilters: selectedArtists.map(v => ({kind: 'Artist', value: v})).concat(selectedGenres.map(v => ({kind: 'Genre', value: v})), selectedTags.map(v => ({kind: 'Tags', value: v})))
    readonly property var sortOptions: [{value:'artist',label:'Artist A–Z'}, {value:'album',label:'Album A–Z'}, {value:'newest',label:'Recently added'}, {value:'most_played',label:'Most played here'}, {value:'recent_played',label:'Recently played here'}]
    function valuesFor(a, kind) { return kind === 'Artist' ? [a.artist || ''] : kind === 'Genre' ? [a.genre || ''] : (a.tags || []) }
    function matches(a, skip) {
        const text = ((a.name || a.title || '') + ' ' + (a.artist || '')).toLowerCase()
        return text.indexOf(filter.toLowerCase()) >= 0
            && (skip === 'Artist' || !selectedArtists.length || selectedArtists.indexOf(a.artist) >= 0)
            && (skip === 'Genre' || !selectedGenres.length || selectedGenres.indexOf(a.genre) >= 0)
            && (skip === 'Tags' || !selectedTags.length || (a.tags || []).some(t => selectedTags.indexOf(t) >= 0))
    }
    function facetOptions(kind) {
        const counts = Object.create(null)
        for (const a of libraryAlbums) {
            for (const value of valuesFor(a, kind)) {
                if (!value) continue
                if (counts[value] === undefined) counts[value] = 0
                if (matches(a, kind)) counts[value]++
            }
        }
        return Object.keys(counts).sort((a, b) => (kind === 'Genre' ? counts[b] - counts[a] : 0) || a.localeCompare(b)).map(value => ({value: value, label: value, count: counts[value]}))
    }
    function removeFilter(kind, value) {
        if (kind === 'Artist') selectedArtists = selectedArtists.filter(v => v !== value)
        else if (kind === 'Genre') selectedGenres = selectedGenres.filter(v => v !== value)
        else selectedTags = selectedTags.filter(v => v !== value)
    }
    signal minimizeRequested()
    signal quitRequested()
    color: background
    component Action: ActionButton {
        foreground: root.foreground; surface: root.background; accent: root.accent
        font.family: root.fontFamily
    }
    component Copy: Text {
        color: root.foreground; font.family: root.fontFamily; font.pixelSize: 14
        textFormat: Text.PlainText
    }
    component Field: TextField {
        color: root.foreground
        placeholderTextColor: root.muted
        selectionColor: root.accent
        selectedTextColor: root.background
        font.family: root.fontFamily
        font.pixelSize: 14
        leftPadding: 14; rightPadding: 14
        implicitHeight: 44
        background: Rectangle {
            radius: 5
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
            border.color: parent.activeFocus ? root.accent : root.muted
            border.width: 1
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 24
            spacing: 12
            Artwork { Layout.preferredWidth: 32; Layout.preferredHeight: 32; source: (root.state.profile || {}).art || ''; foreground: root.foreground }
            Copy { text: 'bandcamp'; font.pixelSize: 24; font.bold: true; font.italic: true; font.letterSpacing: -1 }
            Copy { text: ' /  YOUR RECORDS'; color: root.muted; font.pixelSize: 10; font.letterSpacing: 2; visible: root.width > 650 }
            Item { Layout.fillWidth: true }
            BusyIndicator { Layout.preferredWidth: 22; Layout.preferredHeight: 22; running: !!(root.state.loading || root.state.busy || root.state.metadataBusy); visible: running; ToolTip.visible: hovered; ToolTip.text: root.state.playbackStatus || 'Loading…' }
            Action { text: '⚠'; visible: !!root.state.error || !!root.service.processError; Accessible.name: 'Show player warning'; onClicked: root.showErrors = !root.showErrors }
            Action { text: 'Settings'; onClicked: root.page = 'settings' }
            Action { text: 'Mini'; visible: (root.state.config || {}).mini_player_enabled !== false; Accessible.name: 'Open mini player'; onClicked: root.minimizeRequested() }
            Action { text: 'Quit'; onClicked: root.quitRequested() }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.muted; opacity: 0.2 }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: message.implicitHeight + 24
            visible: !!message.text
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
            Copy { id: message; anchors.fill: parent; anchors.margins: 12; text: (root.showErrors ? ((root.service ? root.service.processError : '') || root.state.error) : '') || root.state.notice || ''; wrapMode: Text.Wrap; font.pixelSize: 13 }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: root.state.starting === true
            ColumnLayout {
                anchors.centerIn: parent
                BusyIndicator { Layout.alignment: Qt.AlignHCenter; running: parent.parent.visible }
                Copy { text: 'Reconnecting to your collection…'; color: root.muted }
            }
        }
        // Login fields live only while disconnected; no password survives login.
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            active: !root.state.connected && !root.state.starting
            visible: active
            sourceComponent: Component {
                Item {
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 64, 410)
                        spacing: 16
                        Copy { text: 'Your collection.\nA little closer.'; font.pixelSize: 32; font.bold: true; lineHeight: 1.15 }
                        Copy { Layout.fillWidth: true; text: '1. Open Bandcamp Fan Settings.\n2. Scroll down to Subsonic.\n3. Generate credentials and copy the separate username and password below.'; color: root.muted; wrapMode: Text.Wrap; lineHeight: 1.4 }
                        Action { text: 'Open Bandcamp Fan Settings'; onClicked: Qt.openUrlExternally('https://bandcamp.com/settings?pane=fan') }
                        Field { id: username; objectName: 'loginUsername'; Layout.fillWidth: true; placeholderText: 'Generated username'; Accessible.name: 'Generated Subsonic username'; enabled: !root.state.busy; onAccepted: password.forceActiveFocus() }
                        Field { id: password; objectName: 'loginPassword'; Layout.fillWidth: true; placeholderText: 'Generated password'; Accessible.name: 'Generated Subsonic password'; echoMode: TextInput.Password; enabled: !root.state.busy; onAccepted: if (login.enabled) login.clicked() }
                        Field { id: profile; Layout.fillWidth: true; placeholderText: 'Public profile URL (optional, for your photo)'; text: (root.state.config || {}).profile_url || ''; enabled: !root.state.busy }
                        CheckBox { id: remember; text: 'Remember securely on this computer'; checked: (root.state.config || {}).remember_login !== false; palette.windowText: root.foreground; palette.text: root.foreground; palette.highlight: root.accent }
                        Action {
                            id: login; objectName: 'loginSubmit'
                            Layout.fillWidth: true; implicitHeight: 44
                            text: root.state.busy ? 'Connecting…' : 'Open my collection'
                            emphasized: true
                            enabled: !root.state.busy && username.text.trim().length > 0 && password.text.length > 0
                            onClicked: { root.service.send('login', {username: username.text.trim(), password: password.text, remember: remember.checked, profile_url: profile.text.trim()}) }
                        }
                        Action { text: help.visible ? 'Hide connection help' : 'Trouble connecting?'; onClicked: help.visible = !help.visible }
                        Copy { id: help; visible: false; Layout.fillWidth: true; text: 'Use the separate Subsonic credentials from Fan Settings. If rejected, generate a fresh pair and try again. Check your connection if loading stalls.'; color: root.muted; font.pixelSize: 12; wrapMode: Text.Wrap }
                        Copy { Layout.fillWidth: true; text: 'Use generated Subsonic credentials, not your regular Bandcamp password.'; font.pixelSize: 12; color: root.muted; wrapMode: Text.Wrap }
                    }
                }
            }
        }
        ColumnLayout {
            visible: !!root.state.connected
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.margins: 24
            spacing: 20
            RowLayout {
                Layout.fillWidth: true
                Action { text: 'Collection'; emphasized: root.page === 'collection'; onClicked: root.page = 'collection' }
                Action { text: 'Playlists'; emphasized: root.page === 'playlists'; onClicked: { root.page = 'playlists'; root.service.send('playlists') } }
                Action { text: 'Queue' + ((root.state.queue || []).length ? ' · ' + root.state.queue.length : ''); emphasized: root.page === 'queue'; onClicked: root.page = 'queue' }
                Item { Layout.fillWidth: true }
                Copy { text: root.state.playbackStatus || ''; color: root.muted; font.pixelSize: 12 }
                Action { text: 'Retry'; visible: !!root.state.error; onClicked: root.service.send('retry') }
                Action { text: 'Refresh'; enabled: !root.state.busy; onClicked: root.service.send('refresh') }
                Action { text: 'Sign out'; enabled: !root.state.busy; onClicked: { root.page = 'collection'; root.service.send('logout') } }
            }
            RowLayout {
                visible: root.page === 'collection'
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 4
                    Copy { text: 'The collection'; font.pixelSize: 27; font.bold: true }
                    Copy { text: root.records.length + ' of ' + root.libraryAlbums.length + ' records'; color: root.muted; font.pixelSize: 12 }
                }
                Item { Layout.fillWidth: true }
                Field { id: search; Layout.preferredWidth: Math.min(300, root.width * 0.35); placeholderText: 'Filter artist or album'; Accessible.name: 'Filter collection'; onTextChanged: root.filter = text }
            }
            RowLayout {
                visible: root.page === 'collection'; Layout.fillWidth: true; spacing: 8
                FilterDropdown { title: 'Artist'; options: root.artistOptions; selectedValues: root.selectedArtists; onSelectionChanged: values => root.selectedArtists = values; foreground: root.foreground; surface: root.background; accent: root.accent }
                FilterDropdown { title: 'Genre'; options: root.genreOptions; selectedValues: root.selectedGenres; onSelectionChanged: values => root.selectedGenres = values; foreground: root.foreground; surface: root.background; accent: root.accent }
                FilterDropdown { title: 'Tags'; visible: (root.state.config || {}).metadata_enrichment === true || root.selectedTags.length > 0; options: root.tagOptions; selectedValues: root.selectedTags; onSelectionChanged: values => root.selectedTags = values; foreground: root.foreground; surface: root.background; accent: root.accent; ToolTip.text: 'Optional MusicBrainz tags'; ToolTip.visible: hovered }
                Item { Layout.fillWidth: true }
                FilterDropdown { title: 'Sort'; text: 'Sort: ' + (root.sortOptions.find(o => o.value === (root.state.collectionOrder || 'artist')) || root.sortOptions[0]).label + '  ▾'; options: root.sortOptions; selectedValues: [root.state.collectionOrder || 'artist']; multiple: false; searchable: false; showCounts: false; onSelectionChanged: values => root.service.send('collection_order', {order: values[0]}); foreground: root.foreground; surface: root.background; accent: root.accent }
                Action { text: 'Clear all'; visible: root.activeFilters.length > 0 || !!root.filter; onClicked: { root.selectedArtists = []; root.selectedGenres = []; root.selectedTags = []; search.clear() } }
            }
            Flow {
                visible: root.page === 'collection' && root.activeFilters.length > 0
                Layout.fillWidth: true; Layout.preferredHeight: childrenRect.height; spacing: 6
                Repeater {
                    model: root.activeFilters
                    Action { required property var modelData; text: modelData.kind + ': ' + modelData.value + '  ×'; width: Math.min(implicitWidth, root.width - 48); implicitHeight: 30; Accessible.name: 'Remove ' + modelData.kind + ' ' + modelData.value; onClicked: root.removeFilter(modelData.kind, modelData.value) }
                }
            }
            Copy { visible: root.page === 'collection'; text: root.state.metadataNotice || root.state.collectionNotice || 'Wheel to scroll · Middle-click, then move the pointer to autoscroll'; color: root.muted; font.pixelSize: 11 }
            StackLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                currentIndex: root.page === 'collection' ? 0 : root.page === 'album' ? 1 : root.page === 'queue' ? 2 : root.page === 'playlists' ? 3 : 4
                Item {
                    GridView {
                        id: grid
                        objectName: "collectionGrid"
                        anchors.fill: parent
                        clip: true
                        cellWidth: width / Math.max(2, Math.floor(width / 178))
                        cellHeight: cellWidth + 65
                        property string recordOrder: ''
                        property real savedOffset: 0
                        property bool restoring: false
                        function restorePosition() {
                            forceLayout()
                            contentY = originY + Math.max(0, Math.min(savedOffset, contentHeight - height))
                            restoring = restoreTimer.running
                        }
                        function updateRecords() {
                            if (model && model.length === root.records.length && root.records.every((item, i) => model[i] === item)) return
                            const order = JSON.stringify(root.records.map(a => String(a.id)))
                            restoring = true
                            if (order !== recordOrder) savedOffset = 0
                            recordOrder = order
                            model = root.records
                            restorePosition()
                        }
                        Timer { id: restoreTimer; interval: 16; onTriggered: grid.restorePosition() }
                        onHeightChanged: if (root.page === 'collection') { restoring = true; restoreTimer.restart() }
                        onContentYChanged: if (!restoring && root.page === 'collection' && (dragging || flicking || collectionBar.pressed || collectionScroll.scrolling)) savedOffset = Math.max(0, contentY - originY)
                        Component.onCompleted: updateRecords()
                        Connections {
                            target: root
                            function onRecordsChanged() { grid.updateRecords() }
                            function onPageChanged() {
                                if (root.page === 'collection') {
                                    grid.restoring = true
                                    restoreTimer.restart()
                                }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { id: collectionBar }
                        ScrollAssist { wheelAcceleration: (root.state.config || {}).wheel_acceleration !== false; wheelStep: (root.state.config || {}).wheel_scroll_pixels || 360; id: collectionScroll; objectName: "collectionScroll"; onScrolled: grid.savedOffset = Math.max(0, grid.contentY - grid.originY); flickable: grid; enabled: root.page === 'collection'; accent: root.accent }
                        delegate: Item {
                            required property var modelData
                            width: grid.cellWidth; height: grid.cellHeight
                            Column {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: 18
                                spacing: 8
                                Button {
                                    width: parent.width; height: width
                                    Accessible.name: 'Open ' + (modelData.name || modelData.title) + ' by ' + modelData.artist
                                    background: Artwork { source: modelData.art || ''; foreground: root.foreground }
                                    onClicked: { root.service.state = Object.assign({}, root.state, {album: null}); root.page = 'album'; root.service.send('album', {id: modelData.id}) }
                                    Rectangle { anchors.fill: parent; color: 'transparent'; border.width: parent.hovered || parent.activeFocus ? 2 : 0; border.color: root.accent }
                                }
                                Copy { width: parent.width; text: modelData.name || modelData.title || 'Untitled'; font.bold: true; elide: Text.ElideRight }
                                Copy { width: parent.width; text: modelData.artist || ''; color: root.muted; font.pixelSize: 12; elide: Text.ElideRight }
                            }
                        }
                    }
                    Copy { anchors.centerIn: parent; visible: root.records.length === 0; text: root.state.busy ? 'Loading your records…' : root.filter || root.activeFilters.length ? 'No records match. Remove a filter or clear all.' : 'No albums found. Refresh to try again.'; color: root.muted }
                }
                ColumnLayout {
                    spacing: 18
                    RowLayout {
                        Layout.fillWidth: true; spacing: 20
                        Artwork { Layout.preferredWidth: 116; Layout.preferredHeight: 116; source: root.album.art || ''; foreground: root.foreground }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 8
                            Copy { Layout.fillWidth: true; text: root.album.name || root.album.title || 'Loading album…'; font.pixelSize: 24; font.bold: true; elide: Text.ElideRight }
                            Copy { Layout.fillWidth: true; text: root.album.artist || ''; color: root.muted; elide: Text.ElideRight }
                            RowLayout {
                                Action { text: 'Play record'; emphasized: true; enabled: !!root.album.id && !root.state.busy; onClicked: root.service.send('play_album', {id: root.album.id, index: 0}) }
                                Action { text: '+ Queue'; enabled: !!root.album.id && !root.state.busy; onClicked: root.service.send('enqueue_album', {id: root.album.id}) }
                            }
                        }
                    }
                    ListView {
                        id: albumTracks
                        ScrollAssist { wheelAcceleration: (root.state.config || {}).wheel_acceleration !== false; wheelStep: (root.state.config || {}).wheel_scroll_pixels || 360; flickable: albumTracks; enabled: root.page === 'album'; accent: root.accent }
                        Layout.fillWidth: true; Layout.fillHeight: true
                        clip: true; spacing: 2
                        model: root.album.song || []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            foreground: root.foreground; muted: root.muted; accent: root.accent
                            track: modelData; number: index + 1
                            actionText: '+ Queue'; onActionClicked: root.service.send('enqueue_track', {id: root.album.id, index: index})
                            selected: root.state.current && root.state.current.id === modelData.id
                            onClicked: root.service.send('play_album', {id: root.album.id, index: index})
                        }
                    }
                }
                Item {
                    ListView {
                        id: queueTracks
                        ScrollAssist { wheelAcceleration: (root.state.config || {}).wheel_acceleration !== false; wheelStep: (root.state.config || {}).wheel_scroll_pixels || 360; flickable: queueTracks; enabled: root.page === 'queue'; accent: root.accent }
                        anchors.fill: parent; clip: true; spacing: 2
                        model: root.state.queue || []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: TrackRow {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            foreground: root.foreground; muted: root.muted; accent: root.accent
                            track: modelData; number: index + 1; selected: root.state.index === index
                            actionText: 'Remove'; onActionClicked: root.service.send('remove_queue', {index: index})
                            onClicked: root.service.send('play_index', {index: index})
                        }
                    }
                    Copy { anchors.centerIn: parent; visible: !(root.state.queue || []).length; text: 'Your queue is empty. Pick a record to begin.'; color: root.muted }
                }
                PlaylistView { service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted; active: root.page === 'playlists' }
                SettingsView { service: root.service; foreground: root.foreground; surface: root.background; accent: root.accent }
            }
        }
        Transport { Layout.fillWidth: true; visible: !!root.state.connected; service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted }
    }
}
