import QtQuick
import QtQuick.Layouts
import "../config"

Pill {
    color: Theme.borderaccent
    horizontalPadding: 14
    verticalPadding: 7

    RowLayout {
        spacing: 12
        Bluetooth {}
        Wifi {}
        Battery {}
    }
}
