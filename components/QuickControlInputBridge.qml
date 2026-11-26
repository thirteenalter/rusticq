import QtQuick
import "../config"

// Legacy controls keep their handlers. Register only actual input controls,
// including dynamically-created device/notification rows, for the window mask.
Item {
    id:root
    visible:false
    property Item target:null
    property bool active:true
    property var registered:[]
    readonly property var candidates:active && target ? collect(target) : []
    function collect(item){
        let found=[];
        if(item!==target && !item.visible)return found;
        if(item!==target && item.quickWindow!==undefined)return found; // self-registering surfaces
        if(item.activeFocusOnTab || (item.acceptedButtons!==undefined && item.cursorShape!==undefined))found.push(item);
        for(const child of item.children || [])if(child!==root)found=found.concat(collect(child));
        return found;
    }
    onCandidatesChanged:{
        for(const item of registered)Store.removeQuickControlInput(item);
        registered=candidates;
        for(const item of registered)Store.addQuickControlInput(item);
    }
    Component.onDestruction:{for(const item of registered)Store.removeQuickControlInput(item);}
}
