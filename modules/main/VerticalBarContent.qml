import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../config"

// Left/Center/Right placement maps to Top/Middle/Bottom on vertical bars.
// Scrollable when users enable more icons than can fit on screen.
Item {
    id: root
    required property var hostWindow
    signal requestPopup(string kind, real localX, real localY)
    signal requestMenu(string section, var sourceItem)
    readonly property bool clean: SettingsStore.barMode === "clean-compact"
    readonly property bool compact: clean || SettingsStore.barMode === "compact"
    readonly property bool professional: SettingsStore.barMode === "professional"
    readonly property bool separated: SettingsStore.barMode === "separated"

    Flickable {
        id: scroll
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, groups.implicitHeight)
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: groups
            width: scroll.width
            spacing: 8
            BarZone {
                id: topZone
                hostWindow: root.hostWindow
                zone: "left"
                vertical: true
                compact: root.compact
                clean: root.clean
                separated: root.separated
                professional: root.professional
                controlHeight: 30
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: implicitHeight
                Layout.preferredWidth: implicitWidth
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(12, (scroll.height - topZone.implicitHeight - midZone.implicitHeight - bottomZone.implicitHeight - 24) / 2)
            }
            BarZone {
                id: midZone
                hostWindow: root.hostWindow
                zone: "center"
                vertical: true
                compact: root.compact
                clean: root.clean
                separated: root.separated
                professional: root.professional
                controlHeight: 30
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: implicitHeight
                Layout.preferredWidth: implicitWidth
            }
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(12, (scroll.height - topZone.implicitHeight - midZone.implicitHeight - bottomZone.implicitHeight - 24) / 2)
            }
            BarZone {
                id: bottomZone
                hostWindow: root.hostWindow
                zone: "right"
                vertical: true
                compact: root.compact
                clean: root.clean
                separated: root.separated
                professional: root.professional
                controlHeight: 30
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: implicitHeight
                Layout.preferredWidth: implicitWidth
            }
        }
    }
}
