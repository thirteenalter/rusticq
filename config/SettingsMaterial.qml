pragma Singleton
import QtQuick

QtObject {
    readonly property var defaults: ({mode:"follow",windowOpacity:0.52,sidebarOpacity:0.28,groupOpacity:0.055,
        popoverOpacity:0.96,outline:true,outlineOpacity:0.16,outlineWidth:1,radius:16,accent:"#568ff5",
        sidebarWidth:248,density:"comfortable",animations:true,iconStyle:"color",shadow:0.12})
    function preferences(app) {
        const saved=SettingsStore.settingsWindowAppearance;
        const explicit=Object.assign({},saved.shared || {},saved[app] && saved[app].enabled ? saved[app].values : {});
        const values=Object.assign({},defaults,explicit);
        if(values.mode==="follow" && !Object.prototype.hasOwnProperty.call(explicit,"windowOpacity"))
            values.windowOpacity=Theme.glassEnabled?Theme.glassWindow.a:1;
        return values;
    }
    function wantsBlur(app) {
        const mode=preferences(app).mode;
        return (mode.indexOf("rage-")===0 || (mode==="follow" && Theme.glassEnabled))
            && !SettingsStore.glassPerformanceMode && !SettingsStore.lowMemoryShellMode;
    }
    // Visual scope is inherited through real Items, including Loader content.
    // A standalone device/card without a settings frame keeps its original Theme.
    function forItem(item) {
        let cursor=item;
        while(cursor) {
            if(cursor.settingsDesign) return cursor.settingsDesign;
            cursor=cursor.parent;
        }
        return Theme;
    }
    function highlightForItem(item) {
        let cursor=item;
        while(cursor) { if(cursor.settingsHighlight!==undefined)return cursor.settingsHighlight;cursor=cursor.parent; }
        return "";
    }
    function reveal(item) {
        let cursor=item.parent;
        while(cursor) {
            if(cursor.objectName==="settings-content-scroll") {
                const offset=item.mapToItem(cursor.contentItem,0,0).y-20;
                cursor.contentY=Math.max(0,Math.min(offset,cursor.contentHeight-cursor.height));return;
            }
            cursor=cursor.parent;
        }
    }
}
