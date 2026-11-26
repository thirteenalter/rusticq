import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

Item {
    id: root
    implicitHeight: weatherContent.implicitHeight + Theme.panelPadding * 2
    Flickable {
        id: weatherScroll
        objectName: "weatherScroll"
        anchors.fill: parent
        contentWidth: width
        contentHeight: weatherContent.implicitHeight + Theme.panelPadding * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: weatherContent
        objectName: "surfaceContent"
            x: Theme.panelPadding; y: Theme.panelPadding
            width: Math.max(0, weatherScroll.width - Theme.panelPadding * 2)
            spacing: Theme.contentGap
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                Icon { icon: WeatherService.icon; font.pixelSize: Fonts.scale(22); color: Theme.accent; Layout.preferredWidth: 28 }
                GlassLabel { text: "Weather"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(16); color: Theme.foreground; Layout.fillWidth: true }
                ActionButton {
                    objectName: "weatherRefreshButton"
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    symbol: "\ue5d5"
                    enabled: !WeatherService.loading
                    Accessible.name: "Refresh weather"
                    onClicked: WeatherService.refresh()
                }
            }
            Item { Layout.fillWidth: true; Layout.preferredHeight: Theme.sectionGap }
            GlassLabel {
                text: WeatherService.temperature || "--°"
                font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(35); color: Theme.foreground
            }
            GlassLabel {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: WeatherService.condition || (WeatherService.loading ? "Updating weather…" : "Weather unavailable")
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(13); color: Theme.foreground
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "\ue1ff"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                GlassLabel { text: "Feels like"; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true }
                GlassLabel { text: WeatherService.feelsLike || "—"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
            }
            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "\ue0c8"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                GlassLabel { textFormat: Text.PlainText; text: WeatherService.location || "Location unavailable"; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); Layout.fillWidth: true; elide: Text.ElideRight }
            }
            GlassLabel {
                objectName: "weatherStatus"
                visible: WeatherService.loading || WeatherService.lastError !== "" || WeatherService.lastUpdated > 0
                text: WeatherService.loading ? "Updating weather…" : WeatherService.lastError
                    || "Updated " + Qt.formatTime(new Date(WeatherService.lastUpdated), "HH:mm")
                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); color: WeatherService.lastError ? Theme.warning : Theme.muted
                Layout.fillWidth: true; wrapMode: Text.WordWrap
            }
        }
    }
}
