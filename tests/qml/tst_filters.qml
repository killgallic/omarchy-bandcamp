import QtQuick
import QtTest
import '../..'
TestCase {
    name: 'FilterDropdown'; when: windowShown; visible: true
    width: 600; height: 600
    FilterDropdown {
        id: dropdown; x: 30; y: 20; title: 'Genre'
        options: Array.from({length: 80}, (_, i) => ({value: 'genre-' + i, label: 'Genre ' + i, count: i + 1}))
        onSelectionChanged: values => selectedValues = values
    }
    function cleanup() {
        dropdown.close(); dropdown.selectedValues = []; dropdown.sortMode = ''
        dropdown.options = Array.from({length: 80}, (_, i) => ({value: 'genre-' + i, label: 'Genre ' + i, count: i + 1}))
    }
    function test_popup_scroll_search_and_multiselect() {
        mouseClick(dropdown)
        wait(30)
        const list = findChild(dropdown, 'filterOptions')
        const search = findChild(dropdown, 'filterSearch')
        verify(list && search)
        verify(list.height < list.contentHeight)
        list.parent.grabToImage(result => result.saveToFile('/tmp/bandcamp-filter-dropdown.png'))
        wait(20)
        mouseWheel(list, 80, 80, 0, -120)
        verify(list.contentY > 0)
        search.text = 'Genre 79'
        wait(20)
        compare(list.count, 1)
        mouseClick(list, 80, 16)
        compare(dropdown.selectedValues[0], 'genre-79')
        verify(dropdown.isOpen)
        search.text = 'Genre 78'
        wait(20)
        mouseClick(list, 80, 16)
        compare(dropdown.selectedValues.length, 2)
        keyClick(Qt.Key_Escape)
        verify(!dropdown.isOpen)
    }
    function test_keyboard_selects_visible_result() {
        mouseClick(dropdown)
        wait(30)
        const search = findChild(dropdown, 'filterSearch')
        search.text = 'Genre 79'
        search.forceActiveFocus()
        keyClick(Qt.Key_Down)
        keyClick(Qt.Key_Return)
        compare(dropdown.selectedValues[0], 'genre-79')
    }
    function test_facet_sort_modes() {
        const original = dropdown.options
        dropdown.options = [
            {value:'z',label:'Zebra',count:2},
            {value:'a',label:'Ambient',count:4},
            {value:'b',label:'Blues',count:1}
        ]
        dropdown.sortMode = 'count_desc'
        compare(dropdown.filteredOptions.map(o => o.value).join(','), 'a,z,b')
        dropdown.sortMode = 'count_asc'
        compare(dropdown.filteredOptions.map(o => o.value).join(','), 'b,z,a')
        dropdown.sortMode = 'alpha_asc'
        compare(dropdown.filteredOptions.map(o => o.value).join(','), 'a,b,z')
        dropdown.sortMode = 'alpha_desc'
        compare(dropdown.filteredOptions.map(o => o.value).join(','), 'z,b,a')
        mouseClick(dropdown)
        wait(20)
        const controls = findChild(dropdown, 'filterSortControls')
        verify(controls)
        mouseClick(controls, 30, 13)
        compare(dropdown.sortMode, 'count_desc')
        compare(dropdown.filteredOptions.map(o => o.value).join(','), 'a,z,b')
        dropdown.options = original
    }
}
