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
    property string page: 'home'
    function goHome() { page = 'home'; if (state.connected) service.send('playlists') }
    function openAlbum(record) { service.state = Object.assign({}, state, {album:null}); page = 'album'; service.send('album', {id:record.id}) }
    property string filter: ''
    property var selectedArtists: []
    property var selectedGenres: []
    property var selectedTags: []
    readonly property var state: service ? service.state : ({})
    readonly property var notificationCenter: service && service.notifications ? service.notifications : null
    readonly property var libraryAlbums: state.albums || []
    readonly property var album: state.album || ({})
    readonly property var records: libraryAlbums.filter(a => matches(a, ''))
    readonly property var artistOptions: facetOptions('Artist')
    readonly property var genreOptions: facetOptions('Genre')
    readonly property var tagOptions: facetOptions('Tags')
    readonly property var activeFilters: selectedArtists.map(v => ({kind: 'Artist', value: v})).concat(selectedGenres.map(v => ({kind: 'Genre', value: v})), selectedTags.map(v => ({kind: 'Tags', value: v})))
    readonly property var sortOptions: [{value:'artist',label:'Artist A–Z'}, {value:'album',label:'Album A–Z'}, {value:'newest',label:'Recently added'}, {value:'recent_purchased',label:'Recently purchased (public)'}, {value:'most_played',label:'Most played here'}, {value:'recent_played',label:'Recently played here'}]
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
            Button { Layout.preferredWidth: 32; Layout.preferredHeight: 32; Accessible.name: 'Home'; background: Artwork { source: (root.state.profile || {}).art || ''; foreground: root.foreground }
                onClicked: root.goHome() }
            Action { text: 'bandcamp'; Accessible.name: 'Bandcamp home'; font.pixelSize: 24; font.bold: true; font.italic: true; onClicked: root.goHome() }
            Copy { text: ' /  YOUR RECORDS'; color: root.muted; font.pixelSize: 10; font.letterSpacing: 2; visible: root.width > 650 }
            Item { Layout.fillWidth: true }
            BusyIndicator { Layout.preferredWidth: 22; Layout.preferredHeight: 22; running: !!(root.state.loading || root.state.busy || root.state.metadataBusy); visible: running; ToolTip.visible: hovered; ToolTip.text: root.state.playbackStatus || 'Loading…' }
            Action { objectName: 'notificationHistoryButton'; text: 'Activity' + (root.notificationCenter && root.notificationCenter.unresolvedCount ? ' · ' + root.notificationCenter.unresolvedCount : ''); visible: !!root.notificationCenter && root.notificationCenter.history.length > 0; Accessible.name: 'Notification history'; onClicked: activity.open() }
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
            Copy { id: message; anchors.fill: parent; anchors.margins: 12; text: !root.state.connected ? ((root.service ? root.service.processError : '') || root.state.error || '') : ''; wrapMode: Text.Wrap; font.pixelSize: 13 }
        }
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: root.state.starting === true && !root.state.setupRequired
            ColumnLayout {
                anchors.centerIn: parent; width: Math.min(parent.width - 48, 480); spacing: 14
                BusyIndicator { Layout.alignment: Qt.AlignHCenter; running: parent.parent.visible }
                Copy { text: 'Reconnecting to your collection…'; color: root.muted }
                Copy { Layout.fillWidth: true; visible: !!root.state.cachedCollection; text: root.state.cachedCollection ? (root.state.cachedCollection.albums || []).length + ' cached records · ' + (root.state.cachedCollection.stale ? 'refreshing an older snapshot' : 'checking for updates') : ''; color: root.muted; wrapMode: Text.Wrap }
                Copy { Layout.fillWidth: true; visible: !!root.state.cachedCollection; text: root.state.cachedCollection ? (root.state.cachedCollection.albums || []).slice(0, 4).map(a => (a.artist || '') + ' — ' + (a.name || '')).join('\n') : ''; color: root.muted; wrapMode: Text.Wrap }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: root.state.setupRequired === true
            spacing: 12
            Copy { text: 'One quick setup step'; font.pixelSize: 26; font.bold: true }
            Copy { Layout.fillWidth: true; wrapMode: Text.Wrap; text: 'Install the locked Python dependencies with bin/setup in the Omarchy Bandcamp project directory. Then reopen the player.' }
            Action { text: 'Retry'; onClicked: root.service.start() }
        }
        // Login fields live only while disconnected; no password survives login.
        Loader {
            Layout.fillWidth: true; Layout.fillHeight: true
            active: !root.state.connected && !root.state.starting && !root.state.setupRequired && !root.state.offline
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
        OfflineView {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 24
            visible: root.state.offline === true && !root.state.starting
            service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted
        }
        ColumnLayout {
            visible: !!root.state.connected
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.margins: 24
            spacing: 20
            RowLayout {
                Layout.fillWidth: true
                Action { text: '← Back to records'; visible: root.page === 'album'; onClicked: root.page = 'collection' }
                Action { text: 'Playlists'; emphasized: root.page === 'playlists'; onClicked: { root.page = 'playlists'; root.service.send('playlists') } }
                Action { text: 'Queue' + ((root.state.queue || []).length ? ' · ' + root.state.queue.length : ''); emphasized: root.page === 'queue'; onClicked: root.page = 'queue' }
                Item { Layout.fillWidth: true }
                Copy { text: root.state.playbackStatus || ''; color: root.muted; font.pixelSize: 12 }
                Action { text: 'Retry'; visible: !!root.state.error; onClicked: root.service.send('retry') }
                Action { text: 'Refresh'; enabled: !root.state.busy; onClicked: root.service.send('refresh') }
                Action { text: 'Sign out'; enabled: !root.state.busy; onClicked: { root.page = 'home'; root.service.send('logout') } }
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
                currentIndex: root.page === 'collection' ? 0 : root.page === 'album' ? 1 : root.page === 'queue' ? 2 : root.page === 'playlists' ? 3 : root.page === 'settings' ? 4 : 5
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
                            required property int index
                            width: grid.cellWidth; height: grid.cellHeight
                            Column {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.rightMargin: 18
                                spacing: 8
                                Button {
                                    width: parent.width; height: width
                                    objectName: 'albumCover' + index
                                    Accessible.name: 'Open ' + (modelData.name || modelData.title) + ' by ' + modelData.artist
                                    background: Artwork { source: modelData.art || ''; foreground: root.foreground }
                                    onClicked: root.openAlbum(modelData)
                                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: itemMenu.showFor(parent, modelData, {kind:'album',id:modelData.id}) }
                                    Keys.onPressed: event => { if (event.key === Qt.Key_Menu || (event.key === Qt.Key_F10 && event.modifiers & Qt.ShiftModifier)) { itemMenu.showFor(parent, modelData, {kind:'album',id:modelData.id}); event.accepted = true } }
                                    Action { anchors.right: parent.right; anchors.bottom: parent.bottom; text: '⋯'; Accessible.name: 'Album actions'; onClicked: itemMenu.showFor(parent, modelData, {kind:'album',id:modelData.id}) }
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
                                Action { text: root.album.artistUrl ? 'Artist on Bandcamp ↗' : 'Search artist ↗'; onClicked: Qt.openUrlExternally(root.album.artistUrl || 'https://bandcamp.com/search?q=' + encodeURIComponent(root.album.artist || '')) }
                                Action { text: root.album.releaseUrl ? 'View / support release ↗' : 'Search release ↗'; onClicked: Qt.openUrlExternally(root.album.releaseUrl || 'https://bandcamp.com/search?q=' + encodeURIComponent((root.album.artist || '') + ' ' + (root.album.name || ''))) }
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
                            onContextRequested: itemMenu.showFor(this, Object.assign({}, modelData, {releaseUrl:root.album.releaseUrl, artistUrl:root.album.artistUrl}), {kind:'track',id:modelData.id,albumId:root.album.id}, index)
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
                            onContextRequested: itemMenu.showFor(this, modelData, {kind:'track',id:modelData.id,albumId:modelData.albumId}, 0, index)
                            actionText: 'Remove'; onActionClicked: root.service.send('remove_queue', {index: index})
                            onClicked: root.service.send('play_index', {index: index})
                        }
                    }
                    Copy { anchors.centerIn: parent; visible: !(root.state.queue || []).length; text: 'Your queue is empty. Pick a record to begin.'; color: root.muted }
                }
                PlaylistView { service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted; active: root.page === 'playlists'; onItemContextRequested: (target, item, source, index) => itemMenu.showFor(target, item, source, index) }
                SettingsView { service: root.service; foreground: root.foreground; surface: root.background; accent: root.accent }
                HomeView {
                    service: root.service; foreground: root.foreground; surface: root.background; accent: root.accent; muted: root.muted
                    onBrowseRequested: query => { search.text = query; root.page = 'collection' }
                    onAlbumRequested: record => root.openAlbum(record)
                    onPlaylistsRequested: { root.page = 'playlists'; root.service.send('playlists') }
                }
            }
        }
        Transport { Layout.fillWidth: true; visible: !!root.state.connected; service: root.service; foreground: root.foreground; background: root.background; accent: root.accent; muted: root.muted }
    }
    Connections { target: root.service; ignoreUnknownSignals: true; function onHomeRequested() { root.goHome() } }
    ItemContextMenu {
        id: itemMenu; objectName: 'itemContextMenu'; service: root.service; foreground: root.foreground; surface: root.background; accent: root.accent
        onPlaylistRequested: source => { playlistPicker.source = source; playlistPicker.open() }
        onDetailsRequested: (record, source) => { information.record = record; information.source = source; information.open() }
    }
    PlaylistPicker { id: playlistPicker; objectName: 'playlistPicker'; service: root.service; foreground: root.foreground; surface: root.background; accent: root.accent }
    Dialog {
        id: information; property var record: ({}); property var source: ({})
        anchors.centerIn: parent; width: Math.min(420, root.width - 32); modal: true; popupType: Popup.Item
        title: record.title || record.name || 'Information'; standardButtons: Dialog.Close
        palette.window: root.background; palette.windowText: root.foreground; palette.text: root.foreground; palette.buttonText: root.foreground
        ColumnLayout {
            width: parent.width
            Copy { Layout.fillWidth: true; text: information.record.artist || ''; wrapMode: Text.Wrap }
            Copy { Layout.fillWidth: true; text: information.record.album || ''; wrapMode: Text.Wrap }
            Copy { text: information.record.duration ? Math.round(information.record.duration) + ' seconds' : '' }
            Action { text: 'View album'; visible: information.source.kind === 'track'; onClicked: { root.openAlbum({id:information.source.albumId}); information.close() } }
            Action { text: 'Search release on Bandcamp ↗'; onClicked: Qt.openUrlExternally('https://bandcamp.com/search?q=' + encodeURIComponent((information.record.artist || '') + ' ' + (information.record.album || information.record.name || ''))) }
        }
    }
    NotificationToast {
        anchors.right: parent.right; anchors.top: parent.top
        anchors.rightMargin: 24; anchors.topMargin: 86
        width: Math.min(460, parent.width - 48)
        z: 20
        center: root.notificationCenter
        foreground: root.foreground; background: root.background; accent: root.accent
    }
    Popup {
        id: activity
        objectName: 'notificationHistoryPopup'
        x: Math.max(12, root.width - width - 24); y: 80
        width: Math.min(480, root.width - 24)
        height: Math.min(root.height - 100, 440)
        padding: 12
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        background: Rectangle { color: root.background; border.color: root.muted; radius: 6 }
        ScrollView {
            anchors.fill: parent
            clip: true
            contentWidth: availableWidth
            NotificationToast {
                width: parent.width
                center: root.notificationCenter; showHistory: true
                foreground: root.foreground; background: root.background; accent: root.accent
            }
        }
    }

}
