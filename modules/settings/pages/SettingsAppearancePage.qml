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
        id: wallpaperSection
        heading: "Wallpaper"
        description: "Apply a local image with swaybg, or use an already running awww, swww, or hyprpaper daemon. Aether's theme files stay unchanged."
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
                sourceSize: Qt.size(720, 280)
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
                model: ["swaybg", "hyprpaper", "awww", "swww", "auto"]
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
                enabled: !wallpaperProcess.running
                onClicked: {
                    SettingsStore.wallpaperPath = wallpaperPathInput.text.trim();
                    SettingsStore.save();
                    wallpaperFeedback.text = "Applying wallpaper…";
                    wallpaperFeedback.color = Theme.muted;
                    const args = ["python3", Quickshell.shellPath("scripts/rusticq-wallpaper.py"), SettingsStore.wallpaperPath,
                                  "--backend", SettingsStore.wallpaperBackend, "--mode", SettingsStore.wallpaperFitMode];
                    if (wallpaperSection.wallpaperReplaceConflicts) args.push("--replace-conflicts");
                    wallpaperSection.wallpaperReplaceConflicts = false;
                    wallpaperProcess.exec(args);
                }
            }
        }
        property bool wallpaperReplaceConflicts: false
        Text { Layout.fillWidth: true; text: "Swaybg scaling"; color: Theme.muted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
        RowLayout { Layout.fillWidth: true; spacing: 5
            Repeater { model: ["fill", "fit", "stretch", "center", "tile"]
                delegate: Rectangle {
                    id: fitOption
                    required property string modelData
                    readonly property bool chosen: SettingsStore.wallpaperFitMode === modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 8
                    color: chosen ? Qt.alpha(Theme.accent,.16) : Theme.background
                    border.width: chosen ? 1 : 0; border.color: Theme.accent
                    Text { anchors.centerIn: parent; text: fitOption.modelData; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { SettingsStore.wallpaperFitMode = fitOption.modelData; SettingsStore.save(); } }
                }
            }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 25; Layout.preferredHeight: 25; radius: 6
                color: SettingsStore.wallpaperAutoRestore ? Theme.accent : Theme.surface
                MouseArea { anchors.fill: parent; onClicked: { SettingsStore.wallpaperAutoRestore = !SettingsStore.wallpaperAutoRestore; SettingsStore.save(); } }
            }
            Text { Layout.fillWidth: true; text: "Restore swaybg wallpaper on RusticQ startup (opt-in)"; wrapMode: Text.WordWrap
                color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 25; Layout.preferredHeight: 25; radius: 6
                color: wallpaperSection.wallpaperReplaceConflicts ? Theme.accent : Theme.surface
                MouseArea { anchors.fill: parent; onClicked: wallpaperSection.wallpaperReplaceConflicts = !wallpaperSection.wallpaperReplaceConflicts }
            }
            Text { Layout.fillWidth: true; text: "Replace other wallpaper daemons this time (may end Omarchy's wallpaper process)"; wrapMode: Text.WordWrap
                color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 25; Layout.preferredHeight: 25; radius: 6
                color: SettingsStore.wallpaperReplaceOnRestore ? Theme.accent : Theme.surface
                MouseArea { anchors.fill: parent
                    onClicked: { SettingsStore.wallpaperReplaceOnRestore = !SettingsStore.wallpaperReplaceOnRestore; SettingsStore.save(); } }
            }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Allow replacing an existing Omarchy wallpaper process on startup (explicit opt-in)"
                color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        }
        Process { id: memoryMeasureProc
            stdout: StdioCollector { onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim());
                    wallpaperMemoryLabel.text = data.ok ? "RAM used: " + data.system_used_mib.toFixed(0) + " MiB / target 2048 MiB" + (data.change_from_baseline_mib === undefined ? "" : " · Δ " + data.change_from_baseline_mib + " MiB") : data.message;
                } catch(e) { wallpaperMemoryLabel.text = "Memory report failed: " + String(e); }
            } }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Repeater { model: [{label:"Measure RAM",baseline:false},{label:"Set baseline",baseline:true}]
                delegate: Rectangle {
                    id: measurement
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 33; radius: 9; color: Theme.background
                    Text { anchors.centerIn: parent; text: measurement.modelData.label; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (!memoryMeasureProc.running) {
                            const args = ["python3", Quickshell.shellPath("scripts/rusticq-idle-memory.py")];
                            if (measurement.modelData.baseline) args.push("--save-baseline");
                            memoryMeasureProc.exec(args);
                        }
                    }
                }
            }
        }
        Text { id: wallpaperMemoryLabel; Layout.fillWidth: true; text: "Memory: use Measure RAM for live values; 2 GiB is an optimization goal, not a guarantee.";
            color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap }
        Text {
            id: wallpaperFeedback
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Swaybg Low Memory works on Wayland; install swaybg first. Use explicit replace only if switching away from an existing wallpaper provider."
            color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
        }
    }

    SettingsSection {
        id: rusticqLockSection
        heading: "RusticQ Lock Screen"
        description: "Custom QML native lockscreen secured with Wayland WlSessionLock and Linux PAM. Omarchy configuration and ASCII screensaver remain untouched."
        symbol: "\ue899"
        property string lockMessage: "The test button locks the real session. Unlock using your Linux account password."
        property bool lockSuccess: true
        Process {
            id: rusticqLockProcess
            stdout: StdioCollector { onStreamFinished: {
                try {
                    const response = JSON.parse(this.text.trim());
                    rusticqLockSection.lockSuccess = response.ok === true;
                    rusticqLockSection.lockMessage = response.message || "No result from the native locker";
                } catch(e) {
                    rusticqLockSection.lockSuccess = false;
                    rusticqLockSection.lockMessage = "Lock screen backend error: " + String(e);
                }
            } }
        }
        // Visual preview shares the same geometry, tokens, and content hierarchy
        // as the WlSessionLockSurface. No password, focus or simulated unlock.
        Rectangle {
            id: nativeLockPreview
            Layout.fillWidth: true
            Layout.preferredHeight: 268
            radius: Theme.sectionRadius
            color: Theme.background
            border.color: Theme.borderaccent
            border.width: 1
            clip: true
            Image {
                anchors.fill: parent
                visible: SettingsStore.lockscreenBackground === "wallpaper" &&
                         String(SettingsStore.wallpaperPath).startsWith("/") && status === Image.Ready
                source: SettingsStore.lockscreenBackground === "wallpaper" && String(SettingsStore.wallpaperPath).startsWith("/")
                        ? "file://" + SettingsStore.wallpaperPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.background, .90) }
            Item {
                anchors.fill: parent
                anchors.margins: 14
                Rectangle {
                    id: previewBrand
                    anchors.left: parent.left; anchors.top: parent.top
                    width: 27; height: 27; radius: 9
                    color: Qt.alpha(Theme.accent, .14)
                    Icon { anchors.centerIn: parent; icon: "\ue899"; color: Theme.accent; font.pixelSize: Fonts.scale(15) }
                }
                Column {
                    anchors.left: previewBrand.right; anchors.leftMargin: 8
                    anchors.verticalCenter: previewBrand.verticalCenter; spacing: 0
                    Text { text: "RusticQ"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(10) }
                    Text { text: "Secure session"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8) }
                }
                Rectangle {
                    anchors.top: parent.top; anchors.right: parent.right
                    width: 63; height: 24; radius: 8
                    color: Theme.surface; border.width: 1; border.color: Theme.borderaccent
                    Text { anchors.centerIn: parent; text: "LOCKED"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(8) }
                }
                Column {
                    id: previewMain
                    width: Math.min(270, parent.width - 10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 12
                    spacing: 8
                    Column {
                        width: parent.width; spacing: 0
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(), "hh:mm"); color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(27) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(), "ddd, d MMM yyyy"); color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8) }
                    }
                    Rectangle {
                        width: parent.width
                        height: 112
                        color: Theme.background
                        radius: 12
                        border.width: 1
                        border.color: Theme.borderaccent
                        Item {
                            anchors.fill: parent
                            anchors.margins: 11
                            Rectangle {
                                id: miniAvatar
                                x: 0; y: 0; width: 27; height: 27; radius: 8
                                color: Qt.alpha(Theme.accent, .14)
                                Icon { anchors.centerIn: parent; icon: "\ue853"; color: Theme.accent; font.pixelSize: Fonts.scale(15) }
                            }
                            Column {
                                anchors.left: miniAvatar.right; anchors.leftMargin: 8
                                anchors.verticalCenter: miniAvatar.verticalCenter; spacing: 1
                                Text { text: "Welcome back"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(9) }
                                Text { text: "Linux account"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8) }
                            }
                            Rectangle {
                                anchors.left: parent.left; anchors.right: parent.right
                                y: 36; height: 1; color: Theme.borderaccent
                            }
                            Rectangle {
                                y: 44; width: parent.width; height: 24; radius: 7
                                color: Theme.surface; border.width: 1; border.color: Theme.borderaccent
                                Text { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "••••••••"; color: Theme.muted; font.pixelSize: Fonts.scale(8) }
                            }
                            Rectangle {
                                y: 74; width: parent.width; height: 21; radius: 7; color: Theme.accent
                                Text { anchors.centerIn: parent; text: "Unlock session →"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(8) }
                            }
                        }
                    }
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    text: "Wayland session lock  ·  Linux PAM"
                    color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8)
                }
            }
        }
        Text { Layout.fillWidth: true; text: "Preview follows your current RusticQ palette, font, and lock background."; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10) }
        Text { text: "Lock background"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [{name:"solid",title:"Solid · private"}, {name:"wallpaper",title:"Current wallpaper"}]
                delegate: Rectangle {
                    id: lockStyle
                    required property var modelData
                    readonly property bool chosen: SettingsStore.lockscreenBackground === modelData.name
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 9
                    color: chosen ? Qt.alpha(Theme.accent, .14) : Theme.background
                    border.color: chosen ? Theme.accent : Theme.borderaccent
                    border.width: 1
                    Text { anchors.centerIn:parent; text:lockStyle.modelData.title; color: Theme.foreground; font.family:Fonts.poppins.name; font.pixelSize:Fonts.scale(11) }
                    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked: {
                        SettingsStore.lockscreenBackground = lockStyle.modelData.name;
                        SettingsStore.save();
                    } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10
                color: Theme.background
                RowLayout { anchors.centerIn: parent; spacing: 8
                    Icon { icon: "\ue889"; color: Theme.accent; font.pixelSize: Fonts.scale(18) }
                    Text { text: "Check native lock"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!rusticqLockProcess.running) rusticqLockProcess.exec(["python3",Quickshell.shellPath("scripts/rusticq-native-lock.py"),"prepare"]) }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10
                color: Theme.accent
                RowLayout { anchors.centerIn: parent; spacing: 8
                    Icon { icon: "\ue899"; color: Theme.background; font.pixelSize: Fonts.scale(18) }
                    Text { text: "Lock now"; color: Theme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!rusticqLockProcess.running) rusticqLockProcess.exec(["python3",Quickshell.shellPath("scripts/rusticq-native-lock.py"),"start"]) }
            }
        }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Native mode needs Quickshell 0.3.1+, Wayland, and system PAM login policy. A separate Quickshell process provides the secure lock surface. Hyprlock remains an explicit emergency fallback via the CLI; neither Omarchy nor PAM files are overwritten."; color: Theme.muted; font.pixelSize: Fonts.scale(10) }
        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: rusticqLockSection.lockMessage; color: rusticqLockSection.lockSuccess ? Theme.muted : Theme.error; font.pixelSize: Fonts.scale(10) }
    }

}
