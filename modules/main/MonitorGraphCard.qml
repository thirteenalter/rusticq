import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"

// Read-only measured data chart: fixed [0,1] for percent; bytes/s scaled to
// maximum observed throughput (scale is shown in the subtitle by the caller).
Rectangle {
    id: card
    required property string heading
    required property string valueLabel
    required property string detail
    required property string glyph
    property var history: []
    property bool percentage: false
    readonly property real maxMeasured: Math.max(1, Math.max.apply(null, history))
    readonly property var normalized: percentage ? history : history.map(v => Math.max(0, Math.min(1, v / maxMeasured)))
    color: Theme.glassColor("card", Theme.surface)
    radius: Theme.glassRadius("card", 13)
    border.width: Theme.glassBorderWidth("card", 0)
    implicitHeight: 183

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.cardPadding
        spacing: 9
        RowLayout {
            Layout.fillWidth: true
            spacing: 9
            Rectangle {
                Layout.preferredWidth: 30; Layout.preferredHeight: 30
                radius: Theme.glassRadius("card", 9); color: Theme.glassColor("card", Qt.alpha(Theme.accent, 0.15))
                Icon { anchors.centerIn: parent; icon: card.glyph; font.pixelSize: Fonts.scale(17); color: Theme.accent }
            }
            GlassLabel {
                Layout.fillWidth: true
                text: card.heading
                color: Theme.foreground
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Fonts.scale(12)
                elide: Text.ElideRight
            }
            GlassLabel {
                text: card.valueLabel
                color: Theme.accent
                font.family: Fonts.poppinsSB.name
                font.pixelSize: Fonts.scale(13)
            }
        }
        MetricWave {
            Layout.fillWidth: true
            Layout.preferredHeight: 93
            samples: card.normalized
        }
        GlassLabel {
            Layout.fillWidth: true
            text: card.detail
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(10)
            color: Theme.contentMuted
            elide: Text.ElideRight
        }
    }
}
