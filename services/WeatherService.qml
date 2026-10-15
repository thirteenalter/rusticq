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

    Timer {
        interval: 600000     // 10 menit
        running: true
        repeat: true

        triggeredOnStart: true

        onTriggered: {
            proc.exec(["curl", "-sf", "https://wttr.in/?format=%t;%f;%l;%C"]);
        }
    }

    Process {
        id: proc

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(";");

                if (parts.length < 4) {
                    console.log("Weather parse failed:", text);
                    return;
                }

                weather.temperature = parts[0].trim();
                weather.feelsLike = parts[1].trim();
                weather.location = parts[2].trim();
                weather.condition = parts[3].trim();
            }
        }
    }
}
