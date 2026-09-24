import QtQuick
import QtTest
import '../..'
TestCase {
 name: 'AlbumContext'; when: windowShown; visible: true
 width: 900; height: 750
 QtObject { id: service; property var state: ({connected:true,albums:[{id:'record-1',name:'First',artist:'Artist'}],queue:[],config:{}}); property string processError:''; property var sent:[]; function send(cmd,args) { sent=sent.concat([{cmd:cmd,args:args}]) } }
 PlayerView { id: player; anchors.fill: parent; service: service; page:'collection' }
 function test_right_click_cover_opens_album_menu_without_playing() {
  const cover=findChild(player,'albumCover0'); verify(cover)
  const menu=findChild(player,'itemContextMenu'); verify(menu)
  mouseClick(cover,cover.width/2,cover.height/2,Qt.RightButton)
  tryCompare(menu,'opened',true)
  compare(menu.source.id,'record-1')
  compare(service.sent.filter(x=>x.cmd==='play_album').length,0)
  menu.close()
 }
}
