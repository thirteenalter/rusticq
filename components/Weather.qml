import QtQuick
import "../config"
import "../services"

Pill {
    color: "transparent"
    horizontalPadding: 7
    verticalPadding: 6

    Text {
        // wttr.in %t already includes °C or °F; do not append a second degree.
        text: WeatherService.temperature !== "" ? WeatherService.temperature : "--°"
        color: Theme.foreground
        font.family: Fonts.poppins.name
        font.pixelSize: 12
    }
}
