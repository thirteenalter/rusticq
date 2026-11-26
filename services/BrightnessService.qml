pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root
    property real brightness: 0
    property int pendingBrightness: 50
    property bool available: false
    property string error: ""
    property bool writing: false
    property bool queued: false
    readonly property bool observed: Store.sidebarVisible && (QuickControlStyle.modular
        ? !Store.advancedVisible || Store.quickAdvancedTab === "display" : Store.advancedVisible)
    function refresh() { if (!read.running && !writing && !debounce.running) read.running=true; }
    function setBrightness(level) {
        if (!available || !Number.isFinite(level)) return;
        pendingBrightness=Math.round(Math.max(.01,Math.min(1,level))*100);
        brightness=pendingBrightness/100;
        queued=true;
        debounce.restart();
    }
    function flush() {
        if (writing || !queued) return;
        queued=false; writing=true;
        write.exec(["brightnessctl","-c","backlight","set",pendingBrightness+"%"]);
    }
    Process {
        id: read
        command:["brightnessctl","-c","backlight","-m"]
        stdout:StdioCollector { onStreamFinished: {
            const match=this.text.trim().match(/(\d+)%/);
            root.available=!!match;
            if(match && !root.queued && !root.writing){root.brightness=Math.max(0,Math.min(1,Number(match[1])/100));root.error="";}
        } }
        onExited:(code,status)=>{if(code!==0){root.available=false;root.error="No supported backlight or brightnessctl unavailable";}}
    }
    Process {
        id:write
        onExited:(code,status)=>{root.writing=false;if(code!==0)root.error="Backlight permission denied";else root.error="";if(root.queued)debounce.restart();}
    }
    Timer {id:debounce;interval:130;onTriggered:root.flush()}
    Timer {interval:5000;repeat:true;running:root.observed;triggeredOnStart:true;onTriggered:root.refresh()}
}
