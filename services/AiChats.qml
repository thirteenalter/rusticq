pragma Singleton
import QtQuick
import Quickshell

// Session-only threads. Prompts stay in memory, never in user-settings.json.
Singleton {
    id: root
    property var threads: []
    property int activeId: -1
    property int nextId: 1
    readonly property var activeThread: threads.find(item => item.id === activeId) || null
    readonly property var activeMessages: activeThread ? activeThread.messages : []
    readonly property string currentTitle: activeThread ? activeThread.title : "New conversation"

    function newChat() {
        const id = nextId++;
        threads = [{ id:id, title:"New conversation", messages:[] }].concat(threads);
        activeId = id;
    }
    function selectChat(id) {
        if (threads.some(item => item.id === id)) activeId = id;
    }
    function append(role, content) {
        if (activeId === -1) newChat();
        const next = threads.map(item => {
            if (item.id !== activeId) return item;
            const messages = item.messages.concat([{role:role, content:String(content)}]);
            const title = item.title === "New conversation" && role === "user"
                ? String(content).replace(/\s+/g, " ").slice(0, 46) || "New conversation" : item.title;
            return {id:item.id, title:title, messages:messages};
        });
        threads = next;
    }
    function remove(id) {
        threads = threads.filter(item => item.id !== id);
        if (activeId === id) activeId = threads.length ? threads[0].id : -1;
    }
    function safeMarkdown(value) {
        // Do not auto-fetch third-party image URLs supplied by model responses.
        return String(value || "").replace(new RegExp("!\\[([^\\]]*)\\]\\([^)]*\\)", "g"), "[image omitted: $1]")
                                   .replace(new RegExp("<img\\b[^>]*>", "gi"), "");
    }
    function clearCurrent() {
        threads = threads.map(item => item.id === activeId ? {id:item.id,title:"New conversation",messages:[]} : item);
    }
    Component.onCompleted: if (threads.length === 0) newChat()
}
