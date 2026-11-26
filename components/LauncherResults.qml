import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../config"

// Model/view only. Providers and execution live in the single controller.
Item {
    id: root
    required property var controller
    property var rows: controller.rows
    property bool grid: false
    property bool interactive: true
    property bool sparse: true
    property int columns: Math.max(1,Math.min(SettingsStore.launcherGridColumns,Math.floor(width/(SettingsStore.launcherGridIconSize+36))))
    property int iconSize: grid ? SettingsStore.launcherGridIconSize : SettingsStore.launcherIconSize
    property int rowHeight: Math.max(SettingsStore.launcherRowHeight,SettingsStore.launcherShowIcons ? iconSize+16 : 28)
    readonly property int cellHeight: iconSize+44+SettingsStore.launcherResultSpacing
    readonly property real estimatedHeight: grid ? Math.ceil(rows.length/columns)*cellHeight
        : rows.length*(rowHeight+SettingsStore.launcherResultSpacing)
    signal focusSearch()
    signal contextRequested(var entry, real xPosition, real yPosition)
    function activate(entry,index) {
        if(!interactive) return;
        controller.selectedIndex=index;
        if(controller.toolsMode) controller.chooseTool(entry); else controller.launch(entry);
    }
    function keepSelectionVisible() {
        if (gridLoader.item) gridLoader.item.positionViewAtIndex(controller.selectedIndex,GridView.Contain);
        if (listLoader.item) listLoader.item.positionViewAtIndex(controller.selectedIndex,ListView.Contain);
    }
    Connections { target:root.controller;ignoreUnknownSignals:true;function onSelectionMoved(){root.keepSelectionVisible();} }
    Loader {
        id:gridLoader;anchors.fill:parent;active:root.grid
        sourceComponent: GridView {
            objectName:"launcherResultGrid"
            clip:true;model:root.rows
            cellWidth:width/root.columns;cellHeight:root.cellHeight
            currentIndex:root.controller.selectedIndex
            boundsBehavior:Flickable.StopAtBounds
            delegate: Item {
                id:tile;required property var modelData;required property int index
                width:GridView.view.cellWidth;height:GridView.view.cellHeight
                Rectangle {
                    x:4;y:2;width:parent.width-8;height:parent.height-6
                    radius:Theme.glassRadius("control",12)
                    color:tile.index===root.controller.selectedIndex ? Theme.glassSelected : hit.containsMouse ? Theme.glassHover : "transparent"
                    border.width:tile.index===root.controller.selectedIndex && root.controller.keyboardNavigation ? 1 : 0
                    border.color:Theme.accent
                }
                Column {
                    anchors.horizontalCenter:parent.horizontalCenter;y:8;width:parent.width-12;spacing:8
                    LauncherAppIcon {onUnavailable:source=>{if(typeof root.controller.markIconUnavailable==="function")root.controller.markIconUnavailable(source);}anchors.horizontalCenter:parent.horizontalCenter;width:root.iconSize;height:root.iconSize;source:root.controller.iconSource(tile.modelData)}
                    GlassLabel {width:parent.width;horizontalAlignment:Text.AlignHCenter;text:root.controller.textOf(tile.modelData.name);textFormat:Text.PlainText
                        color:Theme.foreground;font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(11);elide:Text.ElideRight}
                }
                MouseArea {
                    id:hit;anchors.fill:parent;enabled:root.interactive;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor
                    onPositionChanged: mouse=>{const point=mapToItem(null,mouse.x,mouse.y);root.controller.pointerSelection(tile.index,point.x,point.y);}
                    onClicked: mouse=>{if(mouse.button===Qt.RightButton)root.contextRequested(tile.modelData,tile.x+mouse.x,tile.y+mouse.y);else root.activate(tile.modelData,tile.index);}
                    Accessible.role:Accessible.Button;Accessible.name:root.controller.textOf(tile.modelData.name)
                }
            }
        }
    }
    Loader {
        id:listLoader;anchors.fill:parent;active:!root.grid
        sourceComponent: ListView {
            objectName:"launcherResultList"
            clip:true;model:root.rows;spacing:SettingsStore.launcherResultSpacing
            currentIndex:root.controller.selectedIndex
            boundsBehavior:Flickable.StopAtBounds
            delegate: Rectangle {
                id:row;required property var modelData;required property int index
                width:ListView.view.width;height:root.rowHeight
                radius:Theme.glassRadius("control",10)
                color:index===root.controller.selectedIndex ? Theme.glassSelected : hit.containsMouse ? Theme.glassHover : root.sparse ? "transparent" : Theme.glassCard
                border.width:index===root.controller.selectedIndex && root.controller.keyboardNavigation ? 1 : 0
                border.color:Theme.accent
                RowLayout {
                    anchors.fill:parent;anchors.leftMargin:Theme.controlPadding;anchors.rightMargin:Theme.controlPadding;spacing:Theme.inlineGap
                    Item {
                        visible:SettingsStore.launcherShowIcons
                        Layout.preferredWidth:root.iconSize;Layout.preferredHeight:root.iconSize
                        LauncherAppIcon {onUnavailable:source=>{if(typeof root.controller.markIconUnavailable==="function")root.controller.markIconUnavailable(source);}anchors.fill:parent;visible:!root.controller.toolsMode;source:root.controller.toolsMode ? "" : root.controller.iconSource(row.modelData)}
                        GlassLabel {anchors.centerIn:parent;visible:root.controller.toolsMode;text:row.modelData.icon || "›";color:Theme.accent;font.pixelSize:root.iconSize-4}
                    }
                    ColumnLayout {
                        Layout.fillWidth:true;spacing:1
                        GlassLabel {Layout.fillWidth:true;text:root.controller.toolsMode ? row.modelData.label : root.controller.textOf(row.modelData.name)
                            textFormat:Text.PlainText;elide:Text.ElideRight;color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(12)}
                        GlassLabel {Layout.fillWidth:true;visible:root.rowHeight>=44
                            text:root.controller.toolsMode ? row.modelData.detail || "" : root.controller.textOf(row.modelData.genericName || row.modelData.comment || row.modelData.id)
                            textFormat:Text.PlainText;elide:Text.ElideRight;color:Theme.contentMuted;font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(10)}
                    }
                    GlassLabel {visible:SettingsStore.launcherShowShortcutHints && row.index===root.controller.selectedIndex;text:"↵";color:Theme.contentMuted;font.pixelSize:Fonts.scale(14)}
                    Icon {visible:!root.controller.toolsMode && root.controller.pinned(row.modelData);icon:"\ue838";color:Theme.accent;font.pixelSize:Fonts.scale(15)}
                }
                MouseArea {
                    id:hit;anchors.fill:parent;enabled:root.interactive;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton;cursorShape:Qt.PointingHandCursor
                    onPositionChanged: mouse=>{const point=mapToItem(null,mouse.x,mouse.y);root.controller.pointerSelection(row.index,point.x,point.y);}
                    onClicked: mouse=>{if(mouse.button===Qt.RightButton)root.contextRequested(row.modelData,row.x+mouse.x,row.y+mouse.y);else root.activate(row.modelData,row.index);}
                    Accessible.role:Accessible.Button;Accessible.name:root.controller.toolsMode ? row.modelData.label : root.controller.textOf(row.modelData.name)
                }
            }
        }
    }
}
