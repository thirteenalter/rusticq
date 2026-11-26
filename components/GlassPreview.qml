import QtQuick
import QtQuick.Layouts
import "../config"

Item {
    id: root
    implicitHeight: 186
    Rectangle {
        anchors.fill: parent
        radius: Theme.rowRadius
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.mix(Theme.background, Theme.accent, 0.55) }
            GradientStop { position: 1; color: Theme.background }
        }
    }
    GlassSurface {
        id: sample
        objectName: "glassPreviewSurface"
        anchors.fill: parent
        anchors.margins: 14
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 9
            RowLayout {
                Layout.fillWidth: true
                Icon { icon: "\ue3ab"; color: Theme.accent; font.pixelSize: Fonts.scale(22) }
                GlassLabel { objectName: "glassPreviewText"; text: "RAGE"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(17) }
                Item { Layout.fillWidth: true }
                GlassLabel { text: SettingsStore.glassmorphismEnabled ? SettingsStore.glassStyle : "Standard"; color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            }
            GlassLabel { Layout.fillWidth: true; text: "RUSTIQ ADAPTIVE GLASS ENGINE"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
            Rectangle {
                objectName: "glassPreviewControl"
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: Theme.glassRadius("control", Theme.rowRadius)
                color: Theme.glassColor("control", Theme.surface)
                RowLayout {
                    anchors.centerIn: parent; spacing: 9
                    Icon { icon: "\ue63e"; color: Theme.accent; font.pixelSize: Fonts.scale(16) }
                    GlassLabel { text: "Adaptive surfaces · clear typography"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                }
            }
        }
    }
}
