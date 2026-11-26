import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../../services"
import "../../components"

// Single-surface toast. No accent stripe, stacked borders, or fake buttons.
// Height comes from the laid-out content, not a fixed screen-space guess.
PanelWindow {
    WlrLayershell.namespace: "rusticq-notifications"
    id: toastWindow
    property var retainedNotice: null
    readonly property var notice: NotificationCenter.toast || retainedNotice
    SurfaceMotion {
        id: motion
        shown: SettingsStore.showNotifications && NotificationCenter.toast !== null
        target: toastSurface
        edge: "right"
        onPresentedChanged: if (!presented) toastWindow.retainedNotice = null
    }
    Connections {
        target: NotificationCenter
        function onToastChanged() {
            if (NotificationCenter.toast) {
                toastWindow.retainedNotice = NotificationCenter.toast;
                motion.replay();
            }
        }
    }
    Component.onCompleted: if (NotificationCenter.toast) retainedNotice = NotificationCenter.toast
    readonly property bool hasImage: notice !== null && String(notice.image || "").length > 0
    readonly property int actionCount: notice && notice.actions ? Math.min(2, notice.actions.length) : 0
    readonly property string appIconSource: {
        if (!notice || !notice.appIcon) return "";
        const iconName = String(notice.appIcon);
        if (iconName.indexOf("image://") === 0 || iconName.indexOf("file://") === 0 || iconName.indexOf("qrc:/") === 0)
            return iconName;
        if (iconName.charAt(0) === "/") return "file://" + iconName;
        return Quickshell.iconPath(iconName, true);
    }

    visible: motion.presented
    anchors { top: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    margins { top: 54; right: 16 }
    implicitWidth: hasImage ? 454 : 408
    implicitHeight: Math.max(116, bodyColumn.implicitHeight + Theme.panelPadding * 2)
    color: "transparent"

    GlassSurface {
        Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.motionFastDuration } }
        surfaceRole: "popup"
        id: toastSurface
        anchors.fill: parent
        transform: Translate { x: motion.offsetX; y: motion.offsetY }
        radius: Theme.surfaceRadius("notifications","popup", 19)
        color: Theme.surfaceColor("notifications","popup", Theme.background)
        border.width: Theme.surfaceBorderWidth("notifications","popup", 1)
        border.color: Theme.surfaceBorder("notifications","popup", Theme.borderaccent)
        clip: true

        ColumnLayout {
            id: bodyColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.panelPadding
            anchors.rightMargin: Theme.panelPadding
            anchors.topMargin: Theme.panelPadding
            spacing: Theme.contentGap

            RowLayout {
                Layout.fillWidth: true
                spacing: 9

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: Theme.glassRadius("card", 11)
                    color: Theme.glassColor("card", Qt.alpha(Theme.accent, 0.12))
                    Image {
                        id: realAppIcon
                        anchors.centerIn: parent
                        width: 23
                        height: 23
                        source: toastWindow.appIconSource
                        sourceSize.width: 46
                        sourceSize.height: 46
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !realAppIcon.visible
                        icon: notice ? notice.glyph : "\ue7f4"
                        font.pixelSize: Fonts.scale(19)
                        color: Theme.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    GlassLabel {
                        Layout.fillWidth: true
                        text: notice ? notice.app : ""
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(11)
                        color: Theme.foreground
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    GlassLabel {
                        Layout.fillWidth: true
                        text: notice ? notice.tag : ""
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(9)
                        color: Theme.contentMuted
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                GlassLabel {
                    text: notice ? notice.when : ""
                    color: Theme.contentMuted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(10)
                    textFormat: Text.PlainText
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: Theme.glassRadius("card", 9)
                    color: Theme.glassColor("card", dismissMouse.containsMouse ? Qt.alpha(Theme.foreground, 0.08) : "transparent")
                    Icon {
                        anchors.centerIn: parent
                        icon: "\ue5cd"
                        font.pixelSize: Fonts.scale(18)
                        color: Theme.foreground
                    }
                    MouseArea {
                        id: dismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationCenter.hideToast()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    GlassLabel {
                        Layout.fillWidth: true
                        text: notice ? notice.title : ""
                        color: Theme.foreground
                        font.family: Fonts.poppinsSB.name
                        font.pixelSize: Fonts.scale(14)
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    GlassLabel {
                        visible: text.length > 0
                        Layout.fillWidth: true
                        text: notice ? notice.body : ""
                        color: Theme.contentMuted
                        font.family: Fonts.poppins.name
                        font.pixelSize: Fonts.scale(11)
                        lineHeight: 1.2
                        maximumLineCount: 3
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                Rectangle {
                    visible: toastWindow.hasImage
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: visible ? 112 : 0
                    Layout.preferredHeight: visible ? 78 : 0
                    radius: Theme.glassRadius("card", 10)
                    color: Theme.glassColor("card", Theme.surface)
                    clip: true

                    Image {
                        id: screenshotThumbnail
                        anchors.fill: parent
                        source: toastWindow.hasImage ? notice.image : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 224
                        sourceSize.height: 156
                        asynchronous: true
                        visible: status === Image.Ready
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !screenshotThumbnail.visible
                        icon: "\ue3b0"
                        font.pixelSize: Fonts.scale(22)
                        color: Theme.accent
                    }
                }
            }

            RowLayout {
                visible: toastWindow.actionCount > 0
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 32 : 0
                spacing: 7
                Repeater {
                    model: toastWindow.actionCount
                    delegate: Rectangle {
                        id: nativeAction
                        required property int index
                        readonly property var action: toastWindow.notice && toastWindow.notice.actions
                            ? toastWindow.notice.actions[index] : null
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.glassRadius("card", 9)
                        color: Theme.glassColor("card", index === 0 ? Qt.alpha(Theme.accent, 0.15) : Theme.surface)
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            GlassLabel {
                                text: nativeAction.action ? nativeAction.action.text : ""
                                color: index === 0 ? Theme.accent : Theme.foreground
                                font.family: Fonts.poppinsSB.name
                                font.pixelSize: Fonts.scale(10)
                                maximumLineCount: 1
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                            Icon {
                                icon: "\ue5cc"
                                font.pixelSize: Fonts.scale(15)
                                color: index === 0 ? Theme.accent : Theme.foreground
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (toastWindow.notice)
                                    NotificationCenter.invokeAction(toastWindow.notice.serial, nativeAction.action.sourceIndex);
                            }
                        }
                    }
                }
            }
        }
    }
}
