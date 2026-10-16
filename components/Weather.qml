import QtQuick
import "../config"
import "../services"

Pill {
    id: root
    property bool showIcon: true
    property bool showDetails: true
    signal activated(real localX)
    color: "transparent"
    horizontalPadding: 4
    verticalPadding: 1

    InfoSegment {
        id: weatherPart
        symbol: WeatherService.icon
        showCaption: root.showDetails
        caption: WeatherService.temperature !== "" ? WeatherService.temperature : "--°"
        symbolColor: Theme.foreground
        onActivated: {
            const point = weatherPart.mapToItem(root, weatherPart.width / 2, 0);
            root.activated(point.x);
        }
    }
}
