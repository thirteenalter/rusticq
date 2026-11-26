pragma Singleton
import QtQuick
import QtQuick.Window

QtObject {
    readonly property bool modular: SettingsStore.quickControlLayout !== "classic"
    readonly property bool frameless: SettingsStore.quickControlLayout === "frameless"
    readonly property bool panelBackground: !modular || (!frameless && SettingsStore.quickControlPanelBackground)
    readonly property bool panelOutline: !modular || (!frameless && SettingsStore.quickControlPanelOutline)
    readonly property bool motion: Theme.motionEnabled && (!modular || SettingsStore.quickControlAnimations)
    readonly property bool compact: SettingsStore.quickControlCompact || SettingsStore.uiDensity === "compact"
    readonly property int gap: SettingsStore.quickControlComponentSpacing
    readonly property int sectionGap: SettingsStore.quickControlSectionSpacing
    readonly property int radius: SettingsStore.quickControlComponentRadius
    readonly property int iconRadius: SettingsStore.quickControlIconRadius
    readonly property bool glass: Theme.glassEnabled && SettingsStore.quickControlComponentGlass
    function surface(selected, hovered, pressed) {
        const restingAlpha = SettingsStore.quickControlComponentBackground ? SettingsStore.quickControlSurfaceOpacity : 0;
        const hoverAlpha = Math.max(restingAlpha, SettingsStore.quickControlHoverOpacity);
        const alpha = pressed ? Math.min(1, hoverAlpha + .04) : hovered ? hoverAlpha : restingAlpha;
        // These controls have no component-local backdrop blur. Give each one
        // a readable material; the structural gaps stay fully transparent.
        const material = glass ? Theme.glassTint : Theme.surface;
        const base = selected && SettingsStore.quickControlAccentTint ? Theme.mix(material, Theme.accent, .18) : material;
        return Qt.alpha(base,alpha);
    }
    // Input regions follow controls and intersect every clipping ancestor. No
    // timer or full-panel MouseArea captures the transparent gaps.
    function hitRect(item, windowItem, revision) {
        if (!item || !item.visible || item.Window.window !== windowItem.Window.window) return {x:0,y:0,width:0,height:0};
        const geometryDependency=item.x+item.y+item.width+item.height;
        const point=item.mapToItem(windowItem,0,0);
        let left=point.x,top=point.y,right=left+item.width,bottom=top+item.height;
        for(let parent=item.parent;parent && parent!==windowItem;parent=parent.parent){
            const dependency=parent.x+parent.y+parent.width+parent.height;
            if(parent.clip){
                const clip=parent.mapToItem(windowItem,0,0);
                left=Math.max(left,clip.x);top=Math.max(top,clip.y);
                right=Math.min(right,clip.x+parent.width);bottom=Math.min(bottom,clip.y+parent.height);
            }
        }
        return {x:Math.floor(left),y:Math.floor(top),width:Math.max(0,Math.ceil(right-left)),height:Math.max(0,Math.ceil(bottom-top))};
    }
}
