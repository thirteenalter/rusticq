import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"

// Beta 1 live displays: HyprMon-style change-on-selection, verified readback and timed rollback.
ColumnLayout {
    id: root
    property var appearance: null
    readonly property var controlTheme: appearance || Theme
    property bool framelessQuickControl: false
    Layout.fillWidth: true
    spacing: 13
    property var drafts: []
    property string selectedName: ""
    property string status: "Reading connected displays…"
    property bool failed: false
    property bool awaitingKeep: false
    property int secondsLeft: 0
    property bool preserveReadStatus: false
    property bool busy: readMonitors.running || editMonitors.running
    readonly property var selected: drafts.find(m => m.name === selectedName) || null
    readonly property real minX: drafts.length ? Math.min.apply(null, drafts.map(m => m.x)) : 0
    readonly property real minY: drafts.length ? Math.min.apply(null, drafts.map(m => m.y)) : 0
    readonly property real maxX: drafts.length ? Math.max.apply(null, drafts.map(m => m.x + m.width / m.scale)) : 1920
    readonly property real maxY: drafts.length ? Math.max.apply(null, drafts.map(m => m.y + m.height / m.scale)) : 1080
    readonly property real previewScale: Math.max(.02, Math.min((preview.width-34) / Math.max(1,maxX-minX), (preview.height-34) / Math.max(1,maxY-minY)))
    function setField(name, field, value) {
        if (busy) return;
        drafts = drafts.map(m => m.name === name ? Object.assign({},m,{[field]:value}) : m);
        scheduleLive();
    }
    function scheduleLive() {
        if (!busy) liveTimer.restart();
    }
    Timer {
        id: liveTimer
        interval: 140
        repeat: false
        onTriggered: root.run("apply")
    }
    Timer {
        interval: 1000
        running: root.awaitingKeep
        repeat: true
        onTriggered: {
            if (root.secondsLeft > 0) root.secondsLeft -= 1;
            if (root.secondsLeft <= 0) {
                root.awaitingKeep = false;
                root.status = "Revert timer expired. Reading restored monitor layout…";
                root.preserveReadStatus = true;
                readMonitors.running = true;
            }
        }
    }
    function chooseMode(value) {
        if (!selected) return;
        const mode = String(value).replace("Hz", "");
        const match = mode.match(/^(\d+)x(\d+)@/);
        drafts = drafts.map(m => m.name === selectedName ? Object.assign({},m,{
            mode: mode, width: match ? Number(match[1]) : m.width, height: match ? Number(match[2]) : m.height
        }) : m);
        scheduleLive();
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
        scheduleLive();
    }
    QtObject { id: task; property string action: ""; property string input: "" }
    function run(action) {
        if (busy || (action !== "keep" && action !== "revert" && !drafts.length)) return;
        liveTimer.stop();
        task.action=action;
        task.input=(action === "keep" || action === "revert") ? "" : JSON.stringify(drafts)+"\n";
        failed=false;
        status=action==="apply"?"Applying immediately and checking Hyprland…":
               action==="keep"?"Keeping this display layout…":
               action==="revert"?"Restoring the previous layout…":"Exporting Lua…";
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
                if (!root.preserveReadStatus)
                    root.status=root.drafts.length?"Changes apply immediately. You will have 15 seconds to keep them.":"No connected display found.";
                root.preserveReadStatus = false;
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
                if (result.ok) {
                    if (task.action === "apply") {
                        root.awaitingKeep = !!result.pending;
                        root.secondsLeft = result.pending ? Number(result.seconds || 15) : 0;
                    } else if (task.action === "keep" || task.action === "revert") {
                        root.awaitingKeep = false;
                        root.secondsLeft = 0;
                    }
                } else if (task.action === "apply") {
                    root.awaitingKeep = false;
                    root.secondsLeft = 0;
                }
                if (task.action === "apply" || task.action === "revert" || !result.ok) {
                    root.preserveReadStatus = true;
                    readMonitors.running = true;
                }
            } catch(e) { root.failed=true;root.status="Display helper returned unreadable output: "+e; }
        } }
        onExited: (code,reason) => { if (code!==0 && !root.failed) { root.failed=true;root.status="Display command exited with "+code; } }
    }
    Component.onCompleted: readMonitors.running=true

    RowLayout {
        Layout.fillWidth:true; spacing:10
        ColumnLayout { Layout.fillWidth:true; spacing:3
            GlassLabel { text:"Your displays";font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(14);color:root.controlTheme.foreground }
            GlassLabel { text:root.drafts.length+" connected · live controls";font.pixelSize:Fonts.scale(10);color:root.controlTheme.muted }
        }
        Rectangle { Layout.preferredWidth:88;Layout.preferredHeight:32;radius:root.controlTheme.glassRadius("card", 9);color:root.controlTheme.glassColor("card", root.controlTheme.surface)
            GlassLabel { anchors.centerIn:parent;text:"Refresh";font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(10);color:root.controlTheme.foreground }
            MouseArea { anchors.fill:parent;enabled:!root.busy;cursorShape:Qt.PointingHandCursor;onClicked:readMonitors.running=true }
        }
    }
    Rectangle {
        id: preview
        objectName: "monitorPreview"
        visible: !root.framelessQuickControl || root.drafts.length > 0
        Layout.fillWidth:true;Layout.preferredHeight:220
        radius:root.controlTheme.glassRadius("card", 14);color:root.framelessQuickControl ? "transparent" : root.controlTheme.glassColor("card", Qt.alpha(root.controlTheme.foreground,.035))
        border.color:root.controlTheme.glassBorder("card", root.controlTheme.borderaccent);clip:true
        Repeater { model:root.drafts
            delegate: Rectangle {
                id:screenChip
                required property var modelData
                readonly property var display:modelData
                width:Math.max(56, Math.round(display.width/display.scale*root.previewScale))
                height:Math.max(36, Math.round(display.height/display.scale*root.previewScale))
                x:16+(display.x-root.minX)*root.previewScale
                y:16+(display.y-root.minY)*root.previewScale
                radius:root.controlTheme.glassRadius("card", 9)
                color:root.controlTheme.glassColor("card", root.selectedName===display.name?Qt.alpha(root.controlTheme.accent,.19):root.controlTheme.surface)
                border.color:root.controlTheme.glassBorder("card", root.selectedName===display.name?root.controlTheme.accent:root.controlTheme.borderaccent)
                border.width:root.controlTheme.glassBorderWidth("card", root.selectedName===display.name?2:1)
                Column { anchors.centerIn:parent;spacing:4
                    GlassLabel { anchors.horizontalCenter:parent.horizontalCenter;text:screenChip.display.name;color:root.controlTheme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
                    GlassLabel { anchors.horizontalCenter:parent.horizontalCenter;text:screenChip.display.width+" × "+screenChip.display.height;color:root.controlTheme.muted;font.pixelSize:Fonts.scale(9) }
                }
                MouseArea { anchors.fill:parent;cursorShape:Qt.OpenHandCursor
                    drag.target:root.busy ? null : screenChip
                    drag.minimumX:1;drag.minimumY:1
                    drag.maximumX:Math.max(1,preview.width-screenChip.width-1)
                    drag.maximumY:Math.max(1,preview.height-screenChip.height-1)
                    onPressed:root.selectedName=screenChip.display.name
                    onReleased: {
                        if (root.busy) return;
                        const nx=Math.round(root.minX+(screenChip.x-16)/root.previewScale);
                        const ny=Math.round(root.minY+(screenChip.y-16)/root.previewScale);
                        root.drafts=root.drafts.map(m=>m.name===screenChip.display.name?Object.assign({},m,{x:nx,y:ny}):m);
                        root.scheduleLive();
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
                Layout.fillWidth:true;Layout.preferredHeight:43;radius:root.controlTheme.glassRadius("card", 10)
                color:root.controlTheme.glassColor("card", active?Qt.alpha(root.controlTheme.accent,.17):root.controlTheme.surface)
                border.color:root.controlTheme.glassBorder("card", active?root.controlTheme.accent:root.controlTheme.borderaccent);border.width:root.controlTheme.glassBorderWidth("card", 1)
                RowLayout { anchors.centerIn:parent;spacing:7
                    Icon { icon:"\ue30b";color:monitorSelect.active?root.controlTheme.accent:root.controlTheme.muted;font.pixelSize:Fonts.scale(16) }
                    GlassLabel { text:monitorSelect.modelData.name;color:root.controlTheme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
                    Icon { visible:monitorSelect.active;icon:"\ue5ca";color:root.controlTheme.accent;font.pixelSize:Fonts.scale(15) }
                }
                MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:root.selectedName=monitorSelect.modelData.name }
            }
        }
    }
    Rectangle {
        visible:root.selected!==null
        Layout.fillWidth:true
        Layout.preferredHeight:details.implicitHeight+30
        radius:root.controlTheme.glassRadius("card", 13);color:root.framelessQuickControl ? "transparent" : root.controlTheme.glassColor("card", root.controlTheme.surface)
        ColumnLayout { id:details
            anchors.left:parent.left;anchors.right:parent.right;anchors.top:parent.top;anchors.margins:15;spacing:12
            RowLayout { Layout.fillWidth:true
                ColumnLayout { Layout.fillWidth:true;spacing:2
                    GlassLabel { text:root.selected?root.selected.name:"";font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(14);color:root.controlTheme.foreground }
                    GlassLabel { text:root.selected?(root.selected.description||"Connected output"):"";elide:Text.ElideRight;Layout.fillWidth:true;color:root.controlTheme.muted;font.pixelSize:Fonts.scale(10) }
                }
                GlassLabel { text:root.selected&&root.selected.focused?"Focused":"";color:root.controlTheme.accent;font.pixelSize:Fonts.scale(10) }
            }
            GlassLabel { text:"Resolution and refresh rate";font.family:Fonts.poppinsSB.name;color:root.controlTheme.foreground;font.pixelSize:Fonts.scale(11) }
            ComboBox { palette: ControlPalette {}

                id:modeBox
                Layout.fillWidth:true;Layout.preferredHeight:41
                model:root.selected?(root.selected.modes.length?root.selected.modes:[root.selected.mode]):[]
                currentIndex:root.selected?Math.max(0, model.findIndex(m=>String(m).replace("Hz","")===root.selected.mode)):0
                enabled: !root.busy
                onActivated: index => {if (index>=0 && index<model.length) root.chooseMode(model[index]);}
                contentItem:GlassLabel { text:modeBox.currentText;verticalAlignment:Text.AlignVCenter;leftPadding:13;rightPadding:26;color:root.controlTheme.foreground;font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(11);elide:Text.ElideRight }
                background:Rectangle { radius:root.controlTheme.glassRadius("card", 10);color:root.controlTheme.glassColor("card", root.controlTheme.background);border.color:root.controlTheme.glassBorder("card", modeBox.pressed?root.controlTheme.accent:root.controlTheme.borderaccent);border.width:root.controlTheme.glassBorderWidth("card", 1) }
                indicator:Icon { x:modeBox.width-width-10;y:(modeBox.height-height)/2;icon:"\ue5cf";color:root.controlTheme.accent;font.pixelSize:Fonts.scale(17) }
                delegate:ItemDelegate { width:modeBox.width;height:36
                    required property int index
                    required property var modelData
                    contentItem:GlassLabel { text:String(modelData);leftPadding:10;verticalAlignment:Text.AlignVCenter;color:root.controlTheme.foreground;font.pixelSize:Fonts.scale(10);elide:Text.ElideRight }
                    background:Rectangle { color:root.controlTheme.glassColor("card", highlighted?Qt.alpha(root.controlTheme.accent,.23):root.controlTheme.background);radius:root.controlTheme.glassRadius("card", 6) }
                }
                popup:Popup { y:modeBox.height+4;width:modeBox.width;implicitHeight:Math.min(contentItem.implicitHeight+8,238);padding:4
                    contentItem:ListView { clip:true;implicitHeight:contentHeight;model:modeBox.popup.visible?modeBox.delegateModel:null;currentIndex:modeBox.highlightedIndex;ScrollIndicator.vertical:ScrollIndicator{} }
                    background:Rectangle { radius:root.controlTheme.glassRadius("card", 10);color:root.controlTheme.glassColor("card", root.controlTheme.background);border.color:root.controlTheme.glassBorder("card", root.controlTheme.borderaccent);border.width:root.controlTheme.glassBorderWidth("card", 1) }
                }
            }
            GlassLabel { text:"Scale";color:root.controlTheme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
            RowLayout { Layout.fillWidth:true;spacing:6
                Repeater { model:[1,1.25,1.5,1.75,2]
                    delegate:Rectangle { id:scaleBtn
                        required property real modelData
                        readonly property bool chosen:root.selected!==null&&Math.abs(root.selected.scale-modelData)<.005
                        Layout.fillWidth:true;Layout.preferredHeight:34;radius:root.controlTheme.glassRadius("card", 8)
                        color:root.controlTheme.glassColor("card", chosen?Qt.alpha(root.controlTheme.accent,.17):root.controlTheme.background)
                        border.color:root.controlTheme.glassBorder("card", chosen?root.controlTheme.accent:root.controlTheme.borderaccent);border.width:root.controlTheme.glassBorderWidth("card", 1)
                        GlassLabel { anchors.centerIn:parent;text:scaleBtn.modelData+"×";color:root.controlTheme.foreground;font.pixelSize:Fonts.scale(10) }
                        MouseArea { anchors.fill:parent;enabled:!root.busy;cursorShape:Qt.PointingHandCursor;onClicked:if(root.selected)root.setField(root.selectedName,"scale",scaleBtn.modelData) }
                    }
                }
            }
            GlassLabel { text:"Place relative to another display";color:root.controlTheme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11) }
            RowLayout { Layout.fillWidth:true;spacing:6
                Repeater { model:[{title:"Left",id:"left"},{title:"Right",id:"right"},{title:"Above",id:"above"},{title:"Below",id:"below"}]
                    delegate:Rectangle { id:direction
                        required property var modelData
                        Layout.fillWidth:true;Layout.preferredHeight:34;radius:root.controlTheme.glassRadius("card", 8);color:root.controlTheme.glassColor("card", root.controlTheme.background)
                        GlassLabel { anchors.centerIn:parent;text:direction.modelData.title;color:root.controlTheme.foreground;font.pixelSize:Fonts.scale(10) }
                        MouseArea { anchors.fill:parent;enabled:root.drafts.length>1&&!root.busy;cursorShape:Qt.PointingHandCursor;onClicked:root.place(direction.modelData.id) }
                    }
                }
            }
            GlassLabel { text:root.selected?"Position "+root.selected.x+", "+root.selected.y+" px · "+root.selected.width+"×"+root.selected.height+" · "+root.selected.scale+"×":"";color:root.controlTheme.muted;font.pixelSize:Fonts.scale(10) }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.awaitingKeep ? 54 : 0
        visible: root.awaitingKeep
        radius: root.controlTheme.glassRadius("card", 11)
        color: root.controlTheme.glassColor("card", Qt.alpha(root.controlTheme.accent, 0.12))
        border.color: root.controlTheme.glassBorder("card", root.controlTheme.accent)
        RowLayout {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 9
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                GlassLabel { text: "New display layout is active"; font.family: Fonts.poppinsSB.name; color: root.controlTheme.foreground; font.pixelSize: Fonts.scale(11) }
                GlassLabel { text: "Reverts in " + root.secondsLeft + "s if not kept"; color: root.controlTheme.contentMuted; font.pixelSize: Fonts.scale(10) }
            }
            Rectangle {
                Layout.preferredWidth: 100; Layout.fillHeight: true; radius: root.controlTheme.glassRadius("card", 8); color: root.controlTheme.glassColor("card", root.controlTheme.surface)
                GlassLabel { anchors.centerIn: parent; text: "Revert now"; color: root.controlTheme.foreground; font.pixelSize: Fonts.scale(10) }
                MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.run("revert") }
            }
            Rectangle {
                Layout.preferredWidth: 120; Layout.fillHeight: true; radius: 8; color: root.controlTheme.accent
                GlassLabel { anchors.centerIn: parent; text: "Keep changes"; color: root.controlTheme.background; font.pixelSize: Fonts.scale(10); font.family: Fonts.poppinsSB.name }
                MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.run("keep") }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        GlassLabel {
            Layout.fillWidth: true
            text: root.busy ? "Applying…" : "Instant apply · verified against Hyprland"
            color: root.controlTheme.contentMuted
            font.pixelSize: Fonts.scale(10)
        }
        Rectangle {
            Layout.preferredWidth: 112; Layout.preferredHeight: 35; radius: root.controlTheme.glassRadius("card", 9); color: root.controlTheme.glassColor("card", root.controlTheme.surface)
            GlassLabel { anchors.centerIn: parent; text: "Export Lua"; color: root.controlTheme.foreground; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; enabled: !root.busy; cursorShape: Qt.PointingHandCursor; onClicked: root.run("export") }
        }
    }
    GlassLabel { Layout.fillWidth:true;text:root.status;color:root.failed?root.controlTheme.error:root.controlTheme.muted;wrapMode:Text.WordWrap;font.pixelSize:Fonts.scale(11) }
    GlassLabel { Layout.fillWidth:true;text:"Select a resolution, scale, position or drag a screen: changes apply immediately. Keep within 15 seconds; otherwise the independent rollback guard restores the previous layout. Export Lua for startup persistence (Omarchy files are not overwritten).";color:root.controlTheme.muted;wrapMode:Text.WordWrap;font.pixelSize:Fonts.scale(10) }
    Rectangle { Layout.fillWidth:true;Layout.preferredHeight:34;radius:root.controlTheme.glassRadius("card", 9);color:root.controlTheme.glassColor("card", root.controlTheme.surface)
        GlassLabel { anchors.centerIn:parent;text:"Open nwg-displays (alternative)";color:root.controlTheme.foreground;font.pixelSize:Fonts.scale(11) }
        MouseArea { anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:Quickshell.execDetached(["nwg-displays"]) }
    }
}
