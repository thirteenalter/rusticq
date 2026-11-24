import QtQuick
import QtQuick.Controls
import "../../components"
import "../../config"

// The same three zones map to Top / Middle / Bottom. Center the middle zone
// when space permits; clamp between neighbours and scroll on shorter screens.
Item {
    id: root
    required property var hostWindow
    signal requestPopup(string kind, real localX, real localY)
    signal requestMenu(string section, var sourceItem)
    readonly property bool clean: SettingsStore.barMode === "clean-compact"
    readonly property bool compact: clean || SettingsStore.barMode === "compact"
    readonly property bool professional: SettingsStore.barMode === "professional"
    readonly property bool separated: SettingsStore.barMode === "separated"
    readonly property bool simple: SettingsStore.barMode === "simple"
    readonly property int zoneCount: (topZone.implicitHeight > 0 ? 1 : 0)
        + (midZone.implicitHeight > 0 ? 1 : 0) + (bottomZone.implicitHeight > 0 ? 1 : 0)
    readonly property real minimumContentHeight: topZone.implicitHeight + midZone.implicitHeight
        + bottomZone.implicitHeight + Math.max(0, zoneCount - 1) * Theme.barRailZoneGap
    Connections {
        target: SettingsStore
        function onBarModeChanged() { scroll.contentY = 0; }
    }
    Flickable {
        id: scroll
        objectName: "bar-rail-viewport"
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height, root.minimumContentHeight)
        boundsBehavior: Flickable.StopAtBounds
        onContentHeightChanged: returnToBounds()
        ScrollIndicator.vertical: ScrollIndicator { width: 2 }
        Item {
            width: scroll.width
            height: scroll.contentHeight
            BarZone {
                id: topZone
                objectName: "bar-rail-zone-left"
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth
                height: implicitHeight
                visible: activeKeys.length > 0
                hostWindow: root.hostWindow
                zone: "left"
                vertical: true
                compact: root.compact
                clean: root.clean
                separated: root.separated
                professional: root.professional
                simple: root.simple
                controlHeight: Theme.barRailItemSize
            }
            BarZone {
                id: midZone
                objectName: "bar-rail-zone-center"
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth
                height: implicitHeight
                visible: activeKeys.length > 0
                y: Math.max(topZone.implicitHeight > 0 ? topZone.implicitHeight + Theme.barRailZoneGap : 0,
                    Math.min((scroll.height - implicitHeight) / 2,
                        scroll.contentHeight - implicitHeight - (bottomZone.implicitHeight > 0 ? bottomZone.implicitHeight + Theme.barRailZoneGap : 0)))
                hostWindow: root.hostWindow
                zone: "center"
                vertical: true
                compact: root.compact
                clean: root.clean
                separated: root.separated
                professional: root.professional
                simple: root.simple
                controlHeight: Theme.barRailItemSize
            }
            BarZone {
                id: bottomZone
                objectName: "bar-rail-zone-right"
                anchors.horizontalCenter: parent.horizontalCenter
                width: implicitWidth
                height: implicitHeight
                visible: activeKeys.length > 0
                y: scroll.contentHeight - implicitHeight
                hostWindow: root.hostWindow
                zone: "right"
                vertical: true
                compact: root.compact
                clean: root.clean
                separated: root.separated
                professional: root.professional
                simple: root.simple
                controlHeight: Theme.barRailItemSize
            }
        }
    }
}
