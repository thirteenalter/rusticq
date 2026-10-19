import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"
import "../../bar"
import ".."

ColumnLayout {
    width: parent ? parent.width : 680
    spacing: 14
    SettingsSection {
        heading: "Display arrangement"
        description: "Choose a display and change resolution, refresh rate, scale or position instantly. Keep within 15 seconds or RusticQ restores the previous layout."
        symbol: "\ue30b"
        BarMonitors { Layout.fillWidth: true }
    }
}
