import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'Player'; when: windowShown; visible: true
    width: 1050; height: 900
    QtObject {
        id: service
        property var state: ({connected: true, albums: [{id:'1',name:'One',artist:'A',genre:'House'},{id:'2',name:'Two',artist:'B',genre:'Jazz'}], queue: []})
        property string processError: ''
        property bool quitAsked: false
        function send(cmd,args) {}
        function requestQuit() { quitAsked = true }
    }
    PlayerView { id: player; anchors.fill: parent; service: service }
    function test_top_navigation_and_quit_confirmation() {
        player.page = 'home'
        const home = findChild(player, 'homeNav')
        const collection = findChild(player, 'collectionNav')
        const playlists = findChild(player, 'playlistsNav')
        const queue = findChild(player, 'queueNav')
        verify(home && collection && playlists && queue)
        collection.clicked(); compare(player.page, 'collection')
        playlists.clicked(); compare(player.page, 'playlists')
        queue.clicked(); compare(player.page, 'queue')
        home.clicked(); compare(player.page, 'home')
        findChild(player, 'quitButton').clicked()
        verify(service.quitAsked)
        player.confirmQuit()
        verify(findChild(player, 'quitConfirmation').opened)
        findChild(player, 'quitConfirmation').reject()
        service.quitAsked = false
    }
    function test_collection_scroll_survives_metadata_and_album_navigation() {
        const original = service.state
        const records = Array.from({length: 100}, (_, i) => ({id: String(i), name: 'Record ' + i, artist: 'Artist'}))
        service.state = Object.assign({}, original, {albums: records})
        player.page = 'collection'
        wait(30)
        const grid = findChild(player, 'collectionGrid')
        verify(grid)
        const scroll = findChild(player, 'collectionScroll')
        scroll.scrollBy(900)
        wait(20)
        service.state = Object.assign({}, service.state, {albums: records.map(a => Object.assign({}, a, {art: '', tags: ['ambient']}))})
        wait(30)
        compare(grid.contentY, 900)
        const nearBottom = grid.contentHeight - grid.height - 5
        scroll.scrollBy(nearBottom - grid.contentY)
        player.page = 'album'
        service.state = Object.assign({}, service.state, {albums: records.map(a => Object.assign({}, a, {genre: 'Ambient'}))})
        wait(30)
        player.page = 'collection'
        wait(30)
        tryVerify(() => Math.abs(grid.contentY - nearBottom) < 0.01, 1000)
        service.state = Object.assign({}, service.state, {albums: records.slice().reverse()})
        wait(30)
        compare(grid.contentY, grid.originY)
        scroll.scrollBy(600 - grid.contentY)
        player.filter = 'Record 1'
        wait(30)
        compare(grid.contentY, grid.originY)
        player.filter = ''
        service.state = original
        wait(30)
    }
    function test_wheel_over_album_cards_keeps_speed_after_scrolling() {
        const original = service.state
        service.state = Object.assign({}, original, {albums: Array.from({length: 100}, (_, i) => ({id: String(i), name: 'Record ' + i, artist: 'Artist'}))})
        player.page = 'collection'
        wait(50)
        const grid = findChild(player, 'collectionGrid')
        const scroll = findChild(player, 'collectionScroll')
        grid.contentY = 0
        mouseWheel(grid, 70, 70, 0, -120)
        tryCompare(grid, 'contentY', 360, 1000)
        scroll.resetWheel()
        scroll.scrollBy(900 - grid.contentY)
        mouseWheel(grid, 70, 70, 0, -120)
        tryCompare(grid, 'contentY', 1260, 1000)
        service.state = original
        wait(30)
    }
    function test_collection_wheel_tracks_saved_speed() {
        const original = service.state
        service.state = Object.assign({}, original, {config:{wheel_scroll_pixels:1200,wheel_acceleration:true}})
        player.page = 'collection'
        compare(findChild(player, 'collectionScroll').wheelStep, 1200)
        service.state = Object.assign({}, service.state, {config:{wheel_scroll_pixels:720,wheel_acceleration:false,reduced_motion:true}})
        compare(findChild(player, 'collectionScroll').wheelStep, 720)
        compare(findChild(player, 'collectionScroll').reducedMotion, true)
        service.state = original
    }
    function test_genres_sort_by_count_then_name() {
        const original = service.state
        service.state = Object.assign({}, original, {albums: [
            {id:'1',genre:'Zebra'}, {id:'2',genre:'Zebra'}, {id:'3',genre:'Zebra'},
            {id:'4',genre:'Ambient'}, {id:'5',genre:'Ambient'}, {id:'6',genre:'Blues'}]})
        compare(player.genreOptions.map(o => o.value).join(','), 'Zebra,Ambient,Blues')
        service.state = original
    }
    function test_musicbrainz_coverage_is_only_in_tag_settings() {
        const original = service.state
        service.state = Object.assign({}, original, {metadataNotice: 'MusicBrainz tags available for 7 records.', config: {metadata_enrichment: true}})
        player.page = 'collection'
        wait(20)
        const hint = findChild(player, 'collectionHint')
        verify(hint)
        verify(hint.text.indexOf('MusicBrainz') < 0)
        verify(!hint.visible)
        service.state = Object.assign({}, service.state, {collectionNotice: 'Newest first'})
        wait(20)
        compare(hint.text, 'Newest first')
        verify(hint.visible)
        player.page = 'settings'
        wait(20)
        const status = findChild(player, 'metadataStatus')
        verify(status)
        compare(status.text, 'MusicBrainz tags available for 7 records.')
        service.state = original
    }
    function test_filters() {
        compare(player.records.length, 2)
        player.selectedArtists = ['A']; compare(player.records.length, 1)
        player.selectedGenres = ['Jazz']; compare(player.records.length, 0)
        player.selectedArtists = []; compare(player.records[0].id, '2')
        player.selectedGenres = []; player.filter = 'one'; compare(player.records[0].id, '1')
        player.filter = ''
        player.selectedGenres = ['House', 'Jazz']; compare(player.records.length, 2)
        player.selectedArtists = ['A']; compare(player.records.length, 1)
        compare(player.genreOptions.find(o => o.value === 'Jazz').count, 0)
        player.removeFilter('Artist', 'A'); compare(player.records.length, 2)
        player.selectedGenres = []
    }
    function test_login_retains_password_on_rejection() {
        service.state = Object.assign({}, service.state, {connected: false})
        wait(20)
        const user = findChild(player, 'loginUsername')
        const password = findChild(player, 'loginPassword')
        const submit = findChild(player, 'loginSubmit')
        verify(user && password && submit)
        user.text = 'fixture'; password.text = 'fixture-password'
        submit.clicked()
        service.state = Object.assign({}, service.state, {error: 'Rejected', busy: false})
        compare(password.text, 'fixture-password')
        service.state = Object.assign({}, service.state, {connected: true, error: ''})
        wait(20)
        compare(findChild(player, 'loginPassword'), null)
    }
    function test_pages() {
        for (const page of ['home','collection','album','queue','playlists','settings']) { player.page = page; wait(30); player.grabToImage(function(result) { result.saveToFile('/tmp/bandcamp-' + page + '-fixture.png') }); wait(30) }
        player.grabToImage(function(result) { result.saveToFile('/tmp/bandcamp-settings-fixture.png') })
        wait(80)
    }
}
