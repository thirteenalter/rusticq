import QtQuick
import "../../../components/settings" as Suite
Suite.SettingsColorPicker {
    required property var palette
    design: palette
    format: "hyprland"
}
