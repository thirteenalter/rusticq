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
        description: "Preview the connected monitors, expand each screen for resolution, refresh rate and scale, then Apply."
        symbol: "\ue30b"
        BarMonitors { Layout.fillWidth: true }
    }
}
