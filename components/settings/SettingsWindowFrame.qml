import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

SettingsGlassSurface {
    id: root
    material: "window"
    property var window
    property string applicationKey: "rusticq"
    readonly property var settingsDesign: design
    property string highlight: ""
    readonly property string settingsHighlight: highlight
    property string applicationTitle: "RusticQ Settings"
    property string applicationIcon: ""
    property string version: ""
    property string title: ""
    property string description: ""
    property string symbol: "\ue8b8"
    property string page: ""
    property string query: ""
    property var categories: []
    property var results: []
    property bool canBack: false
    property bool canForward: false
    property bool expandedSidebar: false
    property string status: ""
    property Component toolbar
    property Component footer
    property bool footerVisible: true
    property alias contentY: contentView.contentY
    property alias viewportHeight: contentView.height
    default property alias pageContents: pageColumn.data
    signal navigate(string page,string option)
    signal back()
    signal forward()
    onQueryChanged: if(sidebar.query!==query)sidebar.query=query
    onPageChanged: if(design && design.motionEnabled && pageTransition)pageTransition.restart()
    NumberAnimation {id:pageTransition;target:pageColumn;property:"opacity";from:0.88;to:1;duration:root.design.motionEnabled?190:0}
    function focusSearch() { expandedSidebar=true;Qt.callLater(sidebar.focusSearch); }
    RowLayout {
        anchors.fill: parent;spacing: 0
        SettingsSidebar {
            id: sidebar
            objectName: root.applicationKey==="hyprland"?"hypr-settings-sidebar":"rusticq-settings-sidebar"
            results: root.results
            Layout.preferredWidth: root.width<900 && !root.expandedSidebar?62:root.design.sidebarWidth
            Layout.fillHeight: true;design: root.design;applicationTitle: root.applicationTitle
            applicationIcon: root.applicationIcon;version: root.version;categories: root.categories;page: root.page
            collapsed: root.width<900 && !root.expandedSidebar
            query: root.query;onQueryChanged: if(query!==root.query)root.query=query
            onNavigate: (key,option)=>root.navigate(key,option)
        }
        Rectangle { Layout.fillHeight: true;implicitWidth: 1;color: root.design.line }
        ColumnLayout {
            Layout.fillHeight: true;Layout.fillWidth: true;spacing: 0
            SettingsTitleBar {
                Layout.fillWidth: true;design: root.design;window: root.window;title: root.title
                canBack: root.canBack;canForward: root.canForward;onBack:root.back();onForward:root.forward()
                SettingsButton { visible: root.width<900;design: root.design;text:"☰";Accessible.name:"Toggle sidebar";onClicked:root.expandedSidebar=!root.expandedSidebar }
                Loader { active: !!root.toolbar;visible: active;sourceComponent: root.toolbar }
            }
            Flickable {
                id: contentView
                objectName:"settings-content-scroll"
                visible: !root.query.trim();Layout.fillWidth: true;Layout.fillHeight: true;clip: true
                contentWidth: width;contentHeight: pageColumn.implicitHeight+48
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                ColumnLayout {
                    id: pageColumn;x:24;y:24;width: Math.max(0,contentView.width-48);spacing:20
                    SettingsPageHeader { design: root.design;title: root.title;description: root.description;symbol: root.symbol;Layout.fillWidth: true }
                }
            }
            ListView {
                visible: !!root.query.trim();Layout.fillWidth: true;Layout.fillHeight: true;clip: true
                model: root.results;spacing: 2;leftMargin:24;rightMargin:24;topMargin:12
                delegate: ItemDelegate {
                    required property var modelData;required property int index
                    width: ListView.view.width-48;height:62
                    Accessible.name: modelData.title || modelData.label
                    onClicked: root.navigate(modelData.tab || modelData.key,modelData.option || modelData.title || "")
                    background: Rectangle { radius:8;color:parent.hovered?root.design.hover:"transparent" }
                    contentItem: RowLayout {
                        spacing:12
                        SettingsCategoryIcon { design: root.design;symbol:modelData.icon || "\ue8b6";categoryIndex:index }
                        ColumnLayout {
                            Layout.fillWidth:true;spacing:2
                            SettingsLabel { design:root.design;text:modelData.title || modelData.label;Layout.fillWidth:true }
                            SettingsLabel { design:root.design;text:modelData.group || modelData.tab || modelData.hint || "";color:design.muted;font.pixelSize:11;Layout.fillWidth:true }
                        }
                    }
                }
            }
            Loader { Layout.fillWidth: true;active: !!root.footer && root.footerVisible;visible: active;sourceComponent: root.footer }
            SettingsLabel {
                visible: !!root.status;Layout.fillWidth:true;Layout.margins:12
                design:root.design;text:root.status;color:design.muted;font.pixelSize:11
            }
        }
    }
}
