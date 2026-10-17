pragma Singleton
import QtQuick

QtObject {
    readonly property FontLoader mediumFont: FontLoader { source: "../assets/Poppins-Medium.ttf" }
    readonly property FontLoader semiboldFont: FontLoader { source: "../assets/Poppins-SemiBold.ttf" }
    readonly property FontLoader boldFont: FontLoader { source: "../assets/Poppins-Bold.ttf" }
    readonly property string chosenFamily: SettingsStore.uiFontFamily === "custom" && SettingsStore.uiCustomFont.length > 0 ? SettingsStore.uiCustomFont
                                            : SettingsStore.uiFontFamily === "sans" ? "Sans Serif"
                                            : SettingsStore.uiFontFamily === "mono" ? "Monospace" : (mediumFont.status === FontLoader.Ready ? mediumFont.name : "Sans Serif")
    readonly property var poppins: ({ name: chosenFamily })
    readonly property var poppinsSB: ({ name: SettingsStore.uiFontFamily === "poppins" && semiboldFont.status === FontLoader.Ready ? semiboldFont.name : chosenFamily })
    readonly property var poppinsB: ({ name: SettingsStore.uiFontFamily === "poppins" ? (boldFont.status === FontLoader.Ready ? boldFont.name : chosenFamily) : chosenFamily })
    function scale(value) { return Math.max(8, Math.round(value * SettingsStore.uiFontScale)); }
}
