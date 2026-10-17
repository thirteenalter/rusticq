import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// Beta 1: one selected display, one aligned editor, safe preview/apply/readback.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 13
    property var drafts: []
    property string selectedName: ""
    property string status: "Reading connected displays…"
    property bool failed: false
    property bool busy: readMonitors.running || editMonitors.running
    readonly property var selected: drafts.find(m => m.name === selectedName) || null
    readonly property real minX: drafts.length ? Math.min.apply(null, drafts.map(m => m.x)) : 0
    readonly property real minY: drafts.length ? Math.min.apply(null, drafts.map(m => m.y)) : 0
    readonly property real maxX: drafts.length ? Math.max.apply(null, drafts.map(m => m.x + m.width / m.scale)) : 1920
    readonly property real maxY: drafts.length ? Math.max.apply(null, drafts.map(m => m.y + m.height / m.scale)) : 1080
    readonly property real previewScale: Math.max(.02, Math.min((preview.width-34) / Math.max(1,maxX-minX), (preview.height-34) / Math.max(1,maxY-minY)))
    function setField(name, field, value) {
        drafts = drafts.map(m => m.name === name ? Object.assign({},m,{[field]:value}) : m);
    }
    function chooseMode(value) {
        if (!selected) return;
        const mode = String(value).replace("Hz", "");
        const match = mode.match(/^(\d+)x(\d+)@/);
        drafts = drafts.map(m => m.name === selectedName ? Object.assign({},m,{
            mode: mode, width: match ? Number(match[1]) : m.width, height: match ? Number(match[2]) : m.height
        }) : m);
    }
    function place(side) {
        if (drafts.length < 2 || !selected) return;
        const target=selected, reference=drafts.find(m=>m.name!==target.name);
        if (!reference) return;
        const rw=Math.round(reference.width/reference.scale), rh=Math.round(reference.height/reference.scale);
        const tw=Math.round(target.width/target.scale), th=Math.round(target.height/target.scale);
        const x=side==="right"?reference.x+rw:side==="left"?reference.x-tw:reference.x;
        const y=side==="below"?reference.y+rh:side==="above"?reference.y-th:reference.y;
        drafts=drafts.map(m=>m.name===target.name?Object.assign({},m,{x:x,y:y}):m);
    }
    QtObject { id: task; property string action: ""; property string input: "" }
    function run(action) {
        if (busy || !drafts.length) return;
        task.action=action;
        task.input=JSON.stringify(drafts)+"\n";
        failed=false;
        status=action==="apply"?"Applying layout and verifying with Hyprland…":action==="export"?"Exporting Lua…":"Checking draft…";
        editMonitors.exec(["python3",Quickshell.shellPath("scripts/rustiq-display.py"),action]);
    }
    Process {
        id: readMonitors
        command: ["hyprctl","-j","monitors"]
        stdout: StdioCollector { onStreamFinished: {
            try {
                const parsed=JSON.parse(this.text);
                if (!Array.isArray(parsed)) throw Error("No monitors array");
                root.drafts=parsed.filter(m=>m.name && m.width>0).map(m=>({
                    name:String(m.name),width:m.width,height:m.height,
                    x:Math.round(m.x||0),y:Math.round(m.y||0),scale:Number(m.scale||1),
                    mode:m.width+"x"+m.height+"@"+Number(m.refreshRate||60).toFixed(2),
                    modes:Array.isArray(m.availableModes)?m.availableModes:[],
                    description:m.description||"",focused:!!m.focused,refreshRate:Number(m.refreshRate||60),
                    transform:m.transform||0,vrr:!!m.vrr
                }));
                if (!root.drafts.some(m=>m.name===root.selectedName)) root.selectedName=root.drafts.length?root.drafts[0].name:"";
                root.status=root.drafts.length?"Select a display, adjust it, then Apply. No changes happen until then.":"No connected display found.";
                root.failed=false;
            } catch(e) {root.failed=true;root.status="Cannot read monitors: "+e;}
        } }
        onExited: (code, reason) => { if (code!==0) {root.failed=true;root.status="hyprctl monitors failed; ensure Hyprland is running.";} }
    }
    Process {
        id: editMonitors
        stdinEnabled: true
        onStarted: write(task.input)
        stdout: StdioCollector { onStreamFinished: {
            try {
                const result=JSON.parse(this.text.trim());
                root.failed=!result.ok;
                root.status=result.message||(result.ok?"Success":"Failed");
                if (result.ok && task.action==="apply") readMonitors.running=true;
            } catch(e) { root.failed=true;root.status="Display helper returned unreadable output: "+e; }
        } }
        onExited: (code,reason) => { if (code!==0 && !root.failed) { root.failed=true;root.status="Display command exited with "+code; } }
    }
    Component.onCompleted: readMonitors.running=true

    RowLayout {
        Layout.fillWidth:true; spacing:10
        ColumnLayout { Layout.fillWidth:true; spacing:3
            Text { text:"Your displays";font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(14);color:Theme.foreground }
            Text { text:root.drafts.length+" connected · drag to arrange";font.pixelSize:Fonts.scale(10);color:Theme.muted }
        }
        Rectangle { Layout.preferredWidth:88;Layout.preferredHeight:32;radius:9;color:Theme.surface
            Text { anchors.centerIn:parent;text:"Refresh";font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(10);color:Theme.foreground }
            MouseArea { anchors.fill:parent;enabled:!root.busy;cursorShape:Qt.PointingHandCursor;onClicked:readMonitors.running=true }
        }
    }
    Rectangle {
        id: preview
        Layout.fillWidth:true;Layout.preferredHeight:220
        radius:14;color:Qt.alpha(Theme.foreground,.035)
        border.color:Theme.borderaccent;clip:true
        Repeater { model:root.drafts
            delegate: Rectangle {
                id:screenChip
                required property var modelData
                readonly property var display:modelData
                width:Math.max(56, Math.round(display.width/display.scale*root.previewScale))
                height:Math.max(36, Math.round(display.height/display.scale*root.previewScale))
                x:16+(display.x-root.minX)*root.previewScale
                y:16+(display.y-root.minY)*root.previewScale
                radius:9
                color:root.selectedName===display.name?Qt.alpha(Theme.accent,.19):Theme.surface
                border.color:root.selectedName===display.name?Theme.accent:Theme.borderaccent
                border.width:root.selectedName===display.name?2:1
                Column { anchors.centerIn:parent;spacing:4
                    Text { anchors.horizontalCenter:parent.horizontalCenter;text:screenChip.display.name;color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
                    Text { anchors.horizontalCenter:parent.horizontalCenter;text:screenChip.display.width+" × "+screenChip.display.height;color:Theme.muted;font.pixelSize:Fonts.scale(9) }
                }
                MouseArea { anchors.fill:parent;cursorShape:Qt.OpenHandCursor
                    drag.target:screenChip
                    drag.minimumX:1;drag.minimumY:1
                    drag.maximumX:Math.max(1,preview.width-screenChip.width-1)
                    drag.maximumY:Math.max(1,preview.height-screenChip.height-1)
                    onPressed:root.selectedName=screenChip.display.name
                    onReleased: {
                        const nx=Math.round(root.minX+(screenChip.x-16)/root.previewScale);
                        const ny=Math.round(root.minY+(screenChip.y-16)/root.previewScale);
                        root.drafts=root.drafts.map(m=>m.name===screenChip.display.name?Object.assign({},m,{x:nx,y:ny}):m);
                    }
                }
            }
        }
    }
    RowLayout { Layout.fillWidth:true;spacing:7
        Repeater { model:root.drafts
            delegate:Rectangle {
                id:monitorSelect
                required property var modelData
                readonly property bool active:root.selectedName===modelData.name
                Layout.fillWidth:true;Layout.preferredHeight:43;radius:10
                color:active?Qt.alpha(Theme.accent,.17):Theme.surface
                border.color:active?Theme.accent:Theme.borderaccent;border.width:1
                RowLayout { anchors.centerIn:parent;spacing:7
                    Icon { icon:"\ue30b";color:monitorSelect.active?Theme.accent:Theme.muted;font.pixelSize:Fonts.scale(16) }
                    Text { text:monitorSelect.modelData.name;color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
                    Icon { visible:monitorSelect.active;icon:"\ue5ca";color:Theme.accent;font.pixelSize:Fonts.scale(15) }
                }
                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.selectedName=monitorSelect.modelData.name }
            }
        }
    }
    Rectangle {
        visible:root.selected!==null
        Layout.fillWidth:true
        Layout.preferredHeight:details.implicitHeight+30
        radius:13;color:Theme.surface
        ColumnLayout { id:details
            anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:15;spacing:12
            RowLayout { Layout.fillWidth:true
                ColumnLayout { Layout.fillWidth:true;spacing:2
                    Text { text:root.selected?root.selected.name:"";font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(14);color:Theme.foreground }
                    Text { text:root.selected?(root.selected.description||"Connected output"):"";elide:Text.ElideRight;Layout.fillWidth:true;color:Theme.muted;font.pixelSize:Fonts.scale(10) }
                }
                Text { text:root.selected&&root.selected.focused?"Focused":"";color:Theme.accent;font.pixelSize:Fonts.scale(10) }
            }
            Text { text:"Resolution and refresh rate";font.family:Fonts.poppinsSB.name;color:Theme.foreground;font.pixelSize:Fonts.scale(11) }
            ComboBox {
                id:modeBox
                Layout.fillWidth:true;Layout.preferredHeight:41
                model:root.selected?(root.selected.modes.length?root.selected.modes:[root.selected.mode]):[]
                currentIndex:root.selected?Math.max(0, model.findIndex(m=>String(m).replace("Hz","")===root.selected.mode)):0
                onActivated: index => {if (index>=0 && index<model.length) root.chooseMode(model[index]);}
                contentItem:Text { text:modeBox.currentText;verticalAlignment:Text.AlignVCenter;leftPadding:13;rightPadding:26;color:Theme.foreground;font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(11);elide:Text.ElideRight }
                background:Rectangle { radius:10;color:Theme.background;border.color:modeBox.pressed?Theme.accent:Theme.borderaccent;border.width:1 }
                indicator:Icon { x:modeBox.width-width-10;y:(modeBox.height-height)/2;icon:"\ue5cf";color:Theme.accent;font.pixelSize:Fonts.scale(17) }
                delegate:ItemDelegate { width:modeBox.width;height:36
                    required property int index
                    required property var modelData
                    contentItem:Text { text:String(modelData);leftPadding:10;verticalAlignment:Text.AlignVCenter;color:Theme.foreground;font.pixelSize:Fonts.scale(10);elide:Text.ElideRight }
                    background:Rectangle { color:highlighted?Qt.alpha(Theme.accent,.23):Theme.background;radius:6 }
                }
                popup:Popup { y:modeBox.height+4;width:modeBox.width;implicitHeight:Math.min(contentItem.implicitHeight+8,238);padding:4
                    contentItem:ListView { clip:true;implicitHeight:contentHeight;model:modeBox.popup.visible?modeBox.delegateModel:null;currentIndex:modeBox.highlightedIndex;ScrollIndicator.vertical:ScrollIndicator{} }
                    background:Rectangle { radius:10;color:Theme.background;border.color:Theme.borderaccent;border.width:1 }
                }
            }
            Text { text:"Scale";color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
            RowLayout { Layout.fillWidth:true;spacing:6
                Repeater { model:[1,1.25,1.5,1.75,2]
                    delegate:Rectangle { id:scaleBtn
                        required property real modelData
                        readonly property bool chosen:root.selected!==null&&Math.abs(root.selected.scale-modelData)<.005
                        Layout.fillWidth:true;Layout.preferredHeight:34;radius:8
                        color:chosen?Qt.alpha(Theme.accent,.17):Theme.background
                        border.color:chosen?Theme.accent:Theme.borderaccent;border.width:1
                        Text { anchors.centerIn:parent;text:scaleBtn.modelData+"×";color:Theme.foreground;font.pixelSize:Fonts.scale(10) }
                        MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:if(root.selected)root.setField(root.selectedName,"scale",scaleBtn.modelData) }
                    }
                }
            }
            Text { text:"Place relative to another display";color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
            RowLayout { Layout.fillWidth:true;spacing:6
                Repeater { model:[{title:"Left",id:"left"},{title:"Right",id:"right"},{title:"Above",id:"above"},{title:"Below",id:"below"}]
                    delegate:Rectangle { id:direction
                        required property var modelData
                        Layout.fillWidth:true;Layout.preferredHeight:34;radius:8;color:Theme.background
                        Text { anchors.centerIn:parent;text:direction.modelData.title;color:Theme.foreground;font.pixelSize:Fonts.scale(10) }
                        MouseArea { anchors.fill:parent;enabled:root.drafts.length>1;cursorShape:Qt.PointingHandCursor;onClicked:root.place(direction.modelData.id) }
                    }
                }
            }
            Text { text:root.selected?"Position "+root.selected.x+", "+root.selected.y+" px · "+root.selected.width+"×"+root.selected.height+" · "+root.selected.scale+"×":"";color:Theme.muted;font.pixelSize:Fonts.scale(10) }
        }
    }
    RowLayout { Layout.fillWidth:true;spacing:8
        Repeater { model:[{title:"Validate",action:"dry-run"},{title:"Apply layout",action:"apply"},{title:"Export Lua",action:"export"}]
            delegate:Rectangle { id:applyButton
                required property var modelData
                Layout.fillWidth:true;Layout.preferredHeight:42;radius:10
                readonly property bool important:modelData.action==="apply"
                color:important?Theme.accent:Theme.surface
                opacity:root.busy?.55:1
                Text { anchors.centerIn:parent;text:applyButton.modelData.title;color:applyButton.important?Theme.background:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
                MouseArea { anchors.fill:parent;enabled:!root.busy&&root.drafts.length>0;cursorShape:Qt.PointingHandCursor;onClicked:root.run(applyButton.modelData.action) }
            }
        }
    }
    Text { Layout.fillWidth:true;text:root.status;color:root.failed?Theme.error:Theme.muted;wrapMode:Text.WordWrap;font.pixelSize:Fonts.scale(11) }
    Text { Layout.fillWidth:true;text:"Apply changes this session and verifies readback. Export Lua creates ~/.config/rustiq/monitors.lua; to persist on Omarchy, copy verified monitor rules into ~/.config/hypr/monitors.lua.";color:Theme.muted;wrapMode:Text.WordWrap;font.pixelSize:Fonts.scale(10) }
    Rectangle { Layout.fillWidth:true;Layout.preferredHeight:34;radius:9;color:Theme.surface
        Text { anchors.centerIn:parent;text:"Open nwg-displays (alternative)";color:Theme.foreground;font.pixelSize:Fonts.scale(11) }
        MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:Quickshell.execDetached(["nwg-displays"]) }
    }
}
