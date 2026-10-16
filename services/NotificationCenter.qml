pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root
    // Immutable summaries remain readable even after a notification expires.
    property var history: []
    property var toast: null
    property bool doNotDisturb: false
    property int unread: 0
    property int sequence: 0

    function receive(n) {
        n.tracked = true;
        const entry = {
            serial: ++sequence,
            id: n.id,
            app: n.appName || "Application",
            title: n.summary || "Notification",
            body: n.body || "",
            when: Qt.formatTime(new Date(), "HH:mm"),
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
            try { item.reference.dismiss(); } catch (e) { /* already closed by sender */ }
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
    Timer { id: toastTimer; interval: 5800; onTriggered: root.toast = null }
    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        actionsSupported: false
        onNotification: notification => root.receive(notification)
    }
}
