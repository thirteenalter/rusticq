import QtQuick
import "../config"

GlassLabel {
    font.family: Fonts.poppins.name
    font.pixelSize: Fonts.scale(11)
    color: Theme.foreground
    style: Text.Raised
    styleColor: Qt.alpha(Theme.shadow,0.8)
}
