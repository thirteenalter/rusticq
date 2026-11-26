import QtQuick
import "../config"

// Presentation outlives a close request until the last frame. Window owners
// keep their loader alive using presented and release focus using shown.
Item {
    id: root
    visible: false
    property Item target: null
    property bool shown: false
    property bool animate: Theme.motionEnabled
    property bool startReady: true
    property real travelDistance: Theme.motionDistance
    property string edge: "center"
    property string style: SettingsStore.animationStyle
    property real closedScale: 0.98
    property real progress: 0
    property bool ready: false
    readonly property bool presented: shown || progress > 0
    readonly property bool animating: animation.running
    readonly property bool slides: style === "slide" || style === "float" || style === "spring"
    readonly property bool scales: style === "zoom" || style === "float" || style === "spring"
    readonly property real hiddenScale: style === "zoom" ? Math.min(0.90, closedScale) : style === "spring" ? Math.min(0.95, closedScale) : closedScale
    readonly property real surfaceScale: scales ? hiddenScale + (1 - hiddenScale) * progress : 1
    readonly property real surfaceOpacity: style === "slide" ? (presented ? 1 : 0) : Math.max(0, Math.min(1, progress))
    readonly property real offsetX: slides ? (1 - progress) * travelDistance
        * (edge === "left" ? -1 : edge === "right" ? 1 : 0)
        : 0
    readonly property real offsetY: slides ? (1 - progress) * travelDistance
        * (edge === "top" ? -1 : edge === "bottom" || edge === "center" ? 1 : 0)
        : 0

    function update() {
        if (!ready) return;
        animation.stop();
        const next = shown ? 1 : 0;
        if (animate && shown && !startReady) {
            progress = 0;
            return;
        }
        if (!animate || progress === next) {
            progress = next;
            return;
        }
        animation.from = progress;
        animation.to = next;
        animation.duration = Math.max(1, Math.round((shown ? Theme.motionEnterDuration : Theme.motionExitDuration)
            * Math.abs(next - progress)));
        animation.start();
    }
    function replay() {
        if (!shown || !ready) return;
        animation.stop();
        progress = animate ? 0 : 1;
        update();
    }
    onShownChanged: update()
    onStyleChanged: replay()
    onAnimateChanged: update()
    onStartReadyChanged: update()
    Component.onCompleted: { ready = true; update(); }
    NumberAnimation {
        id: animation
        target: root
        property: "progress"
        easing.type: root.style === "spring" && root.shown ? Easing.OutBack : Easing.OutCubic
        easing.overshoot: 0.7
    }
    Binding { target: root.target; property: "opacity"; value: root.surfaceOpacity; when: root.target !== null }
    Binding { target: root.target; property: "scale"; value: root.surfaceScale; when: root.target !== null }
    Binding { target: root.target; property: "enabled"; value: root.shown; when: root.target !== null }
}
