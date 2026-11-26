import QtQuick
import "../config"

Item {
    id: gauge
    readonly property var settingsTheme: SettingsMaterial.forItem(gauge)
    property real speed: 0
    property real peakSpeed: speed
    property string phaseLabel: "Download"
    property bool modern: false
    property bool animate: gauge.settingsTheme.motionEnabled && SettingsStore.speedTestGaugeAnimation
    property bool glow: SettingsStore.speedTestGaugeGlow && gauge.settingsTheme.glassEffects && gauge.settingsTheme.glassReflections
    readonly property real maximumSpeed: rangeFor(Math.max(speed, peakSpeed))
    property real displayedSpeed: Math.max(0, speed)
    property real displayedFraction: Math.max(0, Math.min(1, speed / maximumSpeed))
    readonly property color trackColor: Qt.alpha(gauge.settingsTheme.foreground, 0.12)
    readonly property color accentColor: gauge.settingsTheme.accent
    readonly property color tickColor: gauge.settingsTheme.contentMuted
    implicitWidth: 128
    implicitHeight: 128
    Accessible.role: Accessible.Indicator
    Accessible.name: phaseLabel + " " + speed.toFixed(1) + " Mbps"

    function rangeFor(value) {
        for (const range of [100, 250, 500, 1000, 2500, 5000, 10000])
            if (value <= range) return range;
        return Math.pow(10, Math.ceil(Math.log(value) / Math.LN10));
    }
    function repaint() { if (visible) dial.requestPaint(); }
    onDisplayedFractionChanged: repaint()
    onMaximumSpeedChanged: repaint()
    onTrackColorChanged: repaint()
    onAccentColorChanged: repaint()
    onTickColorChanged: repaint()
    onModernChanged: repaint()
    onGlowChanged: repaint()
    onVisibleChanged: if (visible) repaint()
    Behavior on displayedSpeed { enabled: gauge.animate && gauge.visible; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on displayedFraction { enabled: gauge.animate && gauge.visible; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Canvas {
        id: dial
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: gauge.repaint()
        onHeightChanged: gauge.repaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const size = Math.min(width, height);
            const cx = width / 2, cy = height * 0.44, radius = size * 0.41;
            const start = Math.PI * 0.75, sweep = Math.PI * 1.5;
            ctx.lineCap = "round";
            ctx.lineWidth = 4;
            ctx.strokeStyle = gauge.trackColor;
            ctx.beginPath(); ctx.arc(cx, cy, radius, start, start + sweep); ctx.stroke();
            if (gauge.displayedFraction > 0) {
                if (gauge.glow) { ctx.shadowColor = gauge.accentColor; ctx.shadowBlur = 5; }
                ctx.strokeStyle = gauge.accentColor;
                ctx.beginPath(); ctx.arc(cx, cy, radius, start, start + sweep * gauge.displayedFraction); ctx.stroke();
                ctx.shadowBlur = 0;
            }
            if (!gauge.modern) {
                ctx.lineWidth = 1;
                ctx.strokeStyle = gauge.tickColor;
                for (let i = 0; i <= 20; i++) {
                    const angle = start + sweep * i / 20;
                    const outer = radius - 7, inner = outer - (i % 5 === 0 ? 5 : 2.5);
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * inner, cy + Math.sin(angle) * inner);
                    ctx.lineTo(cx + Math.cos(angle) * outer, cy + Math.sin(angle) * outer);
                    ctx.stroke();
                }
                const angle = start + sweep * gauge.displayedFraction;
                ctx.lineWidth = 2;
                ctx.strokeStyle = gauge.accentColor;
                ctx.beginPath(); ctx.moveTo(cx, cy);
                ctx.lineTo(cx + Math.cos(angle) * (radius - 15), cy + Math.sin(angle) * (radius - 15)); ctx.stroke();
                ctx.fillStyle = gauge.accentColor;
                ctx.beginPath(); ctx.arc(cx, cy, 4, 0, Math.PI * 2); ctx.fill();
            }
        }
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: gauge.modern ? parent.height * 0.25 : parent.height * 0.53
        spacing: 0
        GlassLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: gauge.displayedSpeed.toFixed(1)
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Fonts.scale(gauge.modern ? 24 : 20)
            font.features: ({"tnum": 1})
            color: gauge.settingsTheme.foreground
        }
        GlassLabel { anchors.horizontalCenter: parent.horizontalCenter; text: "Mbps"; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9); color: gauge.settingsTheme.contentMuted }
        GlassLabel { anchors.horizontalCenter: parent.horizontalCenter; text: gauge.phaseLabel; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(9); color: gauge.settingsTheme.accent }
    }
}
