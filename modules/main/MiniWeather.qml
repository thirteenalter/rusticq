import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

Item {
    id: root
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            Icon { icon: WeatherService.icon; font.pixelSize: Fonts.scale(22); color: Theme.accent; Layout.preferredWidth: 28 }
            Text { text: "Weather"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16); color: Theme.foreground; Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                radius: 10; color: Theme.surface
                Icon { anchors.centerIn: parent; icon: "\ue5d5"; font.pixelSize: Fonts.scale(18); color: Theme.accent }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: WeatherService.refresh() }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.borderaccent }
        Text {
            text: WeatherService.temperature || "--°"
            font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(35); color: Theme.foreground
        }
        Text {
            Layout.fillWidth: true
            text: WeatherService.condition || (WeatherService.loading ? "Updating weather…" : "Weather unavailable")
            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(13); color: Theme.foreground
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            Icon { icon: "\ue1ff"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
            Text { text: "Feels like"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true }
            Text { text: WeatherService.feelsLike || "—"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
        }
        RowLayout {
            Layout.fillWidth: true
            Icon { icon: "\ue0c8"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
            Text { text: WeatherService.location || "Location unavailable"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true; elide: Text.ElideRight }
        }
        Text {
            visible: WeatherService.lastError !== ""
            text: WeatherService.lastError
            font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: Theme.warning
            Layout.fillWidth: true; wrapMode: Text.WordWrap
        }
        Item { Layout.fillHeight: true }
    }
}
