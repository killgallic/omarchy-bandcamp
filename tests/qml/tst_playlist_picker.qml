import QtQuick
import QtTest
import '../..'
TestCase {
 name: 'PlaylistPicker'; when: windowShown; visible:true
 width:500;height:550
 QtObject { id: service; property var state: ({playlists:[],playlistBusy:false,playlistError:''});property var commands:[];function send(cmd,args){commands=commands.concat([{cmd:cmd,args:args}])} }
 PlaylistPicker { id: picker; service:service; source: ({kind:'track',id:'song',albumId:'album'}) }
 function test_failure_keeps_selection_and_success_closes() {
  picker.open();tryCompare(picker,'opened',true)
  const name=findChild(picker,'newPlaylistName');verify(name);name.text='Evening'
  const create=findChild(picker,'createAndAdd');verify(create);create.clicked()
  compare(service.commands[service.commands.length - 1].cmd,'create_and_add')
  compare(service.commands[service.commands.length - 1].args.source.id,'song')
  service.state=Object.assign({},service.state,{playlistBusy:true})
  service.state=Object.assign({},service.state,{playlistBusy:false,playlistError:'Bandcamp rejected the write'})
  compare(picker.opened,true)
  compare(picker.source.id,'song')
  create.clicked()
  service.state=Object.assign({},service.state,{playlistBusy:true,playlistError:''})
  service.state=Object.assign({},service.state,{playlistBusy:false})
  tryCompare(picker,'opened',false)
 }
 function test_wheel_speed_controls_playlist_choices() {
  const original = service.state
  service.state = Object.assign({}, original, {config:{wheel_scroll_pixels:1200,wheel_acceleration:false},playlists:Array.from({length:80},(_,i)=>({id:String(i),name:'Playlist '+i}))})
  picker.open(); tryCompare(picker,'opened',true)
  const list = findChild(picker,'playlistChoices'); verify(list)
  list.contentY = 0
  mouseWheel(list,80,80,0,-120)
  tryCompare(list,'contentY',1200,1000)
  picker.close(); service.state = original
 }
}
