import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
                            id: appearancePage
                            property var installedFonts: []
                            property string fontSearch: ""
                            property string fontStatus: "Loading installed font families…"
                            Component.onCompleted: if (!fontListProcess.running) fontListProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "fonts"])
                            width: parent ? parent.width : 680
                            Layout.fillWidth: true
                            spacing: 12
                            Text { text: "Live theme preview"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                radius: 12
                                color: Qt.alpha(Theme.foreground, 0.045)
                                border.color: Theme.borderaccent
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 10
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: 10
                                        color: Theme.background
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12; anchors.rightMargin: 12
                                            Icon { icon: "\ue5ca"; font.pixelSize: Fonts.scale(17); color: Theme.accent }
                                            Text { text: "Workspaces"; color: Theme.foreground; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppins.name }
                                            Item { Layout.fillWidth: true }
                                            Icon { icon: "\ue63e"; font.pixelSize: Fonts.scale(18); color: Theme.accent }
                                            Text { text: "100%"; color: Theme.foreground; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppinsSB.name }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 65
                                            radius: 10
                                            color: Theme.surface
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 9
                                                Icon { icon: "\ue8b8"; font.pixelSize: Fonts.scale(22); color: Theme.accent }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text { text: "Quick Control"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                                                    Text { text: Theme.useAether ? "Aether live colors" : "Gruvbox accents"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 61
                                            Layout.preferredHeight: 65
                                            radius: 10
                                            color: Qt.alpha(Theme.accent, 0.20)
                                            Icon { anchors.centerIn: parent; icon: "\ue40a"; font.pixelSize: Fonts.scale(24); color: Theme.accent }
                                        }
                                    }
                                }
                            }
                            Text { text: "Color source"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Text {
                                Layout.fillWidth: true
                                text: "Choose independent Gruvbox or follow Aether's last applied wallpaper palette."
                                color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: [
                                    { key: "gruvbox", title: "Independent Gruvbox", info: "Fixed Gruvbox Dark; select an accent below" },
                                    { key: "aether", title: "Follow Aether", info: "Watch ~/.config/aether/theme/colors.toml" }
                                ]
                                delegate: Rectangle {
                                    id: sourceRow
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 56
                                    radius: 11
                                    color: SettingsStore.colorSource === modelData.key ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                                    border.width: SettingsStore.colorSource === modelData.key ? 1 : 0
                                    border.color: Theme.accent
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 10
                                        Icon { icon: sourceRow.modelData.key === "aether" ? "\ue40a" : "\ue8b8"; font.pixelSize: Fonts.scale(21); color: Theme.accent }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text { text: sourceRow.modelData.title; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                                            Text { text: sourceRow.modelData.info; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                                        }
                                        Icon { visible: SettingsStore.colorSource === sourceRow.modelData.key; icon: "\ue5ca"; font.pixelSize: Fonts.scale(17); color: Theme.accent }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { SettingsStore.colorSource = sourceRow.modelData.key; SettingsStore.save(); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: SettingsStore.colorSource === "aether"
                                text: Theme.aetherAvailable ? "Aether palette detected · Live sync enabled" : "Aether palette not detected · Using Gruvbox fallback until Aether applies a theme"
                                color: Theme.aetherAvailable ? Theme.success : Theme.warning
                                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                                wrapMode: Text.WordWrap
                            }
                            Text { text: "Gruvbox accent color"; visible: SettingsStore.colorSource === "gruvbox"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Repeater {
                                model: [
                                    {name: "orange", label: "Gruvbox Orange", hex: "#d65d0e"},
                                    {name: "green", label: "Gruvbox Green", hex: "#b8bb26"},
                                    {name: "blue", label: "Gruvbox Aqua", hex: "#83a598"},
                                    {name: "purple", label: "Gruvbox Purple", hex: "#d3869b"}
                                ]
                                delegate: Rectangle {
                                    id: accentRow
                                    visible: SettingsStore.colorSource === "gruvbox"
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 11
                                    color: SettingsStore.accentName === accentRow.modelData.name ? Qt.alpha(Theme.accent, 0.13) : Theme.surface
                                    border.width: SettingsStore.accentName === accentRow.modelData.name ? 1 : 0
                                    border.color: Theme.accent
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle { Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7; color: accentRow.modelData.hex }
                                        Text {
                                            Layout.fillWidth: true
                                            text: accentRow.modelData.label
                                            color: Theme.foreground
                                            font.family: Fonts.poppins.name
                                            font.pixelSize: Fonts.scale(12)
                                        }
                                        Icon {
                                            icon: "\ue5ca"
                                            font.pixelSize: Fonts.scale(18)
                                            color: Theme.accent
                                            visible: SettingsStore.accentName === accentRow.modelData.name
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { SettingsStore.accentName = accentRow.modelData.name; SettingsStore.save(); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: SettingsStore.colorSource === "aether" ? "Aether source: " + Theme.aetherPath : "Base palette #282828 / #3c3836 / #ebdbb2 · Poppins and Material Symbols"
                                wrapMode: Text.WordWrap
                                color: Theme.muted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(10)
                            }

    SettingsSection {
        heading: "Typography"
        description: "Live font family and text-size controls inspired by end-4's configurable desktop style. Installed system fonts are used when available."
        symbol: "\ue262"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [{key:"poppins", label:"Poppins"}, {key:"sans",label:"System Sans"}, {key:"mono", label:"Monospace"}]
                delegate: Rectangle {
                    id: fontOption
                    required property var modelData
                    readonly property bool chosen: SettingsStore.uiFontFamily === modelData.key
                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10
                    color: chosen ? Qt.alpha(Theme.accent, 0.15) : Theme.background
                    border.color: Theme.accent; border.width: chosen ? 1 : 0
                    Text { anchors.centerIn: parent; text: fontOption.modelData.label; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); color: Theme.foreground }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.uiFontFamily = fontOption.modelData.key; SettingsStore.save(); } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text:"Text scale"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: Theme.foreground }
            Text { text:Math.round(SettingsStore.uiFontScale * 100) + "%"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
        }
        SettingRangeSlider {
            Layout.fillWidth: true
            minimum: 85; maximum: 120; step: 5
            value: Math.round(SettingsStore.uiFontScale * 100)
            onPreview: next => SettingsStore.uiFontScale = next / 100
            onCommit: next => { SettingsStore.uiFontScale = next / 100; SettingsStore.save(); }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [{key:"comfortable",label:"Comfortable"},{key:"compact",label:"Compact"}]
                delegate: Rectangle {
                    id: densityOption
                    required property var modelData
                    readonly property bool chosen: SettingsStore.uiDensity === modelData.key
                    Layout.fillWidth: true; Layout.preferredHeight: 41; radius: 10
                    color: chosen ? Qt.alpha(Theme.accent, 0.15) : Theme.background
                    border.color: Theme.accent; border.width: chosen ? 1 : 0
                    Text { anchors.centerIn: parent; text: densityOption.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.uiDensity = densityOption.modelData.key; SettingsStore.save(); } }
                }
            }
        }
    }

    SettingsSection {
        heading: "Installed fonts & import"
        description: "Browse fonts installed via fontconfig. Add your own TTF/OTF fonts to your user directory without altering system packages."
        symbol: "\ue262"
        Process {
            id: fontListProcess
            stdout: StdioCollector { onStreamFinished: {
                try { const answer = JSON.parse(this.text.trim());
                    appearancePage.installedFonts = answer.families || [];
                    appearancePage.fontStatus = answer.ok ? answer.families.length + " families available" : answer.message;
                } catch(e) { appearancePage.fontStatus = "Cannot parse font list: " + e; }
            } }
        }
        Process {
            id: fontFilePicker
            stdout: StdioCollector { onStreamFinished: {
                try { const answer = JSON.parse(this.text.trim());
                    if (answer.ok && answer.path) fontInstaller.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "install-font", answer.path]);
                    else if (!answer.cancelled) appearancePage.fontStatus = answer.message;
                } catch(e) { appearancePage.fontStatus = "Font picker failed: " + e; }
            } }
        }
        Process {
            id: fontInstaller
            stdout: StdioCollector { onStreamFinished: {
                try { const answer = JSON.parse(this.text.trim());
                    appearancePage.fontStatus = answer.message;
                    if (answer.ok) {
                        if (answer.family) { SettingsStore.uiFontFamily = "custom"; SettingsStore.uiCustomFont = answer.family; SettingsStore.save(); }
                        refreshFonts.restart();
                    }
                } catch(e) { appearancePage.fontStatus = "Font install failed: " + e; }
            } }
        }
        Timer { id: refreshFonts; interval: 750; onTriggered: if (!fontListProcess.running) fontListProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "fonts"]) }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Text { Layout.fillWidth: true; text: "Selected: " + (SettingsStore.uiFontFamily === "custom" ? SettingsStore.uiCustomFont : SettingsStore.uiFontFamily); color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11); elide: Text.ElideRight }
            Repeater {
                model: [{label:"Refresh", action:"refresh"}, {label:"Add font…", action:"install"}]
                delegate: Rectangle { id: fontAction; required property var modelData
                    Layout.preferredWidth: fontAction.modelData.action === "install" ? 94 : 76
                    Layout.preferredHeight: 32; radius: 9; color: Theme.surface
                    Text { anchors.centerIn: parent; text: fontAction.modelData.label; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                        if (fontAction.modelData.action === "refresh" && !fontListProcess.running) fontListProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "fonts"]);
                        if (fontAction.modelData.action === "install" && !fontFilePicker.running) fontFilePicker.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "pick-font"]);
                    } }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 9; color: Theme.background
            TextInput { id: installedFontFilter; anchors.fill: parent; anchors.margins: 8; verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                onTextChanged: appearancePage.fontSearch = text.trim().toLowerCase()
            }
            Text { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; visible: !installedFontFilter.text.length; text: "Search installed font families…"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        }
        ListView { id: fontList; Layout.fillWidth: true; Layout.preferredHeight: 184; clip: true; spacing: 4
            model: appearancePage.installedFonts.filter(name => String(name).toLowerCase().indexOf(appearancePage.fontSearch) !== -1).slice(0, 150)
            delegate: Rectangle { id: fontEntry; required property string modelData
                width: fontList.width; height: 32; radius: 8
                color: SettingsStore.uiFontFamily === "custom" && SettingsStore.uiCustomFont === modelData ? Qt.alpha(Theme.accent,0.14) : Theme.surface
                Text { anchors.fill: parent; anchors.leftMargin: 10; verticalAlignment: Text.AlignVCenter; text: fontEntry.modelData; elide: Text.ElideRight; color: Theme.foreground; font.family: fontEntry.modelData; font.pixelSize: Fonts.scale(11) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.uiCustomFont = fontEntry.modelData; SettingsStore.uiFontFamily = "custom"; SettingsStore.save(); } }
            }
        }
        Text { Layout.fillWidth: true; text: appearancePage.fontStatus; wrapMode: Text.WordWrap; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
    }

    SettingsSection {
        heading: "Wallpaper"
        description: "Apply an image without modifying Aether's theme files. Auto-detects swww, awww, or hyprpaper when running; requires an existing wallpaper daemon."
        symbol: "\ue3f4"
        property string applyStatus: ""
        property bool applySuccess: false
        Process {
            id: wallpaperProcess
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const outcome = JSON.parse(this.text.trim());
                        wallpaperFeedback.text = outcome.message;
                        wallpaperFeedback.color = outcome.ok ? Theme.success : Theme.error;
                    } catch(e) { wallpaperFeedback.text = "Wallpaper command did not return a valid result."; wallpaperFeedback.color = Theme.error; }
                }
            }
        }
        Process {
            id: wallpaperPicker
            stdout: StdioCollector { onStreamFinished: {
                try { const answer = JSON.parse(this.text.trim());
                    if (answer.ok && answer.path) { wallpaperPathInput.text = answer.path; SettingsStore.wallpaperPath = answer.path; SettingsStore.save(); wallpaperFeedback.text = "Image selected; click Apply wallpaper."; }
                    else if (!answer.cancelled) wallpaperFeedback.text = answer.message;
                } catch(e) { wallpaperFeedback.text = "Wallpaper picker error: " + e; }
            } }
        }
        RowLayout { Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Image path (inside your home directory)"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
            Rectangle { Layout.preferredWidth: 102; Layout.preferredHeight: 32; radius: 9; color: Theme.surface
                RowLayout { anchors.centerIn: parent; spacing: 5
                    Icon { icon: "\ue2c7"; color: Theme.accent; font.pixelSize: 17 }
                    Text { text: "Browse file"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!wallpaperPicker.running) wallpaperPicker.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "pick-wallpaper"]) }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10; color: Theme.background
            TextInput {
                id: wallpaperPathInput
                anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter
                color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11)
                text: SettingsStore.wallpaperPath
                clip: true; selectByMouse: true
                onEditingFinished: { SettingsStore.wallpaperPath = text.trim(); SettingsStore.save(); }
            }
            Text { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; visible: !wallpaperPathInput.text.length; text:"/home/user/Pictures/wallpaper.png"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 136
            radius: 12
            color: Theme.background
            clip: true
            Image {
                id: wallpaperPreviewImage
                anchors.fill: parent
                source: wallpaperPathInput.text.trim().startsWith("/") ? "file://" + wallpaperPathInput.text.trim() : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
            ColumnLayout {
                visible: !wallpaperPreviewImage.visible
                anchors.centerIn: parent
                spacing: 7
                Icon { Layout.alignment: Qt.AlignHCenter; icon:"\ue3f4"; font.pixelSize: Fonts.scale(25); color: Theme.muted }
                Text { text:"Wallpaper preview"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(11) }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 7
            Repeater {
                model: ["auto", "swww", "awww", "hyprpaper"]
                delegate: Rectangle {
                    id: backendChoice
                    required property string modelData
                    readonly property bool chosen: SettingsStore.wallpaperBackend === modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 33; radius: 9
                    color: chosen ? Qt.alpha(Theme.accent, .16) : Theme.background
                    border.color: Theme.accent; border.width: chosen ? 1 : 0
                    Text { anchors.centerIn: parent; text:backendChoice.modelData; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.wallpaperBackend = backendChoice.modelData; SettingsStore.save(); } }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 41; radius: 10
            color: Theme.background
            RowLayout { anchors.centerIn: parent; spacing: 8
                Icon { icon:"\ue3f4"; color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                Text { text:"Apply wallpaper"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    SettingsStore.wallpaperPath = wallpaperPathInput.text.trim();
                    SettingsStore.save();
                    wallpaperFeedback.text = "Applying wallpaper…";
                    wallpaperFeedback.color = Theme.muted;
                    if (!wallpaperProcess.running)
                        wallpaperProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-wallpaper.py"), SettingsStore.wallpaperPath, "--backend", SettingsStore.wallpaperBackend]);
                }
            }
        }
        Text {
            id: wallpaperFeedback
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Wallpaper switching needs swww, awww, or hyprpaper already running. Follow Aether colors remain independent."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }

}
