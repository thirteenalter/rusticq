import QtQuick
import "../../../config"
import "../../bar"

BarWifi {
    standalone: true
    fullSettings: true
    popupScreen: Store.settingsScreen
    onShareQrRequested: (screen, ssid) => Store.openWifiQr(screen, ssid)
}
