import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../../config"
import "../../../services"
import "../../bar"
import "../../settings/pages"
import "../components"
import "../editors"
import "../previews"
import "../../../components/settings" as Suite

ColumnLayout {
    id: root
    required property var palette
    required property string page
    property string highlightedOption: ""
    spacing: 20
    readonly property var options: HyprlandConfigService.state.options.filter(o => o.page === page && (o.supported || SettingsStore.hyprSettingsShowUnsupported))
    readonly property string recordKind: ["keyboard","mouse","trackpad"].indexOf(page) >= 0 ? "devices" : page
    readonly property bool operationBusy: page === "shortcuts" && specialPage.item ? specialPage.item.busy === true : false
    readonly property bool editorDirty: recordLoader.item ? recordLoader.item.adding === true : false
    function stageEditor() { if (editorDirty) recordLoader.item.save(); }
    Loader {
        Layout.fillWidth: true
        visible: active
        active: ["appearance","effects","layouts"].indexOf(root.page) >= 0
        sourceComponent: HyprSettingsDesktopPreview { palette: root.palette; page: root.page }
    }
    Loader {
        id: specialPage
        Layout.fillWidth: true
        visible: active
        active: ["overview", "displays", "shortcuts", "plugins", "editor", "backups"].indexOf(root.page) >= 0
        sourceComponent: root.page === "overview" ? overview : root.page === "displays" ? displays : root.page === "shortcuts" ? shortcuts : root.page === "editor" ? files : root.page === "backups" ? backups : plugins
    }
    function groupFor(option) {
        if(page==="appearance") {
            if(option.id.includes("gaps"))return "Window Gaps";
            if(option.id.includes("border"))return "Window Borders";
            if(option.id.includes("opacity"))return "Window Transparency";
            if(option.id.includes("dim"))return "Focus Behavior";
            return "Window Decoration";
        }
        return option.id.includes(":blur:")?"Background Blur":option.id.includes(":shadow:")?"Window Shadow":"General";
    }
    readonly property var optionGroups:Array.from(new Set(options.map(o=>groupFor(o))))
    Repeater {
        model:root.optionGroups
        delegate:Suite.SettingsGroup {
            id:optionGroup
            required property string modelData
            property bool showAdvanced:root.page!=="effects"
            design:root.palette;title:modelData;contentSpacing:0
            Repeater {
                model:root.options.filter(o=>root.groupFor(o)===modelData)
                delegate:HyprSettingsOptionRow {
                    required property var modelData
                    palette:root.palette;option:modelData
                    visible:optionGroup.showAdvanced || !modelData.dependencies || highlighted
                    highlighted:root.highlightedOption===modelData.id
                    onHighlightedChanged:if(highlighted)Qt.callLater(function(){if(highlighted)root.optionRequested(parent.mapToItem(root,0,y).y);})
                }
            }
            Suite.SettingsButton {visible:root.page==="effects";design:root.palette;text:optionGroup.showAdvanced?"Hide advanced controls ⌃":"Advanced controls ⌄";onClicked:optionGroup.showAdvanced=!optionGroup.showAdvanced}
        }
    }
    Loader {
        id: recordLoader
        Layout.fillWidth: true
        visible: active
        active: Object.prototype.hasOwnProperty.call(HyprlandConfigService.state.collections, root.recordKind)
        sourceComponent: HyprSettingsRecordEditor { palette: root.palette; kind: root.recordKind }
    }
    Loader {
        Layout.fillWidth: true
        visible: active
        active: root.page === "gestures"
        sourceComponent: ColumnLayout {
            spacing: 8
            HyprSettingsLabel { palette: root.palette; text: "Gesture preview" }
            Rectangle {
                id: gestureArea
                Layout.fillWidth: true; implicitHeight: 100; radius: 12; color: root.palette.group; clip: true
                Rectangle {
                    id: gestureCursor
                    x: 24; y: 36; width: 64; height: 28; radius: 14; color: root.palette.accent
                    HyprSettingsLabel { anchors.centerIn: parent; palette: root.palette; text: "● ● ●"; color: "white" }
                    NumberAnimation { id: gesturePreview; target: gestureCursor; property: "x"; from: 24; to: gestureArea.width - 88; duration: root.palette.motionEnabled ? 650 : 0; easing.type: Easing.InOutCubic }
                }
                MouseArea { anchors.fill: parent; onClicked: gesturePreview.restart(); Accessible.name: "Preview three-finger workspace swipe" }
            }
        }
    }
    signal optionRequested(real offset)
    Component { id: overview; HyprSettingsOverview { palette: root.palette } }
    Component { id: displays; ColumnLayout {
        HyprSettingsLabel { palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Drag monitors or select a mode. Display changes use RusticQ's existing verified 15-second Keep/Revert workflow. Export the resulting snippet for persistent display configuration."; color: palette.muted; font.pixelSize: 12 }
        BarMonitors { Layout.fillWidth: true; framelessQuickControl: true; appearance: root.palette }
    } }
    // Preserve the existing shortcut controller, backup confirmation and restore
    // semantics instead of creating a competing bindings writer.
    Component { id: shortcuts; SettingsShortcutsPage { appearance: root.palette; confirmationScreen: Store.hyprSettingsScreen; confirmationWindowTitle: "RusticQ Hyprland Settings" } }
    Component { id: files; HyprSettingsFiles { palette: root.palette } }
    Component { id: backups; HyprSettingsBackups { palette: root.palette } }
    Component { id: plugins; ColumnLayout {
        HyprSettingsLabel { palette: root.palette; text: "Installed plugin status"; font.bold: true }
        HyprSettingsLabel { palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Plugin control and plugin-specific schemas depend on the plugin's own API. Unloading arbitrary plugins is not supported by this studio. No third-party plugin is downloaded or executed."; color: palette.muted; font.pixelSize: 12 }
        HyprSettingsLabel { palette: root.palette; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; text: JSON.stringify(HyprlandConfigService.state.plugins || [],null,2); font.family: "Monospace"; font.pixelSize: 12 }
    } }
}
