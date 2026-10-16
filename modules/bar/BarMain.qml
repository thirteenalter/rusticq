import QtQuick
import QtQuick.Layouts
import "../../config"

// Both pages are contained in the existing PanelWindow. The Advanced button
// swaps the content page without spawning an additional Wayland layer/window.
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true

    Flickable {
        id: quickScroll
        anchors.fill: parent
        visible: !Store.advancedVisible
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: quickColumn.implicitHeight + 2

        ColumnLayout {
            id: quickColumn
            width: quickScroll.width
            spacing: Theme.sectionGap

            BarWifi {
                Layout.fillWidth: true
                Layout.preferredHeight: expanded ? Math.max(310, Math.min(480, root.height * 0.47)) : 64
                onExpandedChanged: if (expanded) quickScroll.contentY = 0
            }
            BarBluetooth { Layout.fillWidth: true }
            BarBattery { Layout.fillWidth: true }
            BarSystem { Layout.fillWidth: true }
            BarNotifications { Layout.fillWidth: true; visible: SettingsStore.showNotifications }
        }
    }
    BarAdvanced {
        anchors.fill: parent
        visible: Store.advancedVisible
    }
}
