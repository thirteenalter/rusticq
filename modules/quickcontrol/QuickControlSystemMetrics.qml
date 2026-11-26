import QtQuick
import QtQuick.Layouts
import "../../components"
import "../../config"
import "../../services"

ColumnLayout {
    id:root
    spacing:QuickControlStyle.gap
    QuickControlSection {title:"System";detail:"LIVE"}
    GridLayout {
        objectName:"quickMetricsGrid"
        Layout.fillWidth:true
        columns:root.width/SettingsStore.uiFontScale>=340 ? 4 : 2
        columnSpacing:QuickControlStyle.gap;rowSpacing:QuickControlStyle.gap
        Repeater {
            model:[
                {label:"CPU",symbol:"\ue30d",value:SysMonService.cpuUsage.toFixed(0)+"%",level:SysMonService.cpuUsage/100},
                {label:"RAM",symbol:"\ue322",value:SysMonService.memUsedGB.toFixed(1)+"G",level:SysMonService.memUsedPercent},
                {label:"Free disk",symbol:"\ue1db",value:SysMonService.diskAvailableGB.toFixed(0)+"G",level:1-SysMonService.diskUsedPercent},
                {label:"Temp",symbol:"\ue1ff",value:SysMonService.temperature<0 ? "N/A" : SysMonService.temperature.toFixed(0)+"°",level:SysMonService.temperature/100}
            ]
            QuickControlMetric {required property var modelData;Layout.fillWidth:true;Layout.preferredWidth:1;label:modelData.label;symbol:modelData.symbol;value:modelData.value;level:modelData.level}
        }
    }
}
