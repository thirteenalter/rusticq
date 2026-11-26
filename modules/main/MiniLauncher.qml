import QtQuick
import "../../config"
import "../../components"

// Stable public facade: one backend and one persistent search input across styles.
Item {
    id: root
    signal launched()
    property alias query: backend.query
    property alias results: backend.results
    property alias frequent: backend.frequent
    property alias selectedIndex: backend.selectedIndex
    property alias applicationEntries: backend.applicationEntries
    property alias revealPreview: frontend.revealPreview
    property alias screenWidth: frontend.screenWidth
    property alias screenHeight: frontend.screenHeight
    property alias inputAnchor: frontend.inputAnchor
    readonly property var controller: backend
    readonly property bool cleanHover: frontend.cleanHover
    readonly property bool showResults: frontend.showResults
    readonly property var displayedResults: backend.displayedResults
    readonly property bool toolsMode: backend.toolsMode
    readonly property bool calculatorMode: backend.calculatorMode
    readonly property real inputOriginX: frontend.inputOriginX
    readonly property real headerOriginY: frontend.headerOriginY
    readonly property real motionCanvasHeight: frontend.motionCanvasHeight
    readonly property bool expandUp: frontend.expandUp
    readonly property real inputBlockHeight: frontend.inputBlockHeight
    readonly property real inputWidth: frontend.inputWidth
    readonly property bool stableSearch: frontend.stableSearch
    readonly property real searchScreenOffset: frontend.brandBlock
    readonly property var inputItem: frontend.inputItem
    readonly property var resultsItem: frontend.resultsItem
    implicitWidth: frontend.implicitWidth
    implicitHeight: frontend.implicitHeight
    function rebuild(){backend.rebuild();}
    function textOf(value){return backend.textOf(value);}
    function iconSource(entry){return backend.iconSource(entry);}
    function searchScore(entry,text){return backend.searchScore(entry,text);}
    function moveSelection(delta){backend.moveSelection(delta);}
    function launchSelected(){backend.launchSelected();}
    function beginSession(){backend.beginSession();frontend.beginSession();}
    function focusSearch(){frontend.focusSearch();}
    LauncherController {
        id: backend
        presentation:SettingsStore.launcherLayoutMode
        resultLimit:SettingsStore.launcherLayoutMode==="detached" ? SettingsStore.detachedLauncherMaxResults
            : SettingsStore.launcherLayoutMode==="clean-hover" && query.trim()==="" ? 8 : 0
        onLaunched:root.launched()
    }
    LauncherView {
        id: frontend
        anchors.fill:parent
        controller:backend
        onCloseRequested:root.launched()
    }
    Connections {target:Store;function onLauncherVisibleChanged(){if(Store.launcherVisible)root.beginSession();}}
    Component.onCompleted:if(Store.launcherVisible)beginSession()
}
