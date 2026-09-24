import QtQuick
import QtTest
import '../../TextFormat.js' as Format
TestCase {
    name: 'TextFormat'
    function test_templates() {
        compare(Format.render('{Artist} — {Album} — {Song Name}', {artist:'A',title:'T'}, true), 'A — T')
        compare(Format.render('{Artist} / {Song Name}', {artist:'<b>A</b>',title:'T'}, false), 'Ⅱ  <b>A</b> / T')
        compare(Format.render('{Song Name}', {}, false), 'Bandcamp')
        compare(Format.render('{Song Name}', {title:'-1'}, true), '-1')
        compare(Format.render('{Song Name}', {title:'Song /'}, true), 'Song /')
        compare(Format.render('{State}: {Song Name}', {title:'T'}, false), 'Paused: T')
    }
}
