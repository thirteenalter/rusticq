pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import "../config"

Singleton {
    id: root
    property var history: []
    property var toast: null
    property bool doNotDisturb: false
    property int unread: 0
    property int sequence: 0
    property bool groupByApp: false
    property var expandedApps: ({})
    function toggleGroup(app) {
        const map = Object.assign({}, expandedApps);
        map[app] = !map[app];
        expandedApps = map;
    }
    readonly property var displayHistory: groupByApp ? groupedHistory() : history
    function groupedHistory() {
        const counts = {};
        const first = [];
        for (const note of history) {
            const key = String(note.app || "Application");
            counts[key] = (counts[key] || 0) + 1;
            if (counts[key] === 1) first.push(note);
            else if (expandedApps[key]) first.push(note);
        }
        return first.map(note => Object.assign({}, note, {groupCount: counts[String(note.app || "Application")] || 1}));
    }
    property string serverState: "checking"
    property string serverOwner: "Checking notification service…"
    property string serverAdvice: ""
    property int serverPid: 0
    readonly property bool receivesSystemNotifications: serverState === "owned"

    function refreshServerStatus() {
        if (!doctor.running)
            doctor.exec(["python3", Quickshell.shellPath("scripts/rustiq-notification-doctor.py"), String(Quickshell.processId)]);
    }

    function plain(text) {
        return String(text || "").replace(/<[^>]*>/g, "").trim();
    }

    function initials(app) {
        const src = plain(app) || "App";
        const words = src.split(/\s+/).filter(Boolean);
        if (!words.length) return "A";
        if (words.length === 1) return words[0].charAt(0).toUpperCase();
        return (words[0].charAt(0) + words[1].charAt(0)).toUpperCase();
    }

    function normalizedImage(source) {
        const src = String(source || "").trim();
        if (!src) return "";
        if (src.indexOf("://") !== -1 || src.indexOf("qrc:/") === 0 || src.indexOf("image://") === 0)
            return src;
        if (src.charAt(0) === "/") return "file://" + src;
        return src;
    }

    function detectKind(appName, title, body, image) {
        const haystack = (String(appName || "") + " " + String(title || "") + " " + String(body || "")).toLowerCase();
        if (haystack.indexOf("screenshot") !== -1 || haystack.indexOf("clipboard") !== -1) return "screenshot";
        if (haystack.indexOf("download") !== -1 || haystack.indexOf("saved") !== -1) return "file";
        if (haystack.indexOf("warning") !== -1 || haystack.indexOf("error") !== -1 || haystack.indexOf("failed") !== -1) return "alert";
        return "generic";
    }

    function glyphFor(kind) {
        switch (kind) {
        case "screenshot": return "\ue3b0";
        case "file": return "\ue2c7";
        case "alert": return "\ue002";
        default: return "\ue7f4";
        }
    }

    function tagFor(kind) {
        switch (kind) {
        case "screenshot": return "Screenshot";
        case "file": return "Saved";
        case "alert": return "Alert";
        default: return "Notification";
        }
    }

    function previewNotification() {
        const sample = {
            serial: ++sequence,
            id: -1,
            app: "RusticQ Preview",
            appInitials: "RQ",
            appIcon: "",
            title: "Notification UI preview",
            body: "Cleaner typography, better spacing and optional screenshot previews now match the rest of RusticQ.",
            when: Qt.formatTime(new Date(), "HH:mm"),
            image: "",
            urgency: 1,
            kind: "generic",
            glyph: "\ue7f4",
            tag: "Preview",
            actions: [],
            reference: null,
            preview: true
        };
        history = [sample].concat(history).slice(0, 40);
        unread = Math.min(40, unread + 1);
        if (!doNotDisturb) {
            toast = sample;
            toastTimer.restart();
        }
    }

    function clockFinished(alarm, duration) {
        const entry = {
            serial: ++sequence,
            id: -1,
            app: "RusticQ",
            appInitials: "RQ",
            appIcon: "",
            title: alarm ? "Alarm · " + Store.clockAlarmTime : "Timer finished",
            body: alarm ? "Your alarm is ringing." : "Your " + duration + " timer is complete.",
            when: Qt.formatTime(new Date(), "HH:mm"),
            image: "",
            urgency: 1,
            kind: "generic",
            glyph: alarm ? "\ue855" : "\ue425",
            tag: alarm ? "Alarm" : "Timer",
            clockSequence: Store.clockAlertSequence,
            actions: alarm ? [{text: "Stop", sourceIndex: 0}, {text: "Snooze 5 min", sourceIndex: 1}]
                : [{text: "Stop", sourceIndex: 0}],
            reference: null
        };
        history = [entry].concat(history).slice(0, 40);
        unread = Math.min(40, unread + 1);
        if (!doNotDisturb) {
            toast = entry;
            toastTimer.restart();
        }
    }

    Connections {
        target: Store
        function onClockTimerCompleted(durationSeconds) {
            root.clockFinished(false, Store.formatClockTimer(durationSeconds));
        }
        function onClockAlarmCompleted() { root.clockFinished(true, ""); }
        function onClockSoundRequested(alarm) { root.playClockSound(alarm ? "alarm" : "timer"); }
        function onClockSoundStopped() { root.stopClockSound(); }
    }
    property string pendingClockSound: ""
    property int clockSoundGeneration: 0
    property bool clockSoundActive: false
    property bool clockSoundStopping: false
    function playClockSound(kind) {
        clockSoundGeneration++;
        Store.clockSoundError = "";
        if (clockSoundActive) {
            pendingClockSound = kind;
            clockSoundStopping = true;
            Store.clockSoundPlaying = false;
            clockSound.running = false;
        } else {
            clockSoundActive = true;
            clockSoundStopping = false;
            Store.clockSoundPlaying = true;
            const command = ["python3", Quickshell.shellPath("scripts/rusticq-clock-sound.py"), kind,
                "--sound", SettingsStore.clockSound, "--volume", String(SettingsStore.clockSoundVolume)];
            if (SettingsStore.clockSound === "custom") command.push("--file", SettingsStore.clockSoundFile);
            if (SettingsStore.clockSoundLoop) command.push("--loop");
            clockSound.exec(command);
        }
    }
    function stopClockSound() {
        clockSoundGeneration++;
        pendingClockSound = "";
        clockSoundStopping = true;
        Store.clockSoundPlaying = false;
        clockSound.running = false;
    }
    Connections {
        target: SettingsStore
        function onClockSoundEnabledChanged() { if (!SettingsStore.clockSoundEnabled) root.stopClockSound(); }
        function onClockSoundChanged() { root.restartClockSound(); }
        function onClockSoundFileChanged() { root.restartClockSound(); }
        function onClockSoundVolumeChanged() { root.restartClockSound(); }
        function onClockSoundLoopChanged() { root.restartClockSound(); }
    }
    function restartClockSound() {
        if (clockSoundActive && SettingsStore.clockSoundEnabled)
            root.playClockSound(Store.clockAlertKind === "alarm" ? "alarm" : "timer");
    }
    Process {
        id: clockSound
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) Store.clockSoundError = text.trim().slice(0, 200)
        }
        onExited: (code, status) => {
            const stopped = root.clockSoundStopping;
            root.clockSoundActive = false;
            root.clockSoundStopping = false;
            Store.clockSoundPlaying = false;
            if (code !== 0 && !stopped && !Store.clockSoundError && !root.pendingClockSound)
                Store.clockSoundError = "Clock sound could not be played. Check the audio output.";
            if (root.pendingClockSound) {
                const kind = root.pendingClockSound;
                const generation = root.clockSoundGeneration;
                root.pendingClockSound = "";
                Qt.callLater(function() {
                    if (SettingsStore.clockSoundEnabled && generation === root.clockSoundGeneration) root.playClockSound(kind);
                });
            }
        }
    }

    Process {
        id: doctor
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(this.text.trim());
                    root.serverState = result.state || "error";
                    root.serverOwner = result.owner || "Unknown";
                    root.serverPid = result.pid || 0;
                    root.serverAdvice = result.suggestion || "";
                } catch (e) {
                    root.serverState = "error";
                    root.serverAdvice = "Unable to read notification service diagnostic output.";
                }
            }
        }
    }

    Timer {
        interval: 7000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refreshServerStatus()
    }

    function hideToast() {
        toastTimer.stop();
        toast = null;
    }

    // Clock actions are local and scoped to the current alert. System actions
    // are only those actually supplied by the D-Bus sender.
    function invokeAction(serial, index) {
        const item = history.find(e => e.serial === serial);
        if (item && item.clockSequence !== undefined) {
            if (item.clockSequence !== Store.clockAlertSequence || !Store.clockAlertKind) return;
            if (index === 0) Store.dismissClockAlert();
            else if (index === 1 && Store.clockAlertKind === "alarm") Store.snoozeClockAlarm();
            else return;
            hideToast();
            return;
        }
        if (!item || !item.reference || index < 0) return;
        try {
            const acts = item.reference.actions;
            if (!acts || index >= acts.length) return;
            acts[index].invoke();
            hideToast();
        } catch (e) {
            console.warn("[RusticQ notifications] action unavailable:", e);
        }
    }

    function receive(n) {
        n.tracked = true;
        if (n.lastGeneration) return;
        const appName = n.appName || "Application";
        const title = plain(n.summary) || "Notification";
        const body = plain(n.body);
        const image = normalizedImage(n.image || "");
        const kind = detectKind(appName, title, body, image);
        const actions = [];
        if (n.actions) {
            for (let i = 0; i < n.actions.length && i < 2; ++i) {
                const a = n.actions[i];
                if (a && a.text) actions.push({ text: String(a.text), sourceIndex: i });
            }
        }
        const entry = {
            serial: ++sequence,
            id: n.id,
            app: appName,
            appInitials: initials(appName),
            appIcon: n.appIcon || "",
            title: title,
            body: body,
            when: Qt.formatTime(new Date(), "HH:mm"),
            image: image,
            urgency: n.urgency !== undefined ? n.urgency : 1,
            kind: kind,
            glyph: glyphFor(kind),
            tag: tagFor(kind),
            actions: actions,
            reference: n
        };
        history = [entry].concat(history).slice(0, 40);
        unread = Math.min(40, unread + 1);
        if (!doNotDisturb) {
            toast = entry;
            toastTimer.restart();
        }
    }

    function dismiss(serial) {
        const item = history.find(e => e.serial === serial);
        if (item && item.reference) {
            try { item.reference.dismiss(); } catch (e) {}
        }
        history = history.filter(e => e.serial !== serial);
        if (toast && toast.serial === serial) toast = null;
    }

    function clear() {
        for (const item of history) {
            if (item.reference) {
                try { item.reference.dismiss(); } catch (e) {}
            }
        }
        history = [];
        unread = 0;
        toast = null;
    }

    function markRead() { unread = 0; }

    Timer { id: toastTimer; interval: 6200; onTriggered: root.toast = null }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: notification => root.receive(notification)
    }
}
