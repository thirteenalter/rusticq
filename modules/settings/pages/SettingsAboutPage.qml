import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
    id: root
    readonly property var settingsTheme: SettingsMaterial.forItem(root)
    width: parent ? parent.width : 680
    spacing: root.settingsTheme.sectionGap
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
                radius: root.settingsTheme.glassRadius("card", 22)
                color: root.settingsTheme.glassColor("card", Qt.alpha(root.settingsTheme.accent, 0.10))
                border.width: root.settingsTheme.glassBorderWidth("card", 1)
                border.color: root.settingsTheme.glassBorder("card", root.settingsTheme.borderaccent)
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
                GlassLabel {
                    text: "A modular desktop shell for Hyprland on Arch Linux."
                    wrapMode: Text.WordWrap
                    color: root.settingsTheme.foreground
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(12)
                    Layout.fillWidth: true
                }
                GlassLabel {
                    text: "Customize your bar, launcher, desktop widgets and system controls with Gruvbox or Follow Aether."
                    wrapMode: Text.WordWrap
                    color: root.settingsTheme.contentMuted
                    font.family: Fonts.poppins.name
                    font.pixelSize: Fonts.scale(12)
                    Layout.fillWidth: true
                }
            }
        }

        GlassLabel {
            Layout.fillWidth: true
            visible: ReleaseInfo.ready
            text: ReleaseInfo.current.summary || ""
            wrapMode: Text.WordWrap; color: root.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        GlassLabel {
            Layout.fillWidth: true
            visible: ReleaseInfo.ready
            text: "Channel: " + ReleaseInfo.channel + (ReleaseInfo.current.date ? " · Release date: " + ReleaseInfo.current.date : "")
            wrapMode: Text.WordWrap; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        GlassLabel {
            Layout.fillWidth: true
            visible: ReleaseInfo.loading
            text: "Loading release information…"
            color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        GlassLabel {
            Layout.fillWidth: true
            visible: ReleaseInfo.error.length > 0
            text: ReleaseInfo.error
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap; color: root.settingsTheme.error; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        Button { palette: ControlPalette { anchorItem:root }

            id: releaseRetry
            objectName: "releaseRetry"
            visible: ReleaseInfo.error.length > 0
            enabled: !ReleaseInfo.loading
            text: "Reload release information"
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(12)
            padding: 12
            contentItem: GlassLabel {
                text: releaseRetry.text
                font: releaseRetry.font
                color: root.settingsTheme.foreground
            }
            background: Rectangle {
                radius: root.settingsTheme.glassRadius("card", root.settingsTheme.rowRadius)
                color: root.settingsTheme.glassColor("card", releaseRetry.hovered ? Qt.alpha(root.settingsTheme.accent, 0.15) : root.settingsTheme.background)
                border.width: root.settingsTheme.glassBorderWidth("card", 1)
                border.color: root.settingsTheme.glassBorder("card", root.settingsTheme.borderaccent)
            }
            onClicked: ReleaseInfo.refresh()
        }
    }

    SettingsSection {
        visible: ReleaseInfo.ready
        heading: "Version history"
        description: "Browse release highlights and original notes for each documented version."
        symbol: "\ue889"

        ComboBox { palette: ControlPalette { anchorItem:root }

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
            contentItem: GlassLabel {
                text: releasePicker.displayText
                font: releasePicker.font
                color: root.settingsTheme.foreground
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            indicator: Icon {
                x: releasePicker.width - width - 12
                y: (releasePicker.height - height) / 2
                icon: "\ue5cf"
                color: root.settingsTheme.contentMuted
            }
            background: Rectangle {
                radius: root.settingsTheme.glassRadius("card", root.settingsTheme.rowRadius)
                color: root.settingsTheme.glassColor("card", root.settingsTheme.background)
                border.width: root.settingsTheme.glassBorderWidth("card", 1)
                border.color: root.settingsTheme.glassBorder("card", releasePicker.activeFocus ? root.settingsTheme.accent : root.settingsTheme.borderaccent)
            }
            delegate: ItemDelegate {
                id: releaseOption
                required property string modelData
                required property int index
                width: releasePicker.width - 8
                implicitHeight: 40
                highlighted: releasePicker.highlightedIndex === index
                contentItem: GlassLabel {
                    text: releaseOption.modelData
                    font: releasePicker.font
                    color: root.settingsTheme.foreground
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    radius: root.settingsTheme.glassRadius("card", root.settingsTheme.rowRadius)
                    color: root.settingsTheme.glassColor("card", releaseOption.highlighted || releaseOption.hovered ? Qt.alpha(root.settingsTheme.accent, 0.15) : root.settingsTheme.background)
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
                    radius: root.settingsTheme.glassRadius("card", root.settingsTheme.rowRadius)
                    color: root.settingsTheme.glassColor("card", root.settingsTheme.background)
                    border.width: root.settingsTheme.glassBorderWidth("card", 1)
                    border.color: root.settingsTheme.glassBorder("card", root.settingsTheme.borderaccent)
                }
            }
            onActivated: index => root.selectedTag = ReleaseInfo.releases[index].tag
        }
        GlassLabel {
            Layout.fillWidth: true
            text: root.selectedRelease.summary || ""
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap; color: root.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12)
        }
        GlassLabel {
            Layout.fillWidth: true
            text: "Quickshell " + (root.selectedRelease.minimumQuickshell || "—") + " or later · "
                + (root.selectedRelease.date || "Release date not recorded")
            wrapMode: Text.WordWrap; color: root.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
        Repeater {
            model: root.selectedRelease.changes || []
            delegate: GlassLabel {
                required property string modelData
                Layout.fillWidth: true
                text: "• " + modelData
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap; color: root.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
            }
        }
        Repeater {
            model: root.selectedRelease.notes || []
            delegate: GlassLabel {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                text: "<a href=\"" + Qt.resolvedUrl("../../../" + modelData) + "\">"
                    + (index === 0 ? "Release notes" : "Additional notes " + (index + 1)) + " ↗</a>"
                textFormat: Text.StyledText
                linkColor: root.settingsTheme.accent
                wrapMode: Text.WrapAnywhere
                font.family: Fonts.poppins.name
                font.pixelSize: Fonts.scale(12)
                onLinkActivated: link => Qt.openUrlExternally(link)
            }
        }
        GlassLabel {
            Layout.fillWidth: true
            visible: ReleaseInfo.warnings.length > 0
            text: ReleaseInfo.warnings.join("\n")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap; color: root.settingsTheme.warning; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
    }
}
