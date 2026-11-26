import QtQuick
import QtQuick.Layouts
import "../../config"

// The viewport owns scrolling; each sibling card owns exactly one content inset.
Flickable {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    objectName: "networkPanelViewport"
    property var popupScreen: null
    signal shareQrRequested(var screen, string ssid)
    implicitHeight: cards.implicitHeight
    contentWidth: width
    contentHeight: cards.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    clip: true
    ColumnLayout {
        id: cards
        width: root.width
        spacing: root.settingsTheme.contentGap
        BarWifi {
            id: wifiCard
            objectName: "networkWifiCard"
            standalone: true
            externalScroll: true
            popupScreen: root.popupScreen
            Layout.fillWidth: true
            onAdvancedOpenChanged: root.contentY = 0
            onShareQrRequested: (screen, ssid) => root.shareQrRequested(screen, ssid)
        }
        Loader {
            objectName: "speedTestPanelLoader"
            Layout.fillWidth: true
            active: SettingsStore.showSpeedTestPanel && wifiCard.advancedOpen
            visible: active
            sourceComponent: BarSpeedTest {}
        }
    }
}
