import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell.Widgets
import "../config"

// Pure frontend. The same component renders gallery previews and live sessions.
Item {
    id: root
    required property var controller
    property string style: SettingsStore.launcherLayoutMode
    property bool interactive: true
    property real screenWidth: 1920
    property real screenHeight: 1080
    property point inputAnchor: Qt.point(0,150)
    readonly property bool legacy: style==="compact" || style==="clean-hover"
    readonly property bool detached: style==="detached"
    readonly property bool largeGrid: style==="launchpad" || style==="overview"
    readonly property bool stableSearch: detached || style==="spotlight" || style==="command"
    readonly property bool cleanHover: style==="clean-hover"
    property bool revealPreview: false
    readonly property bool queryEmpty: controller.query.trim().length===0
    readonly property bool showResults: !queryEmpty || !interactive || (detached ? SettingsStore.detachedLauncherShowEmptyResults
        : cleanHover ? revealPreview : style!=="spotlight" && style!=="command")
    readonly property real inputWidth: LauncherStyle.inputWidth(style,screenWidth)
    readonly property real resultWidth: detached && SettingsStore.detachedLauncherResultWidthMode==="custom"
        ? Math.min(screenWidth-32,SettingsStore.detachedLauncherResultsWidth) : inputWidth
    readonly property real resultRelativeX: !detached || SettingsStore.detachedLauncherResultAlignment==="left" ? 0
        : SettingsStore.detachedLauncherResultAlignment==="right" ? inputWidth-resultWidth : (inputWidth-resultWidth)/2
    readonly property real inputOriginX: -Math.min(0,resultRelativeX)
    readonly property real resultsOriginX: inputOriginX+resultRelativeX
    readonly property real requestedWidth: Math.max(inputWidth+inputOriginX,resultWidth+resultsOriginX)
    readonly property int inputHeight: LauncherStyle.searchHeight(style)
    readonly property int padding: SettingsStore.launcherPadding
    readonly property bool branding: !detached && (legacy || SettingsStore.launcherShowBranding)
    readonly property real brandBlock: branding ? 36+Theme.contentGap+padding : 0
    readonly property real searchTopInset: largeGrid ? padding : 0
    readonly property real inputBlockHeight: inputHeight+brandBlock+searchTopInset
    readonly property int gap: detached ? SettingsStore.detachedLauncherGap : showResults ? 4 : 0
    readonly property real belowSpace: Math.max(0,screenHeight-inputAnchor.y-inputBlockHeight-gap-10)
    readonly property real aboveSpace: Math.max(0,inputAnchor.y-gap-10)
    readonly property bool expandUp: stableSearch && (detached && SettingsStore.detachedLauncherExpansionDirection==="up"
        || (detached ? SettingsStore.detachedLauncherExpansionDirection==="auto" : true) && belowSpace<140 && aboveSpace>belowSpace)
    readonly property real availableResultsHeight: stableSearch ? (expandUp ? aboveSpace : belowSpace) : screenHeight-inputBlockHeight-64
    readonly property bool grid: !controller.toolsMode && !controller.calculatorMode && (largeGrid
        || style==="fluent" && !controller.catalogAll && queryEmpty && controller.category==="all"
        || detached && (SettingsStore.detachedLauncherResultMode==="grid" || SettingsStore.detachedLauncherResultMode==="adaptive" && SettingsStore.detachedLauncherAppLayout==="grid"))
    readonly property bool overviewFavorites: SettingsStore.launcherShowFavorites && controller.favorites.length>0
    readonly property bool overviewRecent: SettingsStore.launcherShowRecent && controller.recent.length>0
    readonly property real overviewSidebarWidth: style==="overview" && queryEmpty && (overviewFavorites || overviewRecent)
        ? Math.min(224,resultWidth*.22) : 0
    readonly property int columns: Math.max(1,Math.min(SettingsStore.launcherGridColumns,Math.floor((resultWidth-overviewSidebarWidth-padding*2)/(SettingsStore.launcherGridIconSize+36))))
    readonly property bool categoriesVisible: SettingsStore.launcherShowCategories && !controller.toolsMode && !controller.calculatorMode
        && ["raycast","launchpad","classic","overview","fluent"].indexOf(style)>=0
    readonly property int categoryHeight: categoriesVisible && style!=="classic" ? 36 : 0
    readonly property int headingHeight: SettingsStore.launcherShowCategories && !controller.calculatorMode && ["minimal","command"].indexOf(style)<0
        && (["spotlight","detached"].indexOf(style)<0 || !queryEmpty) ? 28 : 0
    readonly property int footerHeight: SettingsStore.launcherShowShortcutHints && ["raycast","classic","overview"].indexOf(style)>=0 ? 30 : 0
    readonly property int quickActionsHeight: style==="raycast" && queryEmpty ? 40+(SettingsStore.launcherShowRecent && controller.recentCommands.length ? 36 : 0) : 0
    readonly property real legacyFrequentHeight: style==="compact" && queryEmpty && SettingsStore.launcherShowFavorites && controller.frequent.length>0
        ? 26+Math.ceil(controller.frequent.length/SettingsStore.launcherFavoriteColumns)*(Math.max(42,SettingsStore.launcherIconSize+16)+4) : 0
    readonly property int recentHeight: style==="fluent" && queryEmpty && SettingsStore.launcherShowRecent && controller.recent.length ? 76 : 0
    readonly property int rowHeight: Math.max(SettingsStore.launcherRowHeight,SettingsStore.launcherShowIcons ? SettingsStore.launcherIconSize+16 : 28)
    readonly property int resultCellHeight: SettingsStore.launcherGridIconSize+44+SettingsStore.launcherResultSpacing
    readonly property real estimatedResultsHeight: controller.calculatorMode ? 92 : controller.rows.length===0 ? 76
        : grid ? Math.ceil(controller.rows.length/columns)*resultCellHeight : controller.rows.length*(rowHeight+SettingsStore.launcherResultSpacing)
    readonly property real chromeHeight: padding*2+categoryHeight+headingHeight+footerHeight+quickActionsHeight+recentHeight+legacyFrequentHeight
    readonly property real requestedResultsHeight: Math.max(0,Math.min(availableResultsHeight,
        LauncherStyle.maximumHeight(style,screenHeight)-inputBlockHeight-gap,
        largeGrid ? screenHeight-inputBlockHeight-100 : estimatedResultsHeight+chromeHeight))
    property real retainedHeight: 0
    property var retainedRows: []
    onRequestedResultsHeightChanged: if(showResults) retainedHeight=requestedResultsHeight
    onShowResultsChanged: {
        if(showResults) { retainedHeight=requestedResultsHeight;retainedRows=controller.rows; }
    }
    Connections {
        target:root.controller;ignoreUnknownSignals:true
        function onRowsChanged(){if(root.showResults)root.retainedRows=root.controller.rows;}
    }
    readonly property bool animate: interactive && Theme.motionEnabled && !SettingsStore.lowMemoryShellMode && SettingsStore.launcherAnimationStyle!=="none"
    // This is a buffer capacity, not another material or input region. A stable
    // native canvas prevents frame-by-frame Wayland configure/texture allocation.
    readonly property real motionCanvasHeight: !animate ? implicitHeight : Math.max(inputBlockHeight,
        Math.min(LauncherStyle.maximumHeight(style,screenHeight),screenHeight-16,
            stableSearch ? inputBlockHeight+(detached ? gap : 4)+availableResultsHeight : screenHeight-16))
    property real resultsHeight: resultsMotion.presented ? retainedHeight : 0
    Behavior on resultsHeight { enabled:root.animate;NumberAnimation {duration:Theme.motionFastDuration;easing.type:Easing.OutCubic} }
    readonly property real headerOriginY: expandUp && resultsMotion.presented ? resultsHeight+gap : 0
    readonly property real resultsOriginY: expandUp ? 0 : inputBlockHeight+gap
    implicitWidth: requestedWidth
    implicitHeight: inputBlockHeight+(resultsMotion.presented ? resultsHeight+gap : 0)
    readonly property var inputItem: inputBox
    readonly property var resultsItem: resultsSurface
    signal closeRequested()
    signal queryEdited()
    Keys.onEscapePressed:{if(context.visible)context.visible=false;else root.closeRequested();}
    function focusSearch(){if(interactive && visible)searchField.forceActiveFocus(Qt.OtherFocusReason);}
    function beginSession(){revealPreview=false;context.visible=false;focusSearch();focusLater.restart();}
    Timer {id:focusLater;interval:100;onTriggered:{
        const window=root.Window.window, current=window ? window.activeFocusItem : null;
        if(!current || current===searchField || current===window.contentItem || !current.activeFocusOnTab && current.cursorPosition===undefined) root.focusSearch();
    }}
    Timer {id:hoverClose;interval:650;onTriggered:if(root.queryEmpty && !allHover.hovered)root.revealPreview=false}
    HoverHandler {id:allHover;onHoveredChanged:{if(hovered)hoverClose.stop();else if(root.cleanHover)hoverClose.restart();}}
    Component.onCompleted:{retainedHeight=requestedResultsHeight;retainedRows=controller.rows;if(interactive){focusSearch();focusLater.start();}}

    Component {
        id:overviewEntry
        Rectangle {
            required property var modelData
            Layout.fillWidth:true;Layout.preferredHeight:48
            radius:Theme.rowRadius
            color:pointer.containsMouse || activeFocus ? Theme.glassHover : "transparent"
            border.width:activeFocus ? 1 : 0;border.color:Theme.accent
            activeFocusOnTab:root.interactive
            Accessible.role:Accessible.Button;Accessible.name:root.controller.textOf(modelData.name)
            function activate(){root.controller.launch(modelData);}
            Accessible.onPressAction:activate()
            Keys.onReturnPressed:activate()
            Keys.onSpacePressed:activate()
            RowLayout {
                anchors.fill:parent;anchors.margins:Theme.inlineGap;spacing:Theme.inlineGap
                LauncherAppIcon {Layout.preferredWidth:28;Layout.preferredHeight:28;source:root.controller.iconSource(modelData)
                    onUnavailable:source=>{if(typeof root.controller.markIconUnavailable==="function")root.controller.markIconUnavailable(source);}}
                GlassLabel {Layout.fillWidth:true;Layout.minimumWidth:0;text:root.controller.textOf(modelData.name);elide:Text.ElideRight
                    color:Theme.foreground;font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(11)}
            }
            MouseArea {id:pointer;anchors.fill:parent;enabled:root.interactive;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:parent.activate()}
        }
    }

    LauncherMaterial {
        id:mainMaterial;objectName:"launcherMainMaterial"
        visible:!root.detached;x:root.inputOriginX;width:root.inputWidth;height:root.height
    }
    Item {
        objectName:"launcherBrandHeader"
        x:root.inputOriginX+root.padding;y:root.headerOriginY+root.padding;width:root.inputWidth-root.padding*2;height:36
        visible:root.branding
        RowLayout {
            anchors.fill:parent;spacing:Theme.contentGap
            RusticQIcon {objectName:"launcherBrandIcon";iconSize:28;Layout.preferredWidth:28;Layout.preferredHeight:28;visible:SettingsStore.showRusticQIcon}
            ColumnLayout {Layout.fillWidth:true;Layout.minimumWidth:0;spacing:1
                GlassLabel {objectName:"launcherBrandTitle";Layout.fillWidth:true;text:root.legacy ? "App Launcher" : LauncherStyle.spec(root.style).name;elide:Text.ElideRight;color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(15)}
                GlassLabel {Layout.fillWidth:true;visible:root.legacy && !root.cleanHover;text:"Apps · =math · :files · :notes · :settings";elide:Text.ElideRight;color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
            }
            GlassLabel {visible:!root.cleanHover;text:root.controller.allApps.length+" apps";color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
        }
    }
    Item {
        id:inputBox;objectName:"launcherInputBox"
        x:root.inputOriginX;y:root.headerOriginY+root.brandBlock+root.searchTopInset
        width:root.inputWidth;height:root.inputHeight
        LauncherMaterial {id:inputMaterial;objectName:"detachedInputMaterial";anchors.fill:parent;part:"input";visible:root.detached}
        Rectangle {
            id:searchBackground;objectName:"launcherSearchSurface"
            visible:root.legacy || root.largeGrid
            x:root.largeGrid ? Math.max(root.padding,(parent.width-720)/2) : root.padding
            width:root.largeGrid ? Math.min(720,parent.width-root.padding*2) : parent.width-root.padding*2
            height:parent.height
            radius:Theme.glassRadius("control",Theme.rowRadius)
            color:Theme.glassColor("control",Theme.surface)
            border.width:searchField.activeFocus ? 1 : 0
            border.color:Theme.glassBorderColor
        }
        MouseArea {anchors.fill:parent;enabled:root.interactive;cursorShape:Qt.IBeamCursor;onClicked:{root.controller.keyboardNavigation=false;root.focusSearch();}}
        HoverHandler {onHoveredChanged:if(hovered && root.cleanHover)root.revealPreview=true}
        RowLayout {
            anchors.fill:parent
            anchors.leftMargin:searchBackground.visible ? searchBackground.x+Theme.controlPadding : root.padding
            anchors.rightMargin:anchors.leftMargin
            spacing:Theme.contentGap
            Icon {visible:!root.detached || SettingsStore.detachedLauncherShowIcon;icon:"\ue8b6";color:Theme.contentMuted;font.pixelSize:Fonts.scale(root.legacy ? 18 : 24)}
            TextInput {
                id:searchField;objectName:"launcherSearchInput"
                Layout.fillWidth:true;Layout.fillHeight:true
                enabled:root.interactive;activeFocusOnTab:true;selectByMouse:true;clip:true
                verticalAlignment:TextInput.AlignVCenter
                font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(LauncherStyle.searchFont(root.style))
                color:Theme.foreground;selectionColor:Theme.glassSelected;selectedTextColor:Theme.foreground
                text:root.controller.query
                TapHandler {onTapped:root.controller.keyboardNavigation=false}
                onTextEdited:{root.controller.query=text;root.queryEdited();}
                Accessible.name:"Search applications and commands"
                Keys.onEscapePressed: {if(context.visible)context.visible=false;else root.closeRequested();}
                Keys.onDownPressed:event=>{root.revealPreview=true;root.controller.moveSelection(root.grid ? root.columns : 1);event.accepted=true;}
                Keys.onUpPressed:event=>{root.controller.moveSelection(root.grid ? -root.columns : -1);event.accepted=true;}
                Keys.onLeftPressed:event=>{if(root.grid && root.controller.keyboardNavigation){root.controller.moveSelection(-1);event.accepted=true;}else event.accepted=false;}
                Keys.onRightPressed:event=>{if(root.grid && root.controller.keyboardNavigation){root.controller.moveSelection(1);event.accepted=true;}else event.accepted=false;}
                Keys.onReturnPressed:event=>{root.controller.launchSelected();event.accepted=true;}
                Keys.onEnterPressed:event=>{root.controller.launchSelected();event.accepted=true;}
                GlassLabel {
                    objectName:"launcherSearchPlaceholder"
                    anchors.verticalCenter:parent.verticalCenter;width:parent.width;visible:searchField.text.length===0
                    text:root.detached ? SettingsStore.detachedLauncherPlaceholder : root.legacy ? "Apps / =math / :files / :notes / :settings"
                        : root.style==="command" ? "Type an app, =math or :settings"
                        : root.largeGrid ? "Search your applications…" : "Search applications, files, notes…"
                    textFormat:Text.PlainText;elide:Text.ElideRight;color:Theme.contentMuted;font:searchField.font
                }
            }
            GlassLabel {visible:root.detached ? SettingsStore.detachedLauncherShowHint : SettingsStore.launcherShowShortcutHints && !root.legacy
                text:"esc";color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
        }
    }

    Item {
        id:resultsSurface;objectName:"launcherResultsBox"
        x:root.resultsOriginX;y:root.resultsOriginY;width:root.resultWidth;height:root.resultsHeight
        visible:resultsMotion.presented;clip:true
        transform:Translate {y:resultsMotion.offsetY}
        LauncherMaterial {id:resultsMaterial;objectName:"detachedResultsMaterial";anchors.fill:parent;part:"results";visible:root.detached}
        SurfaceMotion {id:resultsMotion;shown:root.showResults;target:resultsSurface;style:"float";edge:root.expandUp ? "bottom" : "top";closedScale:.995;travelDistance:6;animate:root.animate}
        ColumnLayout {
            anchors.fill:parent;anchors.margins:root.padding;spacing:0
            Flickable {
                visible:root.categoryHeight>0
                Layout.fillWidth:true;Layout.preferredHeight:root.categoryHeight
                contentWidth:categoryRow.implicitWidth;clip:true;flickableDirection:Flickable.HorizontalFlick
                Row {
                    id:categoryRow;spacing:6
                    Repeater {
                        model:root.controller.categories.filter(entry=>entry.key!=="favorites" || SettingsStore.launcherShowFavorites).filter(entry=>entry.key!=="recent" || SettingsStore.launcherShowRecent)
                        delegate:ActionButton {
                            required property var modelData
                            label:modelData.label;implicitHeight:28;selected:root.controller.category===modelData.key;enabled:root.interactive
                            onClicked:{root.controller.category=modelData.key;root.focusSearch();}
                        }
                    }
                }
            }
            RowLayout {
                visible:root.quickActionsHeight>0;Layout.fillWidth:true;Layout.preferredHeight:40;spacing:6
                Repeater {
                    model:[{label:"Files",prefix:":files "},{label:"Settings",prefix:":settings "},{label:"Notes",prefix:":notes "},{label:"Calculate",prefix:"="}]
                    delegate:ActionButton {required property var modelData;objectName:"launcherProviderAction_"+modelData.label.toLowerCase();label:modelData.label;enabled:root.interactive
                        onClicked:{root.controller.query=modelData.prefix;root.focusSearch();}}
                }
                Item {Layout.fillWidth:true}
            }
            RowLayout {
                visible:root.quickActionsHeight>40;Layout.fillWidth:true;Layout.preferredHeight:visible ? 36 : 0
                GlassLabel {text:"Recent actions";color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
                Repeater {model:root.controller.recentCommands.slice(0,3)
                    delegate:ActionButton {required property var modelData;label:modelData.label;implicitHeight:28;enabled:root.interactive
                        onClicked:root.controller.chooseTool(modelData)}
                }
                Item {Layout.fillWidth:true}
            }
            ColumnLayout {
                visible:root.legacyFrequentHeight>0;Layout.fillWidth:true;Layout.preferredHeight:root.legacyFrequentHeight;spacing:4
                GlassLabel {text:"Pinned & frequently used";color:Theme.contentMuted;font.pixelSize:Fonts.scale(11)}
                GridLayout {
                    columns:SettingsStore.launcherFavoriteColumns;Layout.fillWidth:true;columnSpacing:6;rowSpacing:4
                    Repeater {model:root.controller.frequent
                        delegate:Rectangle {
                            id:favorite;required property var modelData
                            Layout.fillWidth:true;Layout.preferredHeight:Math.max(42,SettingsStore.launcherIconSize+16)
                            radius:Theme.rowRadius;color:Theme.glassColor("card",Theme.surface)
                            RowLayout {anchors.fill:parent;anchors.margins:8;spacing:6
                                LauncherAppIcon {onUnavailable:source=>{if(typeof root.controller.markIconUnavailable==="function")root.controller.markIconUnavailable(source);}Layout.preferredWidth:SettingsStore.launcherIconSize;Layout.preferredHeight:SettingsStore.launcherIconSize;source:root.controller.iconSource(favorite.modelData)}
                                GlassLabel {Layout.fillWidth:true;text:root.controller.textOf(favorite.modelData.name);color:Theme.foreground;elide:Text.ElideRight;font.pixelSize:Fonts.scale(10)}
                            }
                            MouseArea {anchors.fill:parent;enabled:root.interactive;cursorShape:Qt.PointingHandCursor;onClicked:root.controller.launch(favorite.modelData)}
                        }
                    }
                }
            }
            RowLayout {
                visible:root.headingHeight>0;Layout.fillWidth:true;Layout.preferredHeight:root.headingHeight
                GlassLabel {Layout.fillWidth:true;text:root.controller.toolsMode ? ":"+root.controller.toolName : root.style==="fluent" && root.queryEmpty && !root.controller.catalogAll
                    ? (root.controller.favorites.length ? "Pinned applications" : "Applications") : root.controller.category==="recent" ? "Recently used" : root.queryEmpty ? "Applications" : "Search results"
                    color:Theme.contentMuted;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(11)}
                ActionButton {visible:root.style==="fluent" && root.queryEmpty;label:root.controller.catalogAll ? "Pinned view" : "All apps";implicitHeight:25;enabled:root.interactive
                    onClicked:{root.controller.catalogAll=!root.controller.catalogAll;root.focusSearch();}}
            }
            RowLayout {
                Layout.fillWidth:true;Layout.fillHeight:true;spacing:Theme.contentGap
                Flickable {
                    objectName:"launcherOverviewSidebar"
                    visible:root.overviewSidebarWidth>0
                    Layout.minimumWidth:root.overviewSidebarWidth;Layout.preferredWidth:root.overviewSidebarWidth;Layout.maximumWidth:root.overviewSidebarWidth
                    Layout.fillHeight:true;contentWidth:width;contentHeight:overviewShortcuts.implicitHeight
                    clip:true;boundsBehavior:Flickable.StopAtBounds
                    ColumnLayout {
                        id:overviewShortcuts;width:parent.width;spacing:Theme.inlineGap
                        GlassLabel {Layout.fillWidth:true;text:"Quick access";color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(15)}
                        GlassLabel {visible:root.overviewFavorites;Layout.fillWidth:true;text:"Favorites";color:Theme.contentMuted;font.pixelSize:Fonts.scale(11)}
                        Repeater {model:root.overviewFavorites ? root.controller.favorites.slice(0,6) : [];delegate:overviewEntry}
                        GlassLabel {visible:root.overviewRecent;Layout.fillWidth:true;Layout.topMargin:root.overviewFavorites ? Theme.inlineGap : 0;text:"Recently used";color:Theme.contentMuted;font.pixelSize:Fonts.scale(11)}
                        Repeater {model:root.overviewRecent ? root.controller.recent.slice(0,6) : [];delegate:overviewEntry}
                    }
                }
                Flickable {
                    visible:root.style==="classic" && root.categoriesVisible
                    Layout.preferredWidth:138;Layout.fillHeight:true;contentHeight:classicCategories.implicitHeight;clip:true
                    Column {
                        id:classicCategories;width:parent.width;spacing:4
                        Repeater {model:root.controller.categories
                            delegate:ActionButton {required property var modelData;width:classicCategories.width;label:modelData.label;implicitHeight:32
                                visible:(modelData.key!=="favorites" || SettingsStore.launcherShowFavorites) && (modelData.key!=="recent" || SettingsStore.launcherShowRecent)
                                selected:root.controller.category===modelData.key;enabled:root.interactive
                                onClicked:{root.controller.category=modelData.key;root.focusSearch();}}
                        }
                    }
                }
                Item {
                    objectName:"launcherResultsViewport"
                    Layout.minimumWidth:0
                    Layout.fillWidth:true;Layout.fillHeight:true
                    Loader {
                        id:resultLoader;anchors.fill:parent;active:!root.controller.calculatorMode && resultsMotion.presented && root.controller.rows.length>0
                        sourceComponent:LauncherResults {
                            controller:root.controller;rows:root.showResults ? root.controller.rows : root.retainedRows;grid:root.grid;columns:root.columns
                            interactive:root.interactive;sparse:!root.legacy
                            onFocusSearch:root.focusSearch()
                            onContextRequested:(entry,xPosition,yPosition)=>{
                                context.entry=entry;context.x=Math.min(root.width-context.width,resultsSurface.x+root.padding+xPosition);
                                context.y=Math.min(root.height-context.height,resultsSurface.y+root.padding+yPosition);context.visible=true;
                            }
                        }
                    }
                    Column {
                        visible:root.controller.calculatorMode;anchors.verticalCenter:parent.verticalCenter;width:parent.width;spacing:8
                        GlassLabel {width:parent.width;text:root.controller.calculatorResult.length ? "= "+root.controller.calculatorResult : root.controller.calculatorError || (root.controller.query.trim()==="=" ? "Enter an expression, e.g. =2*(3+4)" : "Calculating…")
                            wrapMode:Text.WordWrap;color:root.controller.calculatorError.length ? Theme.error : Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(22)}
                        ActionButton {label:"Copy result";visible:root.controller.calculatorResult.length>0;enabled:root.interactive;onClicked:{root.controller.copyResult();root.focusSearch();}}
                    }
                    GlassLabel {
                        visible:!root.controller.calculatorMode && root.controller.rows.length===0
                        anchors.centerIn:parent;width:parent.width;text:root.controller.toolMessage || (root.controller.searchBusy ? "Searching…" : root.queryEmpty ? "No applications in this section" : "No matching results")
                        textFormat:Text.PlainText;wrapMode:Text.WordWrap;horizontalAlignment:Text.AlignHCenter
                        color:root.controller.toolError ? Theme.error : Theme.contentMuted;font.family:Fonts.poppins.name;font.pixelSize:Fonts.scale(12)
                    }
                }
                Loader {
                    objectName:"launcherDetailPreview"
                    active:SettingsStore.launcherShowPreview && !root.controller.calculatorMode && root.controller.selected!==null && ["raycast","spotlight","classic"].indexOf(root.style)>=0
                    // An inactive Loader is still a visible layout participant.
                    // Hide it too, so RowLayout does not reserve its 12px gap.
                    visible:active
                    Layout.preferredWidth:active ? Math.min(200,root.resultWidth*.28) : 0;Layout.fillHeight:true
                    sourceComponent:Column {
                        spacing:12
                        LauncherAppIcon {onUnavailable:source=>{if(typeof root.controller.markIconUnavailable==="function")root.controller.markIconUnavailable(source);}width:64;height:64;visible:!root.controller.toolsMode;source:root.controller.toolsMode ? "" : root.controller.iconSource(root.controller.selected)}
                        GlassLabel {width:parent.width;text:root.controller.selected ? root.controller.toolsMode ? root.controller.selected.label : root.controller.textOf(root.controller.selected.name) : ""
                            wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Theme.foreground;font.family:Fonts.poppinsSB.name;font.pixelSize:Fonts.scale(15)}
                        GlassLabel {width:parent.width;text:root.controller.selected ? root.controller.toolsMode ? root.controller.selected.detail || "" : root.controller.textOf(root.controller.selected.comment || root.controller.selected.genericName) : ""
                            wrapMode:Text.WordWrap;textFormat:Text.PlainText;color:Theme.contentMuted;font.pixelSize:Fonts.scale(11)}
                    }
                }
            }
            RowLayout {
                visible:root.recentHeight>0;Layout.fillWidth:true;Layout.preferredHeight:root.recentHeight
                GlassLabel {text:"Recent";color:Theme.contentMuted;font.pixelSize:Fonts.scale(11)}
                Repeater {model:root.controller.recent.slice(0,3)
                    delegate:ActionButton {required property var modelData;Layout.fillWidth:true;label:root.controller.textOf(modelData.name);enabled:root.interactive
                        onClicked:root.controller.launch(modelData)}
                }
            }
            RowLayout {
                visible:root.footerHeight>0;Layout.fillWidth:true;Layout.preferredHeight:root.footerHeight
                GlassLabel {Layout.fillWidth:true;text:root.grid ? "↑↓ rows · ←→ columns" : "↑↓ select · Enter open";color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
                GlassLabel {text:"Esc close";color:Theme.contentMuted;font.pixelSize:Fonts.scale(10)}
            }
        }
    }
    Rectangle {
        id:context;visible:false;z:50;width:200;height:root.controller.toolsMode ? 52 : 100;radius:Theme.rowRadius;color:Theme.glassColor("popup",Theme.background)
        border.width:1;border.color:Theme.glassBorder("popup",Theme.borderaccent)
        property var entry:null
        Column {anchors.fill:parent;anchors.margins:8;spacing:5
            ActionButton {width:parent.width;label:"Open";onClicked:{context.visible=false;if(root.controller.toolsMode)root.controller.chooseTool(context.entry);else root.controller.launch(context.entry);}}
            ActionButton {width:parent.width;visible:!root.controller.toolsMode && SettingsStore.launcherShowFavorites
                label:root.controller.pinned(context.entry) ? "Unpin application" : "Pin application"
                onClicked:{root.controller.togglePinned(context.entry);context.visible=false;root.focusSearch();}}
        }
    }
}
