import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: root
    width: parent ? parent.width : 680
    spacing: Theme.sectionGap
    property string selectedTag: ""
    readonly property var selectedRelease: ReleaseInfo.releases.find(release => release.tag === (root.selectedTag || ReleaseInfo.tag)) || ReleaseInfo.current

    SettingsSection {
        heading: "RusticQ · " + ReleaseInfo.displayName
        description: ReleaseInfo.ready ? "Release " + ReleaseInfo.tag + " · Quickshell " + ReleaseInfo.requiredQuickshell + " or later" : "Local release information"
        symbol: "\ue88e"

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: 22
                color: Qt.alpha(Theme.accent, 0.10)
                border.width: 1
                border.color: Theme.borderaccent
                Image {
                    anchors.centerIn: parent
                    width: 58
                    height: 58
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    source: "../../../assets/rusticq-about-icon.png"
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Image {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    fillMode: Image.PreserveAspectFit
                    source: "../../../assets/rusticq-about-lockup.png"
                    smooth: true
                    mipmap: true
                }
                Text {
                    text: "A modular desktop shell for Hyprland on Arch Linux."
                    wrapMode: Text.WordWrap
                    color: Theme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(12)
                    Layout.fillWidth: true
                }
                Text {
                    text: "Customize your bar, launcher, desktop widgets and system controls with Gruvbox or Follow Aether."
                    wrapMode: Text.WordWrap
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(10)
                    Layout.fillWidth: true
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: ReleaseInfo.ready
            text: ReleaseInfo.current.summary || ""
            wrapMode: Text.WordWrap; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        Text {
            Layout.fillWidth: true
            visible: ReleaseInfo.ready
            text: "Channel: " + ReleaseInfo.channel + (ReleaseInfo.current.date ? " · Release date: " + ReleaseInfo.current.date : "")
            wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        Text {
            Layout.fillWidth: true
            visible: ReleaseInfo.loading
            text: "Loading release information…"
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        Text {
            Layout.fillWidth: true
            visible: ReleaseInfo.error.length > 0
            text: ReleaseInfo.error
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap; color: Theme.error; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
        }
        Button {
            id: releaseRetry
            objectName: "releaseRetry"
            visible: ReleaseInfo.error.length > 0
            enabled: !ReleaseInfo.loading
            text: "Reload release information"
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(11)
            padding: 12
            contentItem: Text {
                text: releaseRetry.text
                font: releaseRetry.font
                color: Theme.foreground
            }
            background: Rectangle {
                radius: Theme.rowRadius
                color: releaseRetry.hovered ? Qt.alpha(Theme.accent, 0.15) : Theme.background
                border.width: 1
                border.color: Theme.borderaccent
            }
            onClicked: ReleaseInfo.refresh()
        }
    }

    SettingsSection {
        visible: ReleaseInfo.ready
        heading: "Version history"
        description: "Browse release highlights and original notes for each documented version."
        symbol: "\ue889"

        ComboBox {
            id: releasePicker
            objectName: "releasePicker"
            Layout.fillWidth: true
            model: ReleaseInfo.releases.map(release => release.name + " · " + release.tag + (release.tag === ReleaseInfo.tag ? " · Current" : ""))
            currentIndex: ReleaseInfo.releases.findIndex(release => release.tag === root.selectedRelease.tag)
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(12)
            implicitHeight: 44
            leftPadding: 12
            rightPadding: 40
            contentItem: Text {
                text: releasePicker.displayText
                font: releasePicker.font
                color: Theme.foreground
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            indicator: Icon {
                x: releasePicker.width - width - 12
                y: (releasePicker.height - height) / 2
                icon: "\ue5cf"
                color: Theme.muted
            }
            background: Rectangle {
                radius: Theme.rowRadius
                color: Theme.background
                border.width: 1
                border.color: releasePicker.activeFocus ? Theme.accent : Theme.borderaccent
            }
            delegate: ItemDelegate {
                id: releaseOption
                required property string modelData
                required property int index
                width: releasePicker.width - 8
                implicitHeight: 40
                highlighted: releasePicker.highlightedIndex === index
                contentItem: Text {
                    text: releaseOption.modelData
                    font: releasePicker.font
                    color: Theme.foreground
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: Theme.rowRadius
                    color: releaseOption.highlighted || releaseOption.hovered ? Qt.alpha(Theme.accent, 0.15) : Theme.background
                }
            }
            popup: Popup {
                y: releasePicker.height + 4
                width: releasePicker.width
                padding: 4
                implicitHeight: Math.min(contentItem.implicitHeight + 8, 280)
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: releasePicker.popup.visible ? releasePicker.delegateModel : null
                    currentIndex: releasePicker.highlightedIndex
                    ScrollIndicator.vertical: ScrollIndicator {}
                }
                background: Rectangle {
                    radius: Theme.rowRadius
                    color: Theme.background
                    border.width: 1
                    border.color: Theme.borderaccent
                }
            }
            onActivated: index => root.selectedTag = ReleaseInfo.releases[index].tag
        }
        Text {
            Layout.fillWidth: true
            text: root.selectedRelease.summary || ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12)
        }
        Text {
            Layout.fillWidth: true
            text: "Quickshell " + (root.selectedRelease.minimumQuickshell || "—") + " or later · "
                + (root.selectedRelease.date || "Release date not recorded")
            wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
        Repeater {
            model: root.selectedRelease.changes || []
            delegate: Text {
                required property string modelData
                Layout.fillWidth: true
                text: "• " + modelData
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
            }
        }
        Repeater {
            model: root.selectedRelease.notes || []
            delegate: Text {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                text: "<a href=\"" + Qt.resolvedUrl("../../../" + modelData) + "\">"
                    + (index === 0 ? "Release notes" : "Additional notes " + (index + 1)) + " ↗</a>"
                textFormat: Text.StyledText
                linkColor: Theme.accent
                wrapMode: Text.WrapAnywhere
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(11)
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
        Text {
            Layout.fillWidth: true
            visible: ReleaseInfo.warnings.length > 0
            text: ReleaseInfo.warnings.join("\n")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap; color: Theme.warning; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }
}
