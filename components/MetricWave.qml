import QtQuick
import "../config"

// Small history chart. The caller supplies measured samples in [0, 1].
Item {
    id: root
    property var samples: []
    property color lineColor: Theme.accent
    implicitHeight: 54
    onSamplesChanged: chart.requestPaint()
    onLineColorChanged: chart.requestPaint()
    onWidthChanged: chart.requestPaint()
    onHeightChanged: chart.requestPaint()
    Canvas {
        id: chart
        anchors.fill: parent
        renderTarget: Canvas.Image
        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height;
            ctx.reset();
            ctx.clearRect(0, 0, w, h);
            if (w < 4 || h < 4) return;
            ctx.lineWidth = 1;
            ctx.strokeStyle = Theme.borderaccent.toString();
            for (let i = 1; i <= 3; i++) {
                const y = h * i / 4;
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
            }
            const data = root.samples;
            if (!data || data.length === 0) return;
            const n = Math.max(2, data.length);
            ctx.beginPath();
            for (let i = 0; i < data.length; i++) {
                const x = (i / (n - 1)) * (w - 2) + 1;
                const y = h - 3 - Math.max(0, Math.min(1, Number(data[i]) || 0)) * (h - 6);
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.strokeStyle = root.lineColor.toString();
            ctx.stroke();
        }
    }
}
