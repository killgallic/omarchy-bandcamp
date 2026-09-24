import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'PlaylistManagement'; when: windowShown; visible: true
    width: 950; height: 720
    QtObject {
        id: service
        property var state: ({playlist: {id:'p1',name:'Quiet hours',entry:[]},playlists:[],queue:[]})
        property var commands: []
        function send(cmd,args) { commands = commands.concat([{cmd:cmd,args:args}]) }
    }
    PlaylistView { id: playlists; anchors.fill: parent; service: service }
    function init() { service.commands = []; service.state = {playlist:{id:'p1',name:'Quiet hours',entry:[]},playlists:[],queue:[]} }
    function test_create_empty_is_separate_from_save_queue() {
        const name = findChild(playlists, 'newPlaylistName')
        verify(name)
        name.text = 'New empty playlist'
        const create = findChild(playlists, 'createPlaylist')
        const save = findChild(playlists, 'saveQueuePlaylist')
        verify(create.enabled)
        verify(!save.enabled)
        mouseClick(create)
        compare(service.commands[0].cmd, 'create_playlist')
        compare(service.commands[0].args.name, 'New empty playlist')
        verify(!findChild(playlists, 'playPlaylist').enabled)
    }
    function test_delete_requires_named_dialog_and_cancel_is_focused() {
        mouseClick(findChild(playlists, 'playlistOverflow'))
        const menuItem = findChild(playlists, 'deletePlaylistMenuItem')
        menuItem.triggered()
        const dialog = findChild(playlists, 'deletePlaylistDialog')
        tryCompare(dialog, 'opened', true)
        compare(service.commands.length, 0)
        compare(dialog.title, 'Delete “Quiet hours”?')
        const cancel = findChild(playlists, 'cancelDeletePlaylist')
        tryVerify(() => cancel.activeFocus)
        keyClick(Qt.Key_Return)
        tryCompare(dialog, 'opened', false)
        compare(service.commands.length, 0)
        mouseClick(findChild(playlists, 'playlistOverflow'))
        menuItem.triggered()
        tryCompare(dialog, 'opened', true)
        mouseClick(findChild(playlists, 'confirmDeletePlaylist'))
        compare(service.commands.length, 1)
        compare(service.commands[0].cmd, 'delete_playlist')
        compare(service.commands[0].args.id, 'p1')
    }
}
