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
            ctx.clearRect(0, 0, w, h);
            if (w < 4 || h < 4) return;
            ctx.lineWidth = 1;
            ctx.strokeStyle = Theme.borderaccent.toString();
            for (let i = 1; i <= 3; i++) {
                const y = h * i / 4;
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
            }
            const data = root.samples || [];
            if (data.length === 0) return;
            // Make a flat low-usage line readable without fabricating samples.
            const n = Math.max(2, data.length);
            let minValue = 1, maxValue = 0;
            for (let i = 0; i < data.length; ++i) {
                const v = Math.max(0, Math.min(1, Number(data[i]) || 0));
                minValue = Math.min(minValue, v);
                maxValue = Math.max(maxValue, v);
            }
            // Keep true relative changes visible at low system load.
            const range = Math.max(0.08, maxValue - minValue);
            const center = (maxValue + minValue) * 0.5;
            const low = Math.max(0, center - range * 0.75);
            const high = Math.min(1, Math.max(low + 0.08, center + range * 0.75));
            ctx.beginPath();
            for (let i = 0; i < data.length; i++) {
                const x = (i / (n - 1)) * (w - 2) + 1;
                const y = h - 3 - ((Math.max(0, Math.min(1, Number(data[i]) || 0)) - low) / (high - low)) * (h - 6);
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.strokeStyle = root.lineColor.toString();
            ctx.stroke();
            // A thin translucent area communicates ongoing sampling.
            const gradient = ctx.createLinearGradient(0, 0, 0, h);
            gradient.addColorStop(0, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.22));
            gradient.addColorStop(1, Qt.rgba(root.lineColor.r, root.lineColor.g, root.lineColor.b, 0.01));
            ctx.lineTo(w - 1, h - 1);
            ctx.lineTo(1, h - 1);
            ctx.closePath();
            ctx.fillStyle = gradient;
            ctx.fill();
        }
    }
}
