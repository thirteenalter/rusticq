import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../config"
import "../../../services"
import "../../../components/settings" as Suite

ColumnLayout {
    id:root
    required property var palette
    readonly property var state:HyprlandConfigService.state
    property bool showBuild:false
    spacing:20
    Suite.SettingsGroup {
        design:root.palette;title:"Hyprland session";contentSpacing:0
        Repeater {
            model:[
                ["Hyprland version",root.state.info.version || "Unavailable"],
                ["Session status",root.state.info.active?"Connected":"No reachable Hyprland session"],
                ["Configuration health",root.state.configErrors && ["ok","[]"].indexOf(root.state.configErrors)<0?root.state.configErrors:root.state.info.reason || "No reported errors"],
                ["Configuration format",root.state.info.format || "Detecting…"],
                ["Active configuration",root.state.info.path || "—"],
                ["Managed configuration",root.state.info.managedPath || "—"],
                ["Active displays",String((root.state.monitors || []).length)],
                ["Current workspace",(root.state.workspace || {}).name || "—"],
                ["Open windows",String((root.state.clients || []).length)]
            ]
            delegate:Suite.SettingsRow {
                required property var modelData
                design:root.palette;label:modelData[0]
                Suite.SettingsLabel {design:root.palette;text:modelData[1];Layout.maximumWidth:Math.max(180,root.width*0.6);wrapMode:Text.WrapAnywhere;font.pixelSize:12;color:design.muted}
            }
        }
        RowLayout {
            Suite.SettingsButton {design:root.palette;text:"Reload Configuration";enabled:HyprlandConfigService.editable && !HyprlandConfigService.busy;onClicked:HyprlandConfigService.reload()}
            Suite.SettingsButton {design:root.palette;text:"Open Folder";onClicked:Qt.openUrlExternally("file://"+root.state.info.path.substring(0,root.state.info.path.lastIndexOf("/")))}
            Suite.SettingsButton {design:root.palette;text:"Build Details";onClicked:root.showBuild=!root.showBuild}
            Suite.SettingsButton {design:root.palette;text:"Backup";enabled:HyprlandConfigService.editable && !HyprlandConfigService.busy;onClicked:HyprlandConfigService.snapshot()}
        }
        Suite.SettingsLabel {visible:root.showBuild;design:root.palette;text:JSON.stringify(root.state.info.build || {},null,2);font.family:"Monospace";font.pixelSize:12;wrapMode:Text.WrapAnywhere;Layout.fillWidth:true}
    }
    Suite.SettingsGroup {
        design:root.palette;title:"Configuration presets";description:"Stage supported appearance and performance options, then review the configuration diff."
        RowLayout {
            Layout.fillWidth:true
            Suite.SettingsDropdown {id:presets;design:root.palette;Layout.fillWidth:true;model:Object.keys(root.state.presets || {})}
            Suite.SettingsButton {design:root.palette;text:"Prepare preset";enabled:HyprlandConfigService.editable;onClicked:HyprlandConfigService.preset(presets.currentText)}
        }
        RowLayout {
            Layout.fillWidth:true
            Suite.SettingsTextField {id:presetName;design:root.palette;Layout.fillWidth:true;placeholderText:"Custom preset name"}
            Suite.SettingsButton {design:root.palette;text:"Save draft as preset";enabled:HyprlandConfigService.editable && !!presetName.text && !HyprlandConfigService.busy;onClicked:HyprlandConfigService.savePreset(presetName.text)}
        }
    }
    Suite.SettingsButton {design:root.palette;text:"Settings suite appearance…";onClicked:Store.showSettings("window-appearance",Store.hyprSettingsScreen)}
}
