import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../config"
import "../../components"
import "../quickcontrol"

PanelWindow {
    WlrLayershell.namespace: QuickControlStyle.panelBackground ? "rusticq-quick-control" : "rusticq-controls-transparent"
    id: sideWindow
    anchors.top: true
    anchors.right: true
    anchors.bottom: false
    exclusionMode: ExclusionMode.Ignore
    focusable: Store.sidebarVisible
    readonly property bool presented: motion.presented
    visible: presented
    SurfaceMotion { id: motion; shown: Store.sidebarVisible; target: sidebarSurface; edge: "right"; animate: QuickControlStyle.motion }

    margins.right: 10
    margins.top: 50

    color: "transparent"
    implicitWidth: QuickControlStyle.modular ? Math.min(SettingsStore.quickControlPanelWidth, screen ? Math.max(240,screen.width-20) : 560) : 400
    mask: QuickControlStyle.modular && !QuickControlStyle.panelBackground ? componentMask : null
    QuickControlInputMask {id:componentMask;windowItem:sideWindow.contentItem;revision:motion.progress}
    implicitHeight: QuickControlStyle.modular
        ? Math.max(120,Math.min(screen ? Math.max(120,screen.height-85) : 780,
            quickCards.preferredContentHeight+42+35+2*Theme.panelPadding+2*QuickControlStyle.gap))
        : Math.max(340,Math.min(screen ? Math.max(340,screen.height-85) : 690,
            Math.min(780,quickCards.preferredContentHeight+54+35+2*Theme.panelPadding+2*Theme.contentGap)))

    HyprlandFocusGrab {
        active: Store.sidebarVisible
        windows: [sideWindow]
        onCleared: Store.sidebarVisible = false
    }

    GlassSurface {
        Behavior on color { enabled: QuickControlStyle.motion; ColorAnimation { duration: Theme.motionFastDuration } }
        surfaceRole: "primary"
        reflectionsEnabled: QuickControlStyle.panelBackground && Theme.glassReflections
        shadowsEnabled: QuickControlStyle.panelBackground && Theme.glassShadows
        id: sidebarSurface
        objectName: "quickControlPanelSurface"
        anchors.fill: parent
        transform: Translate { x: motion.offsetX; y: motion.offsetY }
        color: QuickControlStyle.panelBackground ? Theme.glassColor("primary", Theme.background) : "transparent"
        radius: QuickControlStyle.modular ? SettingsStore.quickControlPanelRadius : Theme.glassRadius("primary", 20)
        border.width: QuickControlStyle.panelOutline ? Theme.glassBorderWidth("primary", 1) : 0
        border.color: Theme.glassBorder("primary", Theme.borderaccent)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.panelPadding
            spacing: QuickControlStyle.modular ? QuickControlStyle.gap : Theme.contentGap

            BarHeader {}
            QuickControlCards { id: quickCards }

            Rectangle {
                id:advancedNavigation
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: Store.advancedVisible ? "Back to Quick Control" : "Advanced controls"
                Accessible.onPressAction: Store.advancedVisible = !Store.advancedVisible
                Keys.onReturnPressed: Store.advancedVisible = !Store.advancedVisible
                Keys.onSpacePressed: Store.advancedVisible = !Store.advancedVisible
                QuickControlInputBridge {target:advancedNavigation;active:QuickControlStyle.modular}
                Layout.fillWidth: true
                Layout.preferredHeight: 35
                radius: QuickControlStyle.modular ? QuickControlStyle.radius : Theme.glassRadius("card", 12)
                color: QuickControlStyle.modular ? QuickControlStyle.surface(false,advancedPointer.containsMouse,advancedPointer.pressed) : Theme.glassColor("card", Theme.surface)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon {
                        icon: Store.advancedVisible ? "\ue5c4" : "\ue429"
                        font.pixelSize: Fonts.scale(16)
                        color: Theme.accent
                    }
                    GlassLabel {
                        text: Store.advancedVisible ? "Back to Quick Control" : "Advanced controls"
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(11)
                        color: Theme.foreground
                    }
                }
                MouseArea {
                    id: advancedPointer
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: Store.advancedVisible = !Store.advancedVisible
                }
            }
        }
    }
}
