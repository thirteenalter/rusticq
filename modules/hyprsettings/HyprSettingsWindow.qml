import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell
import "../../config"
import "../../components"
import "../../services"
import "components"
import "pages"
import "../../components/settings" as Suite

// A single lazy toplevel owned by shell.qml. Native compositor decorations
// provide move, resize, minimize and maximize without a second titlebar.
FloatingWindow {
    id: root
    title: "RusticQ Hyprland Settings"
    screen: Store.hyprSettingsScreen
    minimumSize: Qt.size(800,560)
    implicitWidth: Math.min(SettingsStore.hyprSettingsWidth, screen ? Math.max(800,screen.width - 48) : 1100)
    implicitHeight: Math.min(SettingsStore.hyprSettingsHeight, screen ? Math.max(560,screen.height - 72) : 760)
    color: "transparent"
    readonly property bool presented: motion.presented
    visible: presented
    SurfaceMotion { id: motion; shown: Store.hyprSettingsVisible; target: root.contentItem; closedScale: 0.995;animate:suiteDesign.motionEnabled }
    SettingsDesignTokens { id: suiteDesign;application:"hyprland" }
    property string query:""
    property var history:[]
    property int historyIndex:-1
    property int nextHistoryIndex:-1
    property string page: Store.hyprSettingsPage
    property string highlight: ""
    property string pendingPage: ""
    property string pendingOption: ""
    property bool closingApproved: false
    property bool expandedSidebar: false
    readonly property var category: HyprlandConfigService.state.categories.find(c => c.key === page)
    readonly property bool pageOperationBusy: pageLoader.item ? pageLoader.item.operationBusy : false
    readonly property bool localEditorDirty: pageLoader.item ? pageLoader.item.editorDirty : false
    Component.onCompleted: {history=[page];historyIndex=0;HyprlandConfigService.initialize();}
    onClosed: {
        if (pageOperationBusy) return;
        if ((HyprlandConfigService.dirty || localEditorDirty) && !closingApproved) { closeDialog.open(); return; }
        saveGeometry(); Store.hyprSettingsVisible = false;
    }
    function saveGeometry() {
        if (!maximized && !minimized) {
            SettingsStore.hyprSettingsWidth = Math.max(800, Math.min(2400, width));
            SettingsStore.hyprSettingsHeight = Math.max(560, Math.min(1800, height));
            SettingsStore.save();
        }
    }
    function navigate(key, option, index) {
        nextHistoryIndex=index===undefined?-1:index;
        if (pageOperationBusy) { HyprlandConfigService.message="Wait for the shortcut operation to finish before changing pages."; return; }
        if (key !== page && (HyprlandConfigService.dirty || localEditorDirty)) {
            pendingPage = key; pendingOption = option; leaveDialog.open(); return;
        }
        switchPage(key,option);
    }
    function switchPage(key,option) {
        if(nextHistoryIndex>=0)historyIndex=nextHistoryIndex;
        else if(history[historyIndex]!==key) {history=history.slice(0,historyIndex+1).concat([key]);historyIndex=history.length-1;}
        nextHistoryIndex=-1;query="";frame.query="";
        page = key; Store.hyprSettingsPage = key; highlight = option || "";
        highlightTimer.restart();
        frame.contentY = 0;
    }
    Timer { id: highlightTimer; interval: 2400; onTriggered: root.highlight = "" }
    Connections {
        target: Store
        function onHyprSettingsActivationChanged() {
            if (root.page !== Store.hyprSettingsPage) root.navigate(Store.hyprSettingsPage, "");
            root.minimized = false;
            const nativeWindow = root.contentItem.Window.window;
            if (nativeWindow) { nativeWindow.raise(); nativeWindow.requestActivate(); }
        }
    }
    Connections {
        target: root.contentItem.Window.window
        function onClosing(event) {
            if (root.pageOperationBusy) { event.accepted=false; HyprlandConfigService.message="Wait for the shortcut operation to finish before closing."; }
            else if ((HyprlandConfigService.dirty || root.localEditorDirty) && !root.closingApproved) { event.accepted = false; closeDialog.open(); }
        }
    }
    Shortcut { sequence: "Ctrl+F"; onActivated: { frame.focusSearch(); } }
    Shortcut {sequence:"Ctrl+K";onActivated:frame.focusSearch()}
    Shortcut {sequence:"Alt+Left";onActivated:if(historyIndex>0)root.navigate(history[historyIndex-1],"",historyIndex-1)}
    Shortcut {sequence:"Alt+Right";onActivated:if(historyIndex<history.length-1)root.navigate(history[historyIndex+1],"",historyIndex+1)}
    Shortcut { sequence: "Ctrl+R"; onActivated: if (!HyprlandConfigService.busy) HyprlandConfigService.refresh() }
    Shortcut { sequence: "Ctrl+Return"; onActivated: if (HyprlandConfigService.dirty && !HyprlandConfigService.busy) HyprlandConfigService.preview() }
    Shortcut { sequence: "Ctrl+W"; onActivated: { if (root.pageOperationBusy) return; if (HyprlandConfigService.dirty || root.localEditorDirty) closeDialog.open(); else { root.saveGeometry(); Store.hyprSettingsVisible=false; } } }
    readonly property var searchResults: {
        const q=query.trim().toLowerCase();
        return (HyprlandConfigService.state.categories || []).filter(c=>(c.label+" "+c.key+(c.key==="shortcuts"?" bind":c.key==="trackpad"?" touchpad":"")).toLowerCase().includes(q))
            .concat(HyprlandConfigService.state.options.filter(o=>(o.id+" "+o.label+" "+o.description).toLowerCase().includes(q)).map(o=>({key:o.page,label:o.label,group:o.id,option:o.id,icon:"\ue8b8"})));
    }
    Suite.SettingsWindowFrame {
        id:frame;objectName:"hypr-studio-layout";anchors.fill:parent;window:root;design:suiteDesign;applicationKey:"hyprland"
        applicationTitle:"RusticQ Hyprland";applicationIcon:Quickshell.shellPath("assets/rusticq-hypr-settings.svg");version:HyprlandConfigService.state.info.version || "Configuration Studio"
        title:root.category?root.category.label:"Overview";description:"Configure your Hyprland desktop";symbol:root.category?root.category.icon:"\ue8b8"
        categories:HyprlandConfigService.state.categories || [];page:root.page;results:root.searchResults
        query:root.query;onQueryChanged:if(query!==root.query)root.query=query
        canBack:root.historyIndex>0;canForward:root.historyIndex<root.history.length-1
        onBack:root.navigate(root.history[root.historyIndex-1],"",root.historyIndex-1)
        onForward:root.navigate(root.history[root.historyIndex+1],"",root.historyIndex+1)
        onNavigate:(key,option)=>root.navigate(key,option)
        toolbar:Component { HyprSettingsButton {palette:suiteDesign;text:"Refresh";enabled:!HyprlandConfigService.busy;onClicked:HyprlandConfigService.refresh()} }
        HyprSettingsLabel {
            visible:!!HyprlandConfigService.message || (!HyprlandConfigService.editable && HyprlandConfigService.initialized)
            Layout.fillWidth:true;palette:suiteDesign;wrapMode:Text.WordWrap;text:HyprlandConfigService.message || HyprlandConfigService.state.info.reason || "";color:HyprlandConfigService.failed?suiteDesign.error:suiteDesign.muted;font.pixelSize:12
        }
        Loader {
            id:pageLoader;Layout.fillWidth:true
            sourceComponent:HyprSettingsPage {palette:suiteDesign;page:root.page;highlightedOption:root.highlight;onOptionRequested:offset=>frame.contentY=Math.max(0,offset)}
        }
        footerVisible:HyprlandConfigService.dirty || HyprlandConfigService.externalChange || HyprlandConfigService.busy
        footer:Component { RowLayout {
            width:parent?parent.width:600;spacing:10
            HyprSettingsLabel {Layout.fillWidth:true;Layout.margins:16;palette:suiteDesign;text:HyprlandConfigService.externalChange?"Configuration changed externally":HyprlandConfigService.dirty?"● Unsaved changes":suiteDesign.capabilityText;color:suiteDesign.muted;font.pixelSize:11}
            HyprSettingsButton {palette:suiteDesign;text:"Revert";enabled:!HyprlandConfigService.busy && (HyprlandConfigService.dirty || HyprlandConfigService.externalChange);onClicked:HyprlandConfigService.discard()}
            HyprSettingsButton {Layout.rightMargin:16;Layout.topMargin:12;Layout.bottomMargin:12;palette:suiteDesign;primary:true;text:"Review changes…";enabled:HyprlandConfigService.editable && HyprlandConfigService.dirty && !HyprlandConfigService.busy && !HyprlandConfigService.externalChange;onClicked:HyprlandConfigService.preview()}
        } }
    }
    Connections { target: HyprlandConfigService; function onPreviewTokenChanged() { if (HyprlandConfigService.previewToken) reviewDialog.open(); } }
    Dialog {
        palette:Suite.SettingsControlPalette {design:suiteDesign}
        id: reviewDialog
        objectName: "hypr-review-dialog"
        parent: root.contentItem
        anchors.centerIn: parent
        width: Math.min(760,root.width-48)
        height: Math.min(580,root.height-48)
        title: "Review persistent configuration changes"
        modal: true
        closePolicy: Popup.CloseOnEscape
        background: Rectangle { color: suiteDesign.popover; radius: 12; border.width: 1; border.color: suiteDesign.line }
        contentItem: ColumnLayout {
            HyprSettingsLabel { palette: suiteDesign; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Apply creates a backup, writes only the shown files, then reloads and validates Hyprland. Failed changes are restored automatically."; font.pixelSize: 11 }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                TextArea { readOnly: true; selectByMouse: true; text: HyprlandConfigService.diff || "No persistent changes."; font.family: "Monospace"; font.pixelSize: 11; color: suiteDesign.foreground; wrapMode: TextEdit.WrapAnywhere; background: Rectangle { color: suiteDesign.group; radius: 8 } }
            }
            RowLayout {
                Item { Layout.fillWidth: true }
                HyprSettingsButton { palette: suiteDesign; text: "Cancel"; onClicked: reviewDialog.close() }
                HyprSettingsButton { palette: suiteDesign; text: "Apply"; primary: true; enabled: !!HyprlandConfigService.previewToken && !HyprlandConfigService.busy; onClicked: { reviewDialog.close(); HyprlandConfigService.apply(); } }
            }
        }
    }
    Dialog {
        palette:Suite.SettingsControlPalette {design:suiteDesign}
        id: leaveDialog
        parent: root.contentItem
        anchors.centerIn: parent
        width: Math.min(470,root.width-48)
        title: "Keep unsaved changes?"
        modal: true
        contentItem: ColumnLayout {
            Label { text: "Your draft can stay while you open another category." }
            RowLayout {
                HyprSettingsButton { palette: suiteDesign; text: "Stay"; onClicked: leaveDialog.close() }
                HyprSettingsButton { palette: suiteDesign; text: "Discard"; onClicked: { HyprlandConfigService.discard(); root.switchPage(root.pendingPage,root.pendingOption); leaveDialog.close(); } }
                HyprSettingsButton { palette: suiteDesign; text: "Keep draft"; primary: true; onClicked: { pageLoader.item.stageEditor(); root.switchPage(root.pendingPage,root.pendingOption); leaveDialog.close(); } }
            }
        }
    }
    Dialog {
        palette:Suite.SettingsControlPalette {design:suiteDesign}
        id: closeDialog
        objectName: "hypr-close-dialog"
        parent: root.contentItem
        anchors.centerIn: parent
        width: Math.min(470,root.width-48)
        title: "Close with unsaved changes?"
        modal: true
        contentItem: ColumnLayout {
            Label { text: "Keep the draft for next time, or return to review it." }
            RowLayout {
                HyprSettingsButton { palette: suiteDesign; text: "Keep editing"; onClicked: closeDialog.close() }
                HyprSettingsButton { palette: suiteDesign; text: "Close, keep draft"; onClicked: { pageLoader.item.stageEditor(); root.saveGeometry(); closeDialog.close(); root.closingApproved=true; Store.hyprSettingsVisible=false; } }
            }
        }
    }
}
