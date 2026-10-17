import QtQuick
import QtQuick.Layouts
import "../config"
import "../services"

Pill {
    id: root
    property bool compact: false
    property bool backgroundEnabled: true
    property bool showDetails: true
    property string placement: "right"
    readonly property bool cleanStyle: compact && !backgroundEnabled
    readonly property bool micAvailable: QuickModesService.available("mic")
    readonly property bool showMic: SettingsStore.showMicrophoneStatus && SettingsStore.placementFor("mic") === placement && micAvailable
    readonly property bool showDown: SettingsStore.showDownloadSpeed && SettingsStore.placementFor("down") === placement
    readonly property bool showUp: SettingsStore.showUploadSpeed && SettingsStore.placementFor("up") === placement
    readonly property bool hasAny: showMic || showDown || showUp

    visible: hasAny
    color: backgroundEnabled ? Theme.borderaccent : "transparent"
    horizontalPadding: !backgroundEnabled ? 0 : compact ? 5 : 7
    verticalPadding: compact ? 3 : 6

    RowLayout {
        spacing: compact ? 8 : 10

        Item {
            visible: root.showMic
            implicitWidth: micRow.implicitWidth
            implicitHeight: micRow.implicitHeight
            RowLayout {
                id: micRow
                spacing: 5
                Icon {
                    icon: QuickModesService.active("mic") ? "\ue02b" : "\ue029"
                    font.pixelSize: compact ? 16 : 17
                    color: QuickModesService.active("mic") ? Theme.warning : Theme.foreground
                }
                Text {
                    visible: root.showDetails
                    text: QuickModesService.active("mic") ? "Mic off" : "Mic on"
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(10)
                }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: QuickModesService.toggle("mic")
            }
        }

        Item {
            visible: root.showDown
            implicitWidth: downRow.implicitWidth
            implicitHeight: downRow.implicitHeight
            RowLayout {
                id: downRow
                spacing: 5
                Icon { icon: "\ue5db"; font.pixelSize: compact ? 16 : 17; color: Theme.accent }
                Text {
                    visible: root.showDetails
                    text: SystemMetrics.speed(SystemMetrics.rxPerSec)
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(10)
                }
            }
        }

        Item {
            visible: root.showUp
            implicitWidth: upRow.implicitWidth
            implicitHeight: upRow.implicitHeight
            RowLayout {
                id: upRow
                spacing: 5
                Icon { icon: "\ue5d8"; font.pixelSize: compact ? 16 : 17; color: Theme.accent }
                Text {
                    visible: root.showDetails
                    text: SystemMetrics.speed(SystemMetrics.txPerSec)
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(10)
                }
            }
        }
    }
}
