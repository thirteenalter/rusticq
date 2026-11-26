import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../components"

// A bounded native window. Optional fullscreen backdrop has separate ownership;
// None creates neither fullscreen decoration nor a fullscreen input surface.
PanelWindow {
    id: overlay
    WlrLayershell.namespace: "rusticq-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors {top:true;left:true}
    color:"transparent"
    readonly property real monitorWidth: screen ? screen.width : 1920
    readonly property real monitorHeight: screen ? screen.height : 1080
    readonly property string backdropMode: LauncherStyle.backdrop(SettingsStore.launcherLayoutMode)
    readonly property bool backdropWantsBlur: backdropMode==="blur" || backdropMode==="dim-blur"
    readonly property point inputAnchor: LauncherStyle.anchor(SettingsStore.launcherLayoutMode,monitorWidth,monitorHeight,
        launcherSurface.inputWidth,launcherSurface.stableSearch ? launcherSurface.inputBlockHeight : launcherSurface.implicitHeight)
    implicitWidth: Math.ceil(launcherSurface.implicitWidth)
    implicitHeight: Math.ceil(Math.min(monitorHeight-16,launcherSurface.motionCanvasHeight))
    margins.left:Math.round(LauncherStyle.clamp(inputAnchor.x-launcherSurface.inputOriginX,8,monitorWidth-implicitWidth-8))
    readonly property point canvasAnchor: LauncherStyle.anchor(SettingsStore.launcherLayoutMode,monitorWidth,monitorHeight,
        launcherSurface.inputWidth,implicitHeight)
    margins.top:Math.round(LauncherStyle.clamp(launcherSurface.stableSearch
        ? inputAnchor.y-(launcherSurface.expandUp ? implicitHeight-launcherSurface.inputBlockHeight : 0)
        : canvasAnchor.y,8,monitorHeight-implicitHeight-8))
    readonly property bool presented:motion.presented
    visible:presented
    property bool keyboardPrimed:false
    property bool dismissalArmed:false
    property bool firstFrameReady:false
    WlrLayershell.keyboardFocus:Store.launcherVisible ? (keyboardPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    Timer {id:keyboardPrime;interval:75;onTriggered:if(Store.launcherVisible){overlay.keyboardPrimed=true;armDismissal.restart();}}
    Timer {id:armDismissal;interval:80;onTriggered:overlay.dismissalArmed=Store.launcherVisible && overlay.visible}
    onBackingWindowVisibleChanged:{
        if(backingWindowVisible && Store.launcherVisible)keyboardPrime.restart();
        if(!backingWindowVisible)firstFrameReady=false;
    }
    Connections {
        target:overlay.contentItem.Window.window
        enabled:Store.launcherVisible && !overlay.firstFrameReady
        function onFrameSwapped(){overlay.firstFrameReady=true;}
    }
    Connections {
        target:Store
        function onLauncherVisibleChanged(){
            overlay.dismissalArmed=false;armDismissal.stop();overlay.keyboardPrimed=false;
            if(Store.launcherVisible){keyboardPrime.restart();launcherSurface.focusSearch();}else keyboardPrime.stop();
        }
    }
    HyprlandFocusGrab {
        active:Store.launcherVisible && overlay.visible && overlay.dismissalArmed
        windows:[overlay]
        onCleared:if(overlay.dismissalArmed && Store.launcherVisible)Store.launcherVisible=false
    }
    mask:Region {
        item:Store.launcherVisible && SettingsStore.launcherLayoutMode!=="detached" ? launcherSurface : null
        Region {item:Store.launcherVisible && SettingsStore.launcherLayoutMode==="detached" ? launcherSurface.inputItem : null}
        Region {item:Store.launcherVisible && SettingsStore.launcherLayoutMode==="detached" && launcherSurface.resultsItem.visible ? launcherSurface.resultsItem : null}
    }
    SurfaceMotion {
        id:motion;shown:Store.launcherVisible;target:launcherSurface;style:LauncherStyle.animation()
        startReady:overlay.firstFrameReady
        edge:"top";closedScale:.97
        animate:Theme.motionEnabled && !SettingsStore.lowMemoryShellMode && SettingsStore.launcherAnimationStyle!=="none"
    }
    MiniLauncher {
        id:launcherSurface;objectName:"launcherStudio"
        width:implicitWidth
        height:implicitHeight
        y:overlay.inputAnchor.y-overlay.margins.top-(stableSearch ? headerOriginY : 0)
        screenWidth:overlay.monitorWidth;screenHeight:overlay.monitorHeight
        inputAnchor:overlay.inputAnchor
        transform:Translate {x:motion.offsetX;y:motion.offsetY}
        onLaunched:Store.launcherVisible=false
    }
    Loader {
        id:backdropLoader
        active:overlay.presented && overlay.backdropMode!=="none"
        sourceComponent:PanelWindow {
            WlrLayershell.namespace:"rusticq-launcher-backdrop"
            WlrLayershell.layer:WlrLayer.Top
            WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
            screen:overlay.screen
            anchors {top:true;bottom:true;left:true;right:true}
            exclusionMode:ExclusionMode.Ignore
            // The native blur carrier has 1/255 alpha, with no opaque tint.
            // Dim modes alone use the user's actual dim intensity.
            readonly property real dimAlpha: overlay.backdropMode==="focus" ? Math.min(.85,SettingsStore.launcherBackdropOpacity+.25)
                : overlay.backdropMode==="dim" || overlay.backdropMode==="dim-blur" ? SettingsStore.launcherBackdropOpacity
                : overlay.backdropWantsBlur && !Store.launcherBackdropBlurActive ? Math.max(.15,SettingsStore.launcherBackdropOpacity) : 0
            // Keep the 8-bit blur carrier stable from the first frame. Fading
            // 1/255 alpha quantized it to zero, then abruptly enabled blur.
            color:Qt.alpha(Theme.shadow,Math.max(dimAlpha*motion.progress,overlay.backdropWantsBlur && Store.launcherBackdropBlurActive ? 1/255 : 0))
            mask:Region {item:Store.launcherVisible ? dismissArea : null}
            MouseArea {id:dismissArea;anchors.fill:parent;enabled:Store.launcherVisible;acceptedButtons:Qt.AllButtons;onClicked:Store.launcherVisible=false}
        }
    }
}
