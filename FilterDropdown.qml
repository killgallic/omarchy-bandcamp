import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ActionButton {
    id: root
    property string title: ''
    property var options: []
    property var selectedValues: []
    property bool multiple: true
    property bool searchable: true
    property bool showCounts: true
    readonly property bool isOpen: popup.opened
    readonly property var filteredOptions: options.filter(option => option.label.toLowerCase().indexOf(search.text.toLowerCase()) >= 0)
    signal selectionChanged(var values)
    text: title + (multiple && selectedValues.length ? ' · ' + selectedValues.length : '') + '  ▾'
    emphasized: selectedValues.length > 0 && multiple
    Accessible.name: title
    Accessible.description: 'Open ' + title.toLowerCase() + ' options'
    onClicked: popup.opened ? popup.close() : popup.open()
    function close() { popup.close() }
    function choose(option) {
        if (showCounts && option.count === 0 && selectedValues.indexOf(option.value) < 0) return
        let values = selectedValues.slice()
        const index = values.indexOf(option.value)
        if (!multiple) values = [option.value]
        else if (index >= 0) values.splice(index, 1)
        else values.push(option.value)
        selectionChanged(values)
        if (!multiple) popup.close()
    }
    Popup {
        id: popup
        y: root.height + 6
        width: Math.min(340, root.Window.window ? root.Window.window.width - 24 : 340)
        height: Math.min(root.Window.window ? root.Window.window.height - 32 : 420,
                         (root.searchable ? 112 : 58) + Math.min(8, Math.max(1, root.filteredOptions.length)) * 38)
        padding: 10
        margins: 12
        popupType: Popup.Item
        modal: true
        dim: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        palette.base: root.surface
        palette.text: root.foreground
        palette.windowText: root.foreground
        palette.highlight: root.accent
        onOpened: { if (root.searchable) search.forceActiveFocus(); else choices.forceActiveFocus(); choices.currentIndex = 0 }
        onClosed: { search.clear(); root.forceActiveFocus() }
        background: Rectangle { color: root.surface; radius: 7; border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3) }
        contentItem: ColumnLayout {
            spacing: 8
            TextField {
                id: search; objectName: 'filterSearch'
                visible: root.searchable
                Layout.fillWidth: true
                placeholderTextColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
                placeholderText: 'Search ' + root.title.toLowerCase() + '…'
                color: root.foreground
                selectByMouse: true
                onTextChanged: { choices.currentIndex = 0; choices.positionViewAtBeginning() }
                Keys.onDownPressed: { choices.forceActiveFocus(); choices.currentIndex = 0 }
                Keys.onReturnPressed: if (root.filteredOptions.length) root.choose(root.filteredOptions[0])
            }
            ListView {
                id: choices; objectName: 'filterOptions'
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.filteredOptions
                keyNavigationEnabled: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AlwaysOn }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse
                    onWheel: event => {
                        const delta = event.pixelDelta.y ? -event.pixelDelta.y : -event.angleDelta.y
                        choices.contentY = Math.max(choices.originY, Math.min(choices.originY + Math.max(0, choices.contentHeight - choices.height), choices.contentY + delta))
                        event.accepted = true
                    }
                }
                Keys.onReturnPressed: if (currentIndex >= 0) root.choose(root.filteredOptions[currentIndex])
                Keys.onSpacePressed: if (currentIndex >= 0) root.choose(root.filteredOptions[currentIndex])
                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    readonly property bool chosen: root.selectedValues.indexOf(modelData.value) >= 0
                    width: choices.width - 12; height: 38
                    enabled: !root.showCounts || modelData.count > 0 || chosen
                    Accessible.name: modelData.label
                    Accessible.checkable: root.multiple
                    Accessible.checked: chosen
                    onClicked: { choices.currentIndex = index; root.choose(modelData) }
                    background: Rectangle { radius: 4; color: parent.hovered || (choices.activeFocus && choices.currentIndex === index) ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16) : 'transparent' }
                    contentItem: RowLayout {
                        opacity: parent.enabled ? 1 : 0.4
                        Text { text: chosen ? '✓' : ' '; Layout.preferredWidth: 18; color: root.accent }
                        Text { text: modelData.label; textFormat: Text.PlainText; color: root.foreground; Layout.fillWidth: true; elide: Text.ElideRight }
                        Text { text: root.showCounts ? String(modelData.count) : ''; color: root.foreground; opacity: 0.5 }
                    }
                }
                Text { anchors.centerIn: parent; visible: choices.count === 0; text: 'No matching options'; color: root.foreground; opacity: 0.6 }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: root.multiple ? root.selectedValues.length + ' selected' : 'Collection order'; color: root.foreground; opacity: 0.65; font.pixelSize: 11; Layout.fillWidth: true }
                ActionButton { visible: root.multiple; text: 'Clear'; enabled: root.selectedValues.length > 0; foreground: root.foreground; surface: root.surface; accent: root.accent; implicitHeight: 28; onClicked: root.selectionChanged([]) }
                ActionButton { text: 'Done'; foreground: root.foreground; surface: root.surface; accent: root.accent; implicitHeight: 28; onClicked: popup.close() }
            }
        }
    }
}
