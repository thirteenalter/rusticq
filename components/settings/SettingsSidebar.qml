import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Basic

SettingsGlassSurface {
    id: root
    required property string applicationTitle
    property string version: ""
    property string applicationIcon: ""
    property var categories: []
    property string page: ""
    property string query: ""
    property bool collapsed: false
    property var results: []
    readonly property string hoveredKey: {
        if(!navigationHover.hovered || !enabled || !root.Window.window || !root.Window.window.active || !scroll.contentItem)return "";
        return navigationKeyAt(navigationHover.point.position,scroll.contentItem.contentY,
                               scroll.availableWidth,scroll.availableHeight,navigationColumn.implicitHeight);
    }
    function navigationKeyAt(point,contentOffset,viewportWidth,viewportHeight,contentHeight) {
        if(contentHeight<=0 || point.x<0 || point.y<0 || point.x>=viewportWidth || point.y>=viewportHeight)return "";
        const contentY=point.y+contentOffset;
        for(let index=0;index<navigationEntries.count;index++) {
            const row=navigationEntries.itemAt(index);
            if(!row)continue;
            const control=row.navigationControl;
            const left=row.x+control.x,top=row.y+control.y;
            if(control.visible && control.enabled && point.x>=left && point.x<left+control.width
                    && contentY>=top && contentY<top+control.height)return row.modelData.key;
        }
        return "";
    }
    signal navigate(string key,string option)
    material: "sidebar"
    clip: true
    ColumnLayout {
        anchors.fill: parent;anchors.margins: root.collapsed?10:16;spacing: 16
        RowLayout {
            Layout.fillWidth: true;Layout.topMargin: 10;spacing: 12
            Image { source: root.applicationIcon;sourceSize: Qt.size(48,48);Layout.preferredWidth: root.collapsed?34:44;Layout.preferredHeight: width;fillMode: Image.PreserveAspectFit }
            ColumnLayout {
                visible: !root.collapsed;Layout.fillWidth: true;spacing: 2
                SettingsLabel { design: root.design;text: root.applicationTitle;font.bold: true;font.pixelSize: 16;wrapMode: Text.WordWrap;Layout.fillWidth: true }
                SettingsLabel { design: root.design;text: root.version;color: design.muted;font.pixelSize: 11;Layout.fillWidth: true }
            }
        }
        SettingsSearchField {
            id: search;objectName:"settings-sidebar-search";design: root.design;visible: !root.collapsed;Layout.fillWidth: true
            text: root.query;onTextEdited: root.query=text
            Keys.onEscapePressed: root.query=""
        }
        ScrollView {
            id: scroll;objectName:"settings-sidebar-scroll";Layout.fillWidth: true;Layout.fillHeight: true;contentWidth: availableWidth;clip: true
            padding: 0
            // One passive handler owns the viewport. Per-delegate hover can
            // remain latched when scrolling moves a row without mouse motion.
            HoverHandler {id:navigationHover;enabled:root.enabled}
            ColumnLayout {
                id:navigationColumn
                width: scroll.availableWidth;spacing: 2
                Repeater {
                    id:navigationEntries
                    model: root.categories
                    delegate: ColumnLayout {
                        id: row;required property var modelData;required property int index
                        property alias navigationControl:navigationItem
                        Layout.fillWidth: true;spacing: 5
                        SettingsLabel {
                            visible: !root.collapsed && (row.index===0 || root.categories[row.index-1].group!==row.modelData.group)
                            Layout.topMargin: visible?12:0;Layout.bottomMargin: visible?3:0;Layout.leftMargin: 10
                            design: root.design;text: row.modelData.group || "Settings";color: design.muted;font.pixelSize: 11
                        }
                        ItemDelegate {
                            id:navigationItem
                            objectName:"settings-navigation-"+row.modelData.key
                            readonly property bool selected:root.page===row.modelData.key
                            readonly property bool pointerHovered:enabled && root.hoveredKey===row.modelData.key
                            function revealSelection() {
                                if(!selected)return;
                                const flick=scroll.contentItem;
                                if(flick.contentY===undefined)return;
                                const top=mapToItem(navigationColumn,0,0).y;
                                if(top<flick.contentY)flick.contentY=top;
                                else if(top+height>flick.contentY+flick.height)flick.contentY=top+height-flick.height;
                            }
                            onSelectedChanged:if(selected)Qt.callLater(revealSelection)
                            Component.onCompleted:if(selected)Qt.callLater(revealSelection)
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.maximumWidth: scroll.availableWidth
                            implicitHeight: Math.max(38,implicitContentHeight+topPadding+bottomPadding)
                            // Basic ItemDelegate has 12px padding on every side.
                            // A 27px icon cannot fit in the resulting 14px content
                            // area of a 38px row, and would spill into its neighbors.
                            padding: 0
                            leftPadding: root.collapsed?7:12
                            rightPadding: root.collapsed?7:12
                            topPadding: 5
                            bottomPadding: 5
                            clip: true
                            hoverEnabled: false
                            Accessible.name: row.modelData.label
                            onClicked: root.navigate(row.modelData.key,row.modelData.option || "")
                            background: Rectangle {
                                radius: 8
                                color: navigationItem.selected?root.design.selected:navigationItem.pointerHovered?root.design.hover:"transparent"
                                border.width: navigationItem.visualFocus?1:0
                                border.color: root.design.accent
                                Behavior on color {
                                    enabled: root.design.motionEnabled && (navigationItem.pointerHovered || navigationItem.selected)
                                    ColorAnimation {duration:root.design.duration}
                                }
                            }
                            contentItem: RowLayout {
                                spacing: 10
                                SettingsCategoryIcon { design: root.design;symbol: row.modelData.icon || row.modelData.symbol || "\ue8b8";categoryIndex: row.index }
                                SettingsLabel { visible: !root.collapsed;design: root.design;text: row.modelData.shortLabel || row.modelData.label;Layout.fillWidth: true;Layout.minimumWidth:0;font.pixelSize:root.design.controlTextSize;font.bold:navigationItem.selected }
                            }
                            ToolTip.visible: pointerHovered && root.collapsed;ToolTip.text: row.modelData.label
                        }
                    }
                }
            }
        }
    }
    function focusSearch() { search.forceActiveFocus(); }
}
