pragma Singleton
import QtQuick

// Runtime display metadata for this source build. Keep in sync with /VERSION.
// Changing this value does not publish a release to GitHub.
QtObject {
    readonly property string tag: "beta-3"
    readonly property string displayName: "Beta 3"
    readonly property string channel: "beta"
    readonly property int betaNumber: 3
    readonly property string requiredQuickshell: "0.3.1"
}
