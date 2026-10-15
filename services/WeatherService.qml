pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: weather

    property string temperature: ""
    property string feelsLike: ""
    property string location: ""
    property string condition: ""

    readonly property string text: temperature + " " + location
    readonly property string icon: {
        const c = condition.toLowerCase();
        if (c.includes("thunder") || c.includes("storm")) return "\uebdb";
        if (c.includes("snow") || c.includes("sleet")) return "\ue2cd";
        if (c.includes("rain") || c.includes("drizzle") || c.includes("shower")) return "\uf176";
        if (c.includes("fog") || c.includes("mist") || c.includes("haze")) return "\ue818";
        if (c.includes("partly") || c.includes("overcast") || c.includes("cloud")) return "\uf172";
        if (c.includes("clear") || c.includes("sunny")) return "\ue81a";
        return "\uf60b"; // weather_mix, when the data has no condition yet
    }
    property bool loading: false
    property string lastError: ""
    function refresh() {
        if (proc.running) return;
        loading = true;
        lastError = "";
        proc.exec(["curl", "-sf", "--max-time", "12", "https://wttr.in/?format=%t;%f;%l;%C"]);
    }

    Timer {
        interval: 600000     // 10 menit
        running: true
        repeat: true

        triggeredOnStart: true

        onTriggered: weather.refresh()
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(";");

                if (parts.length < 4) {
                    weather.lastError = "Weather data unavailable. Tap refresh to retry.";
                    return;
                }

                weather.temperature = parts[0].trim();
                weather.feelsLike = parts[1].trim();
                weather.location = parts[2].trim();
                weather.condition = parts[3].trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            weather.loading = false;
            if (exitCode !== 0) weather.lastError = "Weather request failed (check network).";
        }
    }
}
