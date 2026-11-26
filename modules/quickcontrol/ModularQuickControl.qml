import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../../config"
import "../../components"
import "../../services"
import "../bar"

Flickable {
    id:root
    objectName:"modularQuickControl"
    contentWidth:width
    contentHeight:content.implicitHeight
    readonly property int preferredContentHeight:Math.ceil(contentHeight)
    clip:true
    boundsBehavior:Flickable.StopAtBounds
    property int dragSelection:-1
    property bool notificationsExpanded:false
    readonly property var sink:Pipewire.defaultAudioSink
    PwObjectTracker {objects:root.visible && root.sink ? [root.sink] : []}
    WifiManager {id:wifi}
    // The Repeater uses permanent identifiers. Saved order changes only grid
    // coordinates, so reordering cannot destroy delegates or their local state.
    readonly property var placement:{
        const result={};let row=0,column=0;
        const columns=width/SettingsStore.uiFontScale>=310 ? 2 : 1;
        for(const key of SettingsStore.quickControlOrder){
            if(key==="notifications" && !SettingsStore.showNotifications)continue;
            const span=key==="wifi" || key==="bluetooth" ? 1 : columns;
            if(column+span>columns){row++;column=0;}
            result[key]={row:row,column:column,span:span};
            column+=span;if(column>=columns){row++;column=0;}
        }
        return result;
    }
    function dragTarget(x,y){
        let nearest=0,distance=Infinity;
        for(let i=0;i<modules.count;i++){
            const item=modules.itemAt(i);if(!item || !item.visible)continue;
            const point=item.mapToItem(content,item.width/2,item.height/2);
            const next=Math.pow(x-point.x,2)+Math.pow(y-point.y,2);
            if(next<distance){distance=next;nearest=SettingsStore.quickControlOrder.indexOf(item.modelData);}
        }
        return nearest;
    }
    ColumnLayout {
        id:content
        width:root.width
        spacing:QuickControlStyle.sectionGap
        RowLayout {
            visible:Store.quickReorderMode
            Layout.fillWidth:true
            QuickControlLabel {Layout.fillWidth:true;text:"Drag a module handle to reorder";wrapMode:Text.Wrap;font.pixelSize:Fonts.scale(10)}
            QuickControlIconButton {symbol:"\ue5d5";label:"Reset module order";onClicked:SettingsStore.resetQuickOrder()}
        }
        GridLayout {
            id:grid
            Layout.fillWidth:true
            columns:root.width/SettingsStore.uiFontScale>=310 ? 2 : 1
            columnSpacing:QuickControlStyle.gap;rowSpacing:QuickControlStyle.gap
            Repeater {
                id:modules
                model:SettingsStore.defaultQuickOrder
                delegate:Item {
                    id:module
                    required property string modelData
                    objectName:"quickModule_"+modelData
                    readonly property var place:root.placement[modelData] || {row:99,column:0,span:1}
                    visible:modelData!=="notifications" || SettingsStore.showNotifications
                    Layout.row:place.row;Layout.column:place.column;Layout.columnSpan:place.span
                    Layout.fillWidth:true;Layout.preferredWidth:1
                    Layout.topMargin: modelData==="system" || modelData==="notifications" ? Math.max(0,QuickControlStyle.sectionGap-QuickControlStyle.gap) : 0
                    implicitHeight:body.item ? body.item.implicitHeight : 0
                    Loader {
                        id:body;anchors.fill:parent
                        sourceComponent:module.modelData==="wifi" ? wifiTile : module.modelData==="bluetooth" ? bluetoothTile : module.modelData==="battery" ? batteryTile : module.modelData==="system" ? systemTiles : notificationSection
                    }
                    Rectangle {
                        anchors.fill:parent
                        visible:Store.quickReorderMode && root.dragSelection===SettingsStore.quickControlOrder.indexOf(module.modelData)
                        color:"transparent";radius:QuickControlStyle.radius
                        border.width:2;border.color:Theme.accent
                    }
                    QuickControlIconButton {
                        objectName:"quickGrip_"+module.modelData
                        visible:Store.quickReorderMode
                        anchors.right:parent.right;anchors.top:parent.top
                        width:26;height:26;symbol:"\ue8d5";label:"Move "+module.modelData
                        MouseArea {anchors.fill:parent;preventStealing:true;cursorShape:Qt.OpenHandCursor
                            onPositionChanged:mouse=>{if(pressed){const p=mapToItem(content,mouse.x,mouse.y);root.dragSelection=root.dragTarget(p.x,p.y);}}
                            onReleased:mouse=>{const p=mapToItem(content,mouse.x,mouse.y);SettingsStore.moveQuickCard(module.modelData,root.dragTarget(p.x,p.y));root.dragSelection=-1;}
                            onCanceled:root.dragSelection=-1}
                        Keys.onLeftPressed:SettingsStore.moveQuickCard(module.modelData,SettingsStore.quickControlOrder.indexOf(module.modelData)-1)
                        Keys.onRightPressed:SettingsStore.moveQuickCard(module.modelData,SettingsStore.quickControlOrder.indexOf(module.modelData)+1)
                    }
                }
            }
        }

    }
    Component {id:wifiTile;QuickControlTile {
        objectName:"quickWifiTile"
        title:"Wi-Fi";symbol:"\ue63e";selected:wifi.wifiEnabled
        toggleAvailable:wifi.wifiDevice!==null && wifi.wifiHardwareEnabled
        subtitle:WifiService.ethernetConnected ? "Ethernet · "+WifiService.ethernetName : WifiService.connectedNetwork ? WifiService.ssid : wifi.wifiEnabled ? "Not connected" : "Off"
        onToggleRequested:wifi.toggleWifi()
        onDetailsRequested:Store.openDeviceSettings("wifi",Store.sidebarScreen,"details",false)
    }}
    Component {id:bluetoothTile;QuickControlTile {
        objectName:"quickBluetoothTile"
        title:"Bluetooth";symbol:BluetoothService.icon;selected:BluetoothService.enabled
        toggleAvailable:BluetoothService.adapter!==null
        subtitle:BluetoothService.connected ? BluetoothService.deviceName : BluetoothService.enabled ? "Not connected" : "Off"
        onToggleRequested:if(BluetoothService.adapter)BluetoothService.adapter.enabled=!BluetoothService.adapter.enabled
        onDetailsRequested:Store.openDeviceSettings("bluetooth",Store.sidebarScreen,"devices",false)
    }}
    Component {id:batteryTile;RowLayout {
        spacing:QuickControlStyle.gap
        QuickControlTile {Layout.fillWidth:true;Layout.preferredWidth:1;title:"Battery";iconLabel:"Open battery details";symbol:BatteryService.icon;selected:BatteryService.charging
            subtitle:(BatteryService.available ? BatteryService.percentage+"% · "+BatteryService.status : "No battery")+" · "+(PowerProfiles.profile===PowerProfile.Performance ? "Performance" : PowerProfiles.profile===PowerProfile.PowerSaver ? "Power saver" : "Balanced")
            onToggleRequested:Store.openDeviceSettings("battery",Store.sidebarScreen,"details",false)
            onDetailsRequested:Store.openDeviceSettings("battery",Store.sidebarScreen,"details",false)}
        QuickControlTile {Layout.fillWidth:true;Layout.preferredWidth:1;title:"Power";iconLabel:"Open power menu";subtitle:"Lock, log out or shut down";symbol:"\ue8ac";onToggleRequested:Store.togglePowerMenu(Store.sidebarScreen);onDetailsRequested:Store.togglePowerMenu(Store.sidebarScreen)}
    }}
    Component {id:systemTiles;ColumnLayout {
        spacing:QuickControlStyle.sectionGap
        QuickControlSlider {
            Layout.fillWidth:true;label:"Display";symbol:"\ue3ab"
            value:BrightnessService.brightness;adjustable:BrightnessService.available
            onUserChanged:next=>BrightnessService.setBrightness(next)
            onIconClicked:{Store.quickAdvancedTab="display";Store.advancedVisible=true;}
            iconEnabled:true
        }
        QuickControlSlider {
            objectName:"quickOutputVolume"
            Layout.fillWidth:true;label:"Sound";symbol:muted ? "\ue04f" : "\ue050"
            value:root.sink && root.sink.audio ? root.sink.audio.volume : 0
            maximumValue:Math.max(1.5,value)
            adjustable:!!(root.sink && root.sink.audio);muted:!!(root.sink && root.sink.audio && root.sink.audio.muted)
            onUserChanged:next=>{if(root.sink && root.sink.audio)root.sink.audio.volume=next;}
            onIconClicked:if(root.sink && root.sink.audio)root.sink.audio.muted=!root.sink.audio.muted
        }
        ColumnLayout {
            Layout.fillWidth:true;spacing:QuickControlStyle.gap
            QuickControlSection {title:"Quick actions"}
            RowLayout {
                Layout.fillWidth:true;spacing:QuickControlStyle.gap
                Repeater {
                    model:[{key:"awake",label:"Awake",icon:"\ue425"},{key:"silent",label:"DND",icon:"\ue7f6"},{key:"night",label:"Night",icon:"\ue51c"},{key:"gaming",label:"Power",icon:"\ue63c"}]
                    ColumnLayout {required property var modelData;Layout.fillWidth:true;spacing:5
                        QuickControlIconButton {Layout.alignment:Qt.AlignHCenter;width:44;height:40;symbol:modelData.icon;label:modelData.label;selected:QuickModesService.active(modelData.key);enabled:QuickModesService.available(modelData.key);onClicked:QuickModesService.toggle(modelData.key)}
                        QuickControlLabel {Layout.alignment:Qt.AlignHCenter;text:modelData.label;color:Theme.contentMuted;font.pixelSize:Fonts.scale(9)}
                    }
                }
            }
            QuickControlLabel {visible:QuickModesService.error.length>0;Layout.fillWidth:true;text:QuickModesService.error;color:Theme.error;wrapMode:Text.Wrap}
        }
        QuickControlMedia {Layout.fillWidth:true}
        BarSystem {Layout.fillWidth:true;framelessQuickControl:true}
    }}
    Component {id:notificationSection;ColumnLayout {
        spacing:QuickControlStyle.gap
        RowLayout {Layout.fillWidth:true
            QuickControlSection {title:"Notifications";detail:NotificationCenter.unread>0 ? NotificationCenter.unread+" unread" : ""}
            QuickControlIconButton {symbol:root.notificationsExpanded ? "\ue5ce" : "\ue5cf";label:"Show notification history";onClicked:{root.notificationsExpanded=!root.notificationsExpanded;if(root.notificationsExpanded)NotificationCenter.markRead();}}
        }
        Loader {Layout.fillWidth:true;active:root.notificationsExpanded;visible:active
            sourceComponent:BarNotifications {framelessQuickControl:true;standalone:true;expanded:true;implicitHeight:520}}
    }}
}
