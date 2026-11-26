pragma Singleton
import QtQuick

// Layout metadata shared by real frontends, geometry and gallery previews.
QtObject {
    readonly property var styles: [
        {key:"compact",name:"Legacy Compact",description:"Classic app list with branding and frequent apps",kind:"list",width:660,search:40,font:12,position:"center",backdrop:"dim"},
        {key:"clean-hover",name:"Legacy Clean Compact Hover",description:"A compact header that reveals results on hover",kind:"list",width:660,search:40,font:12,position:"center",backdrop:"dim"},
        {key:"spotlight",name:"Spotlight",description:"A large floating search field, expanding as you type",kind:"list",width:680,search:68,font:22,position:"upper-center",backdrop:"none"},
        {key:"raycast",name:"Raycast",description:"Commands, recent apps, categories and an action footer",kind:"commands",width:760,search:60,font:18,position:"upper-center",backdrop:"none"},
        {key:"launchpad",name:"Launchpad",description:"A spacious app grid with search and categories",kind:"grid",width:1320,search:56,font:20,position:"center",backdrop:"blur"},
        {key:"fluent",name:"Fluent",description:"Pinned applications and recent activity in one panel",kind:"pinned",width:720,search:52,font:18,position:"lower-center",backdrop:"none"},
        {key:"minimal",name:"Minimal",description:"A lightweight search field and focused compact list",kind:"minimal",width:520,search:44,font:16,position:"center",backdrop:"none"},
        {key:"classic",name:"Classic Menu",description:"Bar-relative applications with a category sidebar",kind:"menu",width:740,search:48,font:16,position:"follow-bar",backdrop:"none"},
        {key:"overview",name:"Overview",description:"A large searchable catalog with favorites and recents",kind:"overview",width:1480,search:64,font:22,position:"center",backdrop:"dim-blur"},
        {key:"command",name:"Compact Command",description:"A small search-only command instrument",kind:"command",width:500,search:46,font:16,position:"upper-center",backdrop:"none"},
        {key:"detached",name:"Detached Floating Search",description:"An independent floating search input with a separate results panel that appears as you type.",kind:"detached",width:660,search:64,font:21,position:"upper-center",backdrop:"none"}
    ]
    function spec(key) { return styles.find(value=>value.key===key) || styles[2]; }
    function position(key) { return SettingsStore.launcherPosition === "auto" ? spec(key).position : SettingsStore.launcherPosition; }
    function backdrop(key) { return SettingsStore.launcherBackdropMode === "auto" ? spec(key).backdrop : SettingsStore.launcherBackdropMode; }
    function animation() { return SettingsStore.launcherAnimationStyle === "inherit" ? SettingsStore.animationStyle
        : SettingsStore.launcherAnimationStyle === "scale" ? "zoom" : SettingsStore.launcherAnimationStyle === "none" ? "fade" : SettingsStore.launcherAnimationStyle; }
    function clamp(value,min,max) { return Math.max(min,Math.min(Math.max(min,max),value)); }
    function inputWidth(key,screenWidth) {
        const automatic=SettingsStore.launcherUseStyleDefaults && key!=="compact" && key!=="clean-hover";
        const maximum=Math.max(120,screenWidth-16), minimum=Math.min(280,maximum);
        return Math.round(clamp(automatic ? spec(key).width : SettingsStore.launcherWidth,minimum,maximum));
    }
    function searchHeight(key) { return key==="detached" ? SettingsStore.detachedLauncherInputHeight
        : SettingsStore.launcherUseStyleDefaults || key==="compact" || key==="clean-hover" ? spec(key).search : SettingsStore.launcherSearchHeight; }
    function searchFont(key) { return key==="detached" ? SettingsStore.detachedLauncherInputFontSize
        : SettingsStore.launcherUseStyleDefaults || key==="compact" || key==="clean-hover" ? spec(key).font : SettingsStore.launcherSearchFontSize; }
    function maximumHeight(key,screenHeight) { return SettingsStore.launcherUseStyleDefaults && (key==="launchpad" || key==="overview") ? Math.max(240,screenHeight-110)
        : SettingsStore.launcherUseStyleDefaults && key!=="compact" && key!=="clean-hover"
            ? (key==="command" ? 340 : key==="minimal" ? 420 : key==="fluent" ? 620 : 520) : SettingsStore.launcherHeight; }
    function anchor(key,screenWidth,screenHeight,inputWidth,inputHeight) {
        const location=position(key), pad=20;
        let x=(screenWidth-inputWidth)/2, y=(screenHeight-inputHeight)/2;
        if(location==="upper-center") y=screenHeight*.18;
        if(location==="lower-center") y=screenHeight*.60;
        if(location.indexOf("top-")===0) y=pad+40;
        if(location.indexOf("bottom-")===0) y=screenHeight-inputHeight-pad;
        if(location.endsWith("left")) x=pad;
        if(location.endsWith("right")) x=screenWidth-inputWidth-pad;
        if(location==="custom") {x=SettingsStore.launcherCustomX*(screenWidth-inputWidth);y=SettingsStore.launcherCustomY*(screenHeight-inputHeight);}
        if(location==="follow-bar") {
            const trigger=Store.launcherAnchor;
            if(trigger && Store.launcherScreen && trigger.screenName===Store.launcherScreen.name) {
                if(trigger.position==="top") {x=trigger.x;y=trigger.y+trigger.height+8;}
                if(trigger.position==="bottom") {x=trigger.x;y=trigger.y-inputHeight-8;}
                if(trigger.position==="left") {x=trigger.x+trigger.width+8;y=trigger.y;}
                if(trigger.position==="right") {x=trigger.x-inputWidth-8;y=trigger.y;}
                return Qt.point(clamp(x+SettingsStore.launcherOffsetX,8,screenWidth-inputWidth-8),clamp(y+SettingsStore.launcherOffsetY,8,screenHeight-inputHeight-8));
            }
            if(SettingsStore.barPosition==="top") {x=pad;y=60;}
            if(SettingsStore.barPosition==="bottom") {x=pad;y=screenHeight-inputHeight-60;}
            if(SettingsStore.barPosition==="left") {x=80;y=pad+40;}
            if(SettingsStore.barPosition==="right") {x=screenWidth-inputWidth-80;y=pad+40;}
        }
        return Qt.point(clamp(x+SettingsStore.launcherOffsetX,8,screenWidth-inputWidth-8),clamp(y+SettingsStore.launcherOffsetY,8,screenHeight-inputHeight-8));
    }
}
