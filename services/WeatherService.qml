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
    property double lastUpdated: 0

    function description(entries) {
        return Array.isArray(entries) && entries.length && entries[0] && typeof entries[0].value === "string"
            ? entries[0].value.trim() : "";
    }
    function numeric(value) {
        if (typeof value === "number") return value;
        if (typeof value !== "string" || value.trim() === "") return NaN;
        return Number(value);
    }
    function applyResponse(text) {
        try {
            const data = JSON.parse(text);
            const current = Array.isArray(data.current_condition) ? data.current_condition[0] : null;
            if (!current || current.temp_C === null || current.temp_C === undefined
                || String(current.temp_C).trim() === "") throw Error("Missing temperature");
            const degrees = numeric(current.temp_C);
            const feels = numeric(current.FeelsLikeC);
            const summary = description(current.weatherDesc);
            if (!Number.isFinite(degrees) || degrees < -100 || degrees > 70 || !summary)
                throw Error("Invalid current conditions");
            const area = Array.isArray(data.nearest_area) ? data.nearest_area[0] : null;
            const city = area ? description(area.areaName) : "";
            const region = area ? description(area.region) : "";
            const country = area ? description(area.country) : "";
            temperature = Math.round(degrees) + "°C";
            feelsLike = Number.isFinite(feels) && feels >= -150 && feels <= 150 ? Math.round(feels) + "°C" : "";
            location = [city || region, country].filter((part, index, all) => part && all.indexOf(part) === index).join(", ");
            condition = summary;
            lastUpdated = Date.now();
            lastError = "";
            return true;
        } catch (error) {
            lastError = temperature ? "Weather update unavailable. Showing the last available weather."
                : "Weather data unavailable. Refresh to retry.";
            return false;
        }
    }

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
        proc.exec(["curl", "--fail", "--silent", "--show-error", "--connect-timeout", "5", "--max-time", "15", "https://wttr.in/?format=j1&m"]);
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
                weather.applyResponse(this.text);
            }
        }
        onExited: (exitCode, exitStatus) => {
            weather.loading = false;
            if (exitCode !== 0) weather.lastError = weather.temperature
                ? "Weather refresh failed. Showing the last available weather; check your connection."
                : "Weather request failed. Check your connection and refresh to retry.";
        }
    }
}
