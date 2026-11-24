import QtQuick
import Quickshell

// Keep the closing window until its motion finishes. The active binding never
// reads item: LazyLoader changes item while evaluating active on destruction.
LazyLoader {
    id: root
    property bool shown: false
    property bool keepLoaded: false
    property bool held: false
    active: shown || keepLoaded || held
    function syncHeld() { held = item ? item.presented : false; }
    onItemChanged: Qt.callLater(syncHeld)
    property Connections presentationConnection: Connections {
        target: root.item
        ignoreUnknownSignals: true
        function onPresentedChanged() { Qt.callLater(root.syncHeld); }
    }
}
