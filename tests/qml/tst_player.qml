import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'Player'; when: windowShown; visible: true
    width: 1050; height: 900
    QtObject { id: service; property var state: ({connected: true, albums: [{id:'1',name:'One',artist:'A',genre:'House'},{id:'2',name:'Two',artist:'B',genre:'Jazz'}], queue: []}); property string processError: ''; function send(cmd,args) {} }
    PlayerView { id: player; anchors.fill: parent; service: service }
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
        for (const page of ['collection','album','queue','playlists','settings']) { player.page = page; wait(30); player.grabToImage(function(result) { result.saveToFile('/tmp/bandcamp-' + page + '-fixture.png') }); wait(30) }
        player.grabToImage(function(result) { result.saveToFile('/tmp/bandcamp-settings-fixture.png') })
        wait(80)
    }
}
