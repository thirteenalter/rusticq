import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../components"

ColumnLayout {
    id: root
    required property var palette
    property real x1: 0.23
    property real y1: 1
    property real x2: 0.32
    property real y2: 1
    property string previewKind: "windows"
    property real previewSpeed: 4
    property bool previewEnabled: true
    signal edited(real x1, real y1, real x2, real y2)
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        HyprSettingsLabel { palette: root.palette; text: "Animation curve"; Layout.fillWidth: true }
        HyprSettingsButton { palette: root.palette; text: "Preview"; onClicked: preview.restart() }
    }
    Rectangle {
        id: graph
        Layout.fillWidth: true
        implicitHeight: 145
        radius: 10
        color: root.palette.background
        Canvas {
            id: canvas
            anchors.fill: parent
            anchors.margins: 16
            onPaint: {
                const c = getContext("2d"); c.reset();
                c.strokeStyle = root.palette.line; c.lineWidth = 1;
                c.beginPath(); c.moveTo(0,height); c.lineTo(width,0); c.stroke();
                c.beginPath(); c.moveTo(0,height); c.lineTo(root.x1*width,(1-root.y1)*height);
                c.moveTo(width,0); c.lineTo(root.x2*width,(1-root.y2)*height); c.stroke();
                c.strokeStyle = root.palette.accent; c.lineWidth = 2;
                c.beginPath(); c.moveTo(0,height); c.bezierCurveTo(root.x1*width,(1-root.y1)*height,root.x2*width,(1-root.y2)*height,width,0); c.stroke();
            }
            Repeater {
                model: 2
                Rectangle {
                    id: handle
                    required property int index
                    x: (index === 0 ? root.x1 : root.x2) * canvas.width - 5
                    y: (1 - (index === 0 ? root.y1 : root.y2)) * canvas.height - 5
                    width: 10; height: 10; radius: 5; color: root.palette.accent
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            const p = mapToItem(canvas, mouse.x, mouse.y);
                            const x = Math.max(0,Math.min(1,p.x/canvas.width));
                            const y = Math.max(0,Math.min(1,1-p.y/canvas.height));
                            if (handle.index === 0) { root.x1=x;root.y1=y; } else { root.x2=x;root.y2=y; }
                            canvas.requestPaint(); root.edited(root.x1,root.y1,root.x2,root.y2);
                        }
                    }
                }
            }
        }
        Connections { target: root; function onX1Changed(){canvas.requestPaint();} function onY1Changed(){canvas.requestPaint();} function onX2Changed(){canvas.requestPaint();} function onY2Changed(){canvas.requestPaint();} }
        Rectangle {
            id: sample
            property real progress: 0
            x: root.previewKind === "workspaces" ? 12 + progress * (graph.width - width - 24) : graph.width-width-14
            y: root.previewKind === "layers" ? graph.height-height-8 + (1-progress)*25 : graph.height-height-8
            width: 42; height: 27; radius: 5; color: root.palette.accent
            scale: root.previewKind === "windowsOut" ? 1-progress*0.5 : root.previewKind.indexOf("windows")===0 ? 0.6+progress*0.4 : 1
            opacity: root.previewKind === "windowsOut" ? 1-progress : root.previewKind === "fade" || root.previewKind.indexOf("windows")===0 ? progress : 1
            border.width: root.previewKind === "border" ? 3 : 0
            border.color: Qt.alpha(root.palette.foreground,progress)
            NumberAnimation {
                id: preview; target: sample; property: "progress"; from: 0; to: 1
                duration: root.palette.motionEnabled && root.previewEnabled ? Math.max(100,Math.min(3000,root.previewSpeed*100)) : 0
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [root.x1,root.y1,root.x2,root.y2,1,1]
            }
        }
    }
}
