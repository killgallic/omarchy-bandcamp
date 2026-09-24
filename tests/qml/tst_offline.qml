import QtQuick
import QtTest
import '../..'
TestCase {
 name:'Offline'; when:windowShown; visible:true;width:700;height:500
 QtObject { id:service;property var state:({connected:false,offline:true,starting:false,cachedCollection:{albums:[{id:'1',artist:'A',name:'First'},{id:'2',artist:'B',name:'Second'}]},config:{}});property string processError:'';property var sent:[];function send(cmd,args){sent=sent.concat([cmd])} }
 PlayerView { id:player;anchors.fill:parent;service:service }
 function test_offline_browse_is_read_only() {
  verify(findChild(player,'loginUsername')===null)
  verify(player.state.offline)
  compare(service.sent.length,0)
  // Offline records are rendered by the dedicated view, without play controls.
  compare(findChild(player,'albumCover0'),null)
 }
}
