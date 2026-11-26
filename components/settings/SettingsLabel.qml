import QtQuick
import "../../config"
Text {
    required property var design
    color: design.foreground
    style: design.glassEnabled && !design.lightPalette ? Text.Raised : Text.Normal
    styleColor: design.glassTextShadow
    font.family: Fonts.poppins.name
    font.pixelSize: Fonts.scale(13)
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
}
