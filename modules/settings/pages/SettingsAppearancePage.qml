import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../config"
import "../../../components"
import ".."

ColumnLayout {
                            id: appearancePage
    objectName:"appearance-settings-page"
    readonly property var settingsTheme: SettingsMaterial.forItem(appearancePage)
    property string sectionFilter: ""
    function showsSection(section) { return !sectionFilter || sectionFilter===section; }
                            property var installedFonts: []
                            property string fontSearch: ""
                            property string fontStatus: "Loading installed font families…"
    property bool fontsRequested:false
    function requestFonts() {
        if(showsSection("typography") && !fontsRequested && fontListProcess && !fontListProcess.running) {
            fontsRequested=true;
            fontListProcess.exec(["python3",Quickshell.shellPath("scripts/rusticq-appearance.py"),"fonts"]);
        }
    }
    onSectionFilterChanged:Qt.callLater(requestFonts)
    Component.onCompleted:requestFonts()
                            width: parent ? parent.width : 680
                            Layout.fillWidth: true
                            spacing: 12
                            SettingsWindowAppearance { Layout.fillWidth:true;visible:!appearancePage.sectionFilter && appearancePage.settingsTheme !== Theme }
                            SurfaceSpacingSettings { Layout.fillWidth: true;visible:!appearancePage.sectionFilter }
                            NetworkPanelSettings { Layout.fillWidth: true;visible:!appearancePage.sectionFilter }
                            QuickControlSettings { Layout.fillWidth: true;visible:!appearancePage.sectionFilter }
                            GlassSettings { Layout.fillWidth: true;visible:!appearancePage.sectionFilter }
                            BarSurfaceSettings { Layout.fillWidth:true;visible:!appearancePage.sectionFilter; heading:"RAGE · Surface Glass Effects · Bar" }
    ColumnLayout {
        Layout.fillWidth:true;visible:!appearancePage.sectionFilter;spacing:12
                            GlassLabel { text: "Live theme preview"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 150
                                radius: appearancePage.settingsTheme.glassRadius("card", 12)
                                color: appearancePage.settingsTheme.glassColor("card", Qt.alpha(appearancePage.settingsTheme.foreground, 0.045))
                                border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.borderaccent)
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 13
                                    spacing: 10
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: appearancePage.settingsTheme.glassRadius("card", 10)
                                        color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12; anchors.rightMargin: 12
                                            Icon { icon: "\ue5ca"; font.pixelSize: Fonts.scale(17); color: appearancePage.settingsTheme.accent }
                                            GlassLabel { text: "Workspaces"; color: appearancePage.settingsTheme.foreground; font.pixelSize: Fonts.scale(12); font.family: Fonts.poppins.name }
                                            Item { Layout.fillWidth: true }
                                            Icon { icon: "\ue63e"; font.pixelSize: Fonts.scale(18); color: appearancePage.settingsTheme.accent }
                                            GlassLabel { text: "100%"; color: appearancePage.settingsTheme.foreground; font.pixelSize: Fonts.scale(12); font.family: Fonts.poppinsSB.name }
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10
                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 65
                                            radius: appearancePage.settingsTheme.glassRadius("card", 10)
                                            color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.surface)
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 9
                                                Icon { icon: "\ue8b8"; font.pixelSize: Fonts.scale(22); color: appearancePage.settingsTheme.accent }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    GlassLabel { text: "Quick Control"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                                                    GlassLabel { text: Theme.useAether ? "Aether live colors" : "Gruvbox accents"; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.preferredWidth: 61
                                            Layout.preferredHeight: 65
                                            radius: appearancePage.settingsTheme.glassRadius("card", 10)
                                            color: appearancePage.settingsTheme.glassColor("card", Qt.alpha(appearancePage.settingsTheme.accent, 0.20))
                                            Icon { anchors.centerIn: parent; icon: "\ue40a"; font.pixelSize: Fonts.scale(24); color: appearancePage.settingsTheme.accent }
                                        }
                                    }
                                }
                            }
    }
    SettingsSection {
        visible:appearancePage.showsSection("motion")
        objectName:"appearance-motion-section"
        heading: "Animations"
        description: "Soft fades, short slides and smooth controls. Turn off for instant changes."
        symbol: "\ue9d9"
        SettingsToggle {
            objectName: "interfaceAnimationsToggle"
            modelData: ({key: "animationsEnabled", label: "Interface animations",
                desc: "Popups, panels, launcher, dock and controls", icon: "\ue9d9"})
        }
        MotionStylePicker {}
    }
    ColumnLayout {
        Layout.fillWidth:true;visible:!appearancePage.sectionFilter;spacing:12
                            GlassLabel { text: Theme.rageExclusive ? "Saved external color source" : "Color source"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            GlassLabel {
                                Layout.fillWidth: true
                                text: Theme.rageExclusive ? "RAGE Native is active. These preferences are retained for Adaptive Mode and do not style the current interface." : "Choose independent Gruvbox or follow Aether's last applied wallpaper palette."
                                color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
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
                                    radius: appearancePage.settingsTheme.glassRadius("card", 11)
                                    color: appearancePage.settingsTheme.glassColor("card", SettingsStore.colorSource === modelData.key ? Qt.alpha(appearancePage.settingsTheme.accent, 0.13) : appearancePage.settingsTheme.surface)
                                    border.width: appearancePage.settingsTheme.glassBorderWidth("card", SettingsStore.colorSource === modelData.key ? 1 : 0)
                                    border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.accent)
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 10
                                        Icon { icon: sourceRow.modelData.key === "aether" ? "\ue40a" : "\ue8b8"; font.pixelSize: Fonts.scale(21); color: appearancePage.settingsTheme.accent }
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            GlassLabel { text: sourceRow.modelData.title; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                                            GlassLabel { text: sourceRow.modelData.info; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
                                        }
                                        Icon { visible: SettingsStore.colorSource === sourceRow.modelData.key; icon: "\ue5ca"; font.pixelSize: Fonts.scale(17); color: appearancePage.settingsTheme.accent }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { SettingsStore.colorSource = sourceRow.modelData.key; SettingsStore.save(); }
                                    }
                                }
                            }
                            GlassLabel {
                                Layout.fillWidth: true
                                visible: SettingsStore.colorSource === "aether"
                                text: appearancePage.settingsTheme.aetherAvailable ? "Aether palette detected · Live sync enabled" : "Aether palette not detected · Using Gruvbox fallback until Aether applies a theme"
                                color: appearancePage.settingsTheme.aetherAvailable ? appearancePage.settingsTheme.success : appearancePage.settingsTheme.warning
                                font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                                wrapMode: Text.WordWrap
                            }
                            GlassLabel { text: "Gruvbox accent color"; visible: !Theme.rageExclusive && SettingsStore.colorSource === "gruvbox"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(13) }
                            Repeater {
                                model: [
                                    {name: "orange", label: "Gruvbox Orange", hex: "#d65d0e"},
                                    {name: "green", label: "Gruvbox Green", hex: "#b8bb26"},
                                    {name: "blue", label: "Gruvbox Aqua", hex: "#83a598"},
                                    {name: "purple", label: "Gruvbox Purple", hex: "#d3869b"}
                                ]
                                delegate: Rectangle {
                                    id: accentRow
                                    visible: !Theme.rageExclusive && SettingsStore.colorSource === "gruvbox"
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: appearancePage.settingsTheme.glassRadius("card", 11)
                                    color: appearancePage.settingsTheme.glassColor("card", SettingsStore.accentName === accentRow.modelData.name ? Qt.alpha(appearancePage.settingsTheme.accent, 0.13) : appearancePage.settingsTheme.surface)
                                    border.width: appearancePage.settingsTheme.glassBorderWidth("card", SettingsStore.accentName === accentRow.modelData.name ? 1 : 0)
                                    border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.accent)
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12; anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle { Layout.preferredWidth: 24; Layout.preferredHeight: 24; radius: 7; color: accentRow.modelData.hex }
                                        GlassLabel {
                                            Layout.fillWidth: true
                                            text: accentRow.modelData.label
                                            color: appearancePage.settingsTheme.foreground
                                            font.family: Fonts.poppins.name
                                            font.pixelSize: Fonts.scale(12)
                                        }
                                        Icon {
                                            icon: "\ue5ca"
                                            font.pixelSize: Fonts.scale(18)
                                            color: appearancePage.settingsTheme.accent
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
                            GlassLabel {
                                Layout.fillWidth: true
                                text: Theme.rageExclusive ? "Effective provider: RAGE Native · " + SettingsStore.ragePalette : SettingsStore.colorSource === "aether" ? "Aether source: " + appearancePage.settingsTheme.aetherPath : "Base palette #282828 / #3c3836 / #ebdbb2 · Poppins and Material Symbols"
                                wrapMode: Text.WordWrap
                                color: appearancePage.settingsTheme.contentMuted
                                font.family: Fonts.poppins.name
                                font.pixelSize: Fonts.scale(12)
                            }

    }
    SettingsSection {
        visible:appearancePage.showsSection("typography")
        objectName:"appearance-typography-section"
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
                    Layout.fillWidth: true; Layout.preferredHeight: 42; radius: appearancePage.settingsTheme.glassRadius("card", 10)
                    color: appearancePage.settingsTheme.glassColor("card", chosen ? Qt.alpha(appearancePage.settingsTheme.accent, 0.15) : appearancePage.settingsTheme.background)
                    border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.accent); border.width: appearancePage.settingsTheme.glassBorderWidth("card", chosen ? 1 : 0)
                    GlassLabel { anchors.centerIn: parent; text: fontOption.modelData.label; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12); color: appearancePage.settingsTheme.foreground }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.uiFontFamily = fontOption.modelData.key; SettingsStore.save(); } }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            GlassLabel { Layout.fillWidth: true; text:"Text scale"; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12); color: appearancePage.settingsTheme.foreground }
            GlassLabel { text:Math.round(SettingsStore.uiFontScale * 100) + "%"; color: appearancePage.settingsTheme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
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
                    Layout.fillWidth: true; Layout.preferredHeight: 41; radius: appearancePage.settingsTheme.glassRadius("card", 10)
                    color: appearancePage.settingsTheme.glassColor("card", chosen ? Qt.alpha(appearancePage.settingsTheme.accent, 0.15) : appearancePage.settingsTheme.background)
                    border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.accent); border.width: appearancePage.settingsTheme.glassBorderWidth("card", chosen ? 1 : 0)
                    GlassLabel { anchors.centerIn: parent; text: densityOption.modelData.label; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.uiDensity = densityOption.modelData.key; SettingsStore.save(); } }
                }
            }
        }
    }

    SettingsSection {
        visible:appearancePage.showsSection("typography")
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
            GlassLabel { Layout.fillWidth: true; text: "Selected: " + (SettingsStore.uiFontFamily === "custom" ? SettingsStore.uiCustomFont : SettingsStore.uiFontFamily); color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12); elide: Text.ElideRight }
            Repeater {
                model: [{label:"Refresh", action:"refresh"}, {label:"Add font…", action:"install"}]
                delegate: Rectangle { id: fontAction; required property var modelData
                    Layout.preferredWidth: fontAction.modelData.action === "install" ? 94 : 76
                    Layout.preferredHeight: 32; radius: appearancePage.settingsTheme.glassRadius("card", 9); color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.surface)
                    GlassLabel { anchors.centerIn: parent; text: fontAction.modelData.label; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                        if (fontAction.modelData.action === "refresh" && !fontListProcess.running) fontListProcess.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "fonts"]);
                        if (fontAction.modelData.action === "install" && !fontFilePicker.running) fontFilePicker.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "pick-font"]);
                    } }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 34; radius: appearancePage.settingsTheme.glassRadius("card", 9); color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
            TextInput { id: installedFontFilter; anchors.fill: parent; anchors.margins: 8; verticalAlignment: TextInput.AlignVCenter
                color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                onTextChanged: appearancePage.fontSearch = text.trim().toLowerCase()
            }
            GlassLabel { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; visible: !installedFontFilter.text.length; text: "Search installed font families…"; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
        }
        ListView { id: fontList; Layout.fillWidth: true; Layout.preferredHeight: 184; clip: true; spacing: 4
            model: appearancePage.installedFonts.filter(name => String(name).toLowerCase().indexOf(appearancePage.fontSearch) !== -1).slice(0, 150)
            delegate: Rectangle { id: fontEntry; required property string modelData
                width: fontList.width; height: 32; radius: appearancePage.settingsTheme.glassRadius("card", 8)
                color: appearancePage.settingsTheme.glassColor("card", SettingsStore.uiFontFamily === "custom" && SettingsStore.uiCustomFont === modelData ? Qt.alpha(appearancePage.settingsTheme.accent,0.14) : appearancePage.settingsTheme.surface)
                GlassLabel { anchors.fill: parent; anchors.leftMargin: 10; verticalAlignment: Text.AlignVCenter; text: fontEntry.modelData; elide: Text.ElideRight; color: appearancePage.settingsTheme.foreground; font.family: fontEntry.modelData; font.pixelSize: Fonts.scale(12) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.uiCustomFont = fontEntry.modelData; SettingsStore.uiFontFamily = "custom"; SettingsStore.save(); } }
            }
        }
        GlassLabel { Layout.fillWidth: true; text: appearancePage.fontStatus; wrapMode: Text.WordWrap; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
    }

    SettingsSection {
        id: wallpaperSection
        objectName:"appearance-wallpaper-section"
        visible:appearancePage.showsSection("wallpaper")
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
                        wallpaperFeedback.color = outcome.ok ? appearancePage.settingsTheme.success : appearancePage.settingsTheme.error;
                        if (outcome.ok && outcome.backend) {
                            // A successful Apply is remembered across reboot and
                            // across development/permanent shell installations.
                            SettingsStore.wallpaperAutoRestore = outcome.auto_restore === true;
                            SettingsStore.save();
                        }
                    } catch(e) { wallpaperFeedback.text = "Wallpaper command did not return a valid result."; wallpaperFeedback.color = appearancePage.settingsTheme.error; }
                }
            }
        }
        property bool requestedAutoRestore: false
        property bool requestedReplaceRestore: false
        function saveRestoreChoice(enabled, replace) {
            if (restoreConfigProc.running) return;
            if (enabled && SettingsStore.wallpaperBackend !== "swaybg") {
                wallpaperFeedback.text = "Choose swaybg before enabling automatic swaybg restore.";
                wallpaperFeedback.color = appearancePage.settingsTheme.error;
                return;
            }
            requestedAutoRestore = enabled;
            requestedReplaceRestore = replace;
            const args = ["python3", Quickshell.shellPath("scripts/rusticq-wallpaper.py"),
                          SettingsStore.wallpaperPath, "--configure-restore", enabled ? "on" : "off",
                          "--mode", SettingsStore.wallpaperFitMode];
            if (replace) args.push("--remember-replace");
            restoreConfigProc.exec(args);
        }
        Process {
            id: restoreConfigProc
            stdout: StdioCollector { onStreamFinished: {
                try {
                    const outcome = JSON.parse(this.text.trim());
                    wallpaperFeedback.text = outcome.message;
                    wallpaperFeedback.color = outcome.ok ? appearancePage.settingsTheme.success : appearancePage.settingsTheme.error;
                    if (outcome.ok) {
                        SettingsStore.wallpaperAutoRestore = wallpaperSection.requestedAutoRestore;
                        SettingsStore.wallpaperReplaceOnRestore = wallpaperSection.requestedReplaceRestore;
                        SettingsStore.save();
                    }
                } catch (e) {
                    wallpaperFeedback.text = "Cannot update startup wallpaper: " + String(e);
                    wallpaperFeedback.color = appearancePage.settingsTheme.error;
                }
            } }
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
            GlassLabel { Layout.fillWidth: true; text: "Image path (inside your home directory)"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            Rectangle { Layout.preferredWidth: 102; Layout.preferredHeight: 32; radius: appearancePage.settingsTheme.glassRadius("card", 9); color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.surface)
                RowLayout { anchors.centerIn: parent; spacing: 5
                    Icon { icon: "\ue2c7"; color: appearancePage.settingsTheme.accent; font.pixelSize: 17 }
                    GlassLabel { text: "Browse file"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!wallpaperPicker.running) wallpaperPicker.exec(["python3", Quickshell.shellPath("scripts/rusticq-appearance.py"), "pick-wallpaper"]) }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 42; radius: appearancePage.settingsTheme.glassRadius("card", 10); color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
            TextInput {
                id: wallpaperPathInput
                anchors.fill: parent; anchors.margins: 12; verticalAlignment: TextInput.AlignVCenter
                color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                text: SettingsStore.wallpaperPath
                clip: true; selectByMouse: true
                onEditingFinished: { SettingsStore.wallpaperPath = text.trim(); SettingsStore.save(); }
            }
            GlassLabel { anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; visible: !wallpaperPathInput.text.length; text:"/home/user/Pictures/wallpaper.png"; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 136
            radius: appearancePage.settingsTheme.glassRadius("card", 12)
            color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
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
                Icon { Layout.alignment: Qt.AlignHCenter; icon:"\ue3f4"; font.pixelSize: Fonts.scale(25); color: appearancePage.settingsTheme.contentMuted }
                GlassLabel { text:"Wallpaper preview"; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
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
                    Layout.fillWidth: true; Layout.preferredHeight: 33; radius: appearancePage.settingsTheme.glassRadius("card", 9)
                    color: appearancePage.settingsTheme.glassColor("card", chosen ? Qt.alpha(appearancePage.settingsTheme.accent, .16) : appearancePage.settingsTheme.background)
                    border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.accent); border.width: appearancePage.settingsTheme.glassBorderWidth("card", chosen ? 1 : 0)
                    GlassLabel { anchors.centerIn: parent; text:backendChoice.modelData; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { SettingsStore.wallpaperBackend = backendChoice.modelData; SettingsStore.save(); } }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 41; radius: appearancePage.settingsTheme.glassRadius("card", 10)
            color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
            RowLayout { anchors.centerIn: parent; spacing: 8
                Icon { icon:"\ue3f4"; color: appearancePage.settingsTheme.accent; font.pixelSize: Fonts.scale(17) }
                GlassLabel { text:"Apply wallpaper"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                enabled: !wallpaperProcess.running
                onClicked: {
                    SettingsStore.wallpaperPath = wallpaperPathInput.text.trim();
                    SettingsStore.save();
                    wallpaperFeedback.text = "Applying wallpaper…";
                    wallpaperFeedback.color = appearancePage.settingsTheme.muted;
                    const args = ["python3", Quickshell.shellPath("scripts/rusticq-wallpaper.py"), SettingsStore.wallpaperPath,
                                  "--backend", SettingsStore.wallpaperBackend, "--mode", SettingsStore.wallpaperFitMode];
                    if (wallpaperSection.wallpaperReplaceConflicts) args.push("--replace-conflicts");
                    // Remember only after successful Apply, never an invalid path.
                    args.push("--remember");
                    if (SettingsStore.wallpaperReplaceOnRestore) args.push("--remember-replace");
                    wallpaperSection.wallpaperReplaceConflicts = false;
                    wallpaperProcess.exec(args);
                }
            }
        }
        property bool wallpaperReplaceConflicts: false
        GlassLabel { Layout.fillWidth: true; text: "Swaybg scaling"; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
        RowLayout { Layout.fillWidth: true; spacing: 5
            Repeater { model: ["fill", "fit", "stretch", "center", "tile"]
                delegate: Rectangle {
                    id: fitOption
                    required property string modelData
                    readonly property bool chosen: SettingsStore.wallpaperFitMode === modelData
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: appearancePage.settingsTheme.glassRadius("card", 8)
                    color: appearancePage.settingsTheme.glassColor("card", chosen ? Qt.alpha(appearancePage.settingsTheme.accent,.16) : appearancePage.settingsTheme.background)
                    border.width: appearancePage.settingsTheme.glassBorderWidth("card", chosen ? 1 : 0); border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.accent)
                    GlassLabel { anchors.centerIn: parent; text: fitOption.modelData; color: appearancePage.settingsTheme.foreground; font.pixelSize: Fonts.scale(12) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { SettingsStore.wallpaperFitMode = fitOption.modelData; SettingsStore.save(); } }
                }
            }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 25; Layout.preferredHeight: 25; radius: appearancePage.settingsTheme.glassRadius("card", 6)
                color: appearancePage.settingsTheme.glassColor("card", SettingsStore.wallpaperAutoRestore ? appearancePage.settingsTheme.accent : appearancePage.settingsTheme.surface)
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor;
                    onClicked: wallpaperSection.saveRestoreChoice(!SettingsStore.wallpaperAutoRestore,
                                                                   SettingsStore.wallpaperReplaceOnRestore) }
            }
            GlassLabel { Layout.fillWidth: true; text: "Restore swaybg automatically after login (enabled after Apply)"; wrapMode: Text.WordWrap
                color: appearancePage.settingsTheme.foreground; font.pixelSize: Fonts.scale(12) }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 25; Layout.preferredHeight: 25; radius: appearancePage.settingsTheme.glassRadius("card", 6)
                color: appearancePage.settingsTheme.glassColor("card", wallpaperSection.wallpaperReplaceConflicts ? appearancePage.settingsTheme.accent : appearancePage.settingsTheme.surface)
                MouseArea { anchors.fill: parent; onClicked: wallpaperSection.wallpaperReplaceConflicts = !wallpaperSection.wallpaperReplaceConflicts }
            }
            GlassLabel { Layout.fillWidth: true; text: "Replace other wallpaper daemons this time (may end Omarchy's wallpaper process)"; wrapMode: Text.WordWrap
                color: appearancePage.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(12) }
        }
        RowLayout { Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 25; Layout.preferredHeight: 25; radius: appearancePage.settingsTheme.glassRadius("card", 6)
                color: appearancePage.settingsTheme.glassColor("card", SettingsStore.wallpaperReplaceOnRestore ? appearancePage.settingsTheme.accent : appearancePage.settingsTheme.surface)
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: wallpaperSection.saveRestoreChoice(SettingsStore.wallpaperAutoRestore,
                                                                   !SettingsStore.wallpaperReplaceOnRestore) }
            }
            GlassLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: "Allow replacing an existing Omarchy wallpaper process on startup (explicit opt-in)"
                color: appearancePage.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(12) }
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
                    Layout.fillWidth: true; Layout.preferredHeight: 33; radius: appearancePage.settingsTheme.glassRadius("card", 9); color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
                    GlassLabel { anchors.centerIn: parent; text: measurement.modelData.label; color: appearancePage.settingsTheme.foreground; font.pixelSize: Fonts.scale(12) }
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
        GlassLabel { id: wallpaperMemoryLabel; Layout.fillWidth: true; text: "Memory: use Measure RAM for live values; 2 GiB is an optimization goal, not a guarantee.";
            color: appearancePage.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(12); wrapMode: Text.WordWrap }
        GlassLabel {
            id: wallpaperFeedback
            Layout.fillWidth: true; wrapMode: Text.WordWrap
            text: "Choose an image, then Apply. RusticQ remembers swaybg across logout/reboot for all monitors. Do not autostart bare 'swaybg' without -i image; this backend supplies the image itself."
            color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
        }
    }

    SettingsSection {
        id: rusticqLockSection
        objectName:"appearance-lockscreen-section"
        visible:appearancePage.showsSection("lockscreen")
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
            radius: appearancePage.settingsTheme.glassRadius("card", appearancePage.settingsTheme.sectionRadius)
            color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
            border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.borderaccent)
            border.width: appearancePage.settingsTheme.glassBorderWidth("card", 1)
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
            Rectangle { anchors.fill: parent; color: appearancePage.settingsTheme.glassColor("card", Qt.alpha(appearancePage.settingsTheme.background, .90)) }
            Item {
                anchors.fill: parent
                anchors.margins: 14
                Rectangle {
                    id: previewBrand
                    anchors.left: parent.left; anchors.top: parent.top
                    width: 27; height: 27; radius: appearancePage.settingsTheme.glassRadius("card", 9)
                    color: appearancePage.settingsTheme.glassColor("card", Qt.alpha(appearancePage.settingsTheme.accent, .14))
                    Icon { anchors.centerIn: parent; icon: "\ue899"; color: appearancePage.settingsTheme.accent; font.pixelSize: Fonts.scale(15) }
                }
                Column {
                    anchors.left: previewBrand.right; anchors.leftMargin: 8
                    anchors.verticalCenter: previewBrand.verticalCenter; spacing: 0
                    GlassLabel { text: "RusticQ"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                    GlassLabel { text: "Secure session"; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8) }
                }
                Rectangle {
                    anchors.top: parent.top; anchors.right: parent.right
                    width: 63; height: 24; radius: appearancePage.settingsTheme.glassRadius("card", 8)
                    color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.surface); border.width: appearancePage.settingsTheme.glassBorderWidth("card", 1); border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.borderaccent)
                    GlassLabel { anchors.centerIn: parent; text: "LOCKED"; color: appearancePage.settingsTheme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(8) }
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
                        GlassLabel { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(), "hh:mm"); color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(27) }
                        GlassLabel { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(), "ddd, d MMM yyyy"); color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8) }
                    }
                    Rectangle {
                        width: parent.width
                        height: 112
                        color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
                        radius: appearancePage.settingsTheme.glassRadius("card", 12)
                        border.width: appearancePage.settingsTheme.glassBorderWidth("card", 1)
                        border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.borderaccent)
                        Item {
                            anchors.fill: parent
                            anchors.margins: 11
                            Rectangle {
                                id: miniAvatar
                                x: 0; y: 0; width: 27; height: 27; radius: appearancePage.settingsTheme.glassRadius("card", 8)
                                color: appearancePage.settingsTheme.glassColor("card", Qt.alpha(appearancePage.settingsTheme.accent, .14))
                                Icon { anchors.centerIn: parent; icon: "\ue853"; color: appearancePage.settingsTheme.accent; font.pixelSize: Fonts.scale(15) }
                            }
                            Column {
                                anchors.left: miniAvatar.right; anchors.leftMargin: 8
                                anchors.verticalCenter: miniAvatar.verticalCenter; spacing: 1
                                GlassLabel { text: "Welcome back"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                                GlassLabel { text: "Linux account"; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8) }
                            }
                            Rectangle {
                                y: 44; width: parent.width; height: 24; radius: appearancePage.settingsTheme.glassRadius("card", 7)
                                color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.surface); border.width: appearancePage.settingsTheme.glassBorderWidth("card", 1); border.color: appearancePage.settingsTheme.glassBorder("card", appearancePage.settingsTheme.borderaccent)
                                GlassLabel { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "••••••••"; color: appearancePage.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(8) }
                            }
                            Rectangle {
                                y: 74; width: parent.width; height: 21; radius: 7; color: appearancePage.settingsTheme.accent
                                GlassLabel { anchors.centerIn: parent; text: "Unlock session →"; color: appearancePage.settingsTheme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(8) }
                            }
                        }
                    }
                }
                GlassLabel {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    text: "Wayland session lock  ·  Linux PAM"
                    color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(8)
                }
            }
        }
        GlassLabel { Layout.fillWidth: true; text: "Preview follows your current RusticQ palette, font, and lock background."; color: appearancePage.settingsTheme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
        GlassLabel { text: "Lock background"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
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
                    radius: appearancePage.settingsTheme.glassRadius("card", 9)
                    color: appearancePage.settingsTheme.glassColor("card", chosen ? Qt.alpha(appearancePage.settingsTheme.accent, .14) : appearancePage.settingsTheme.background)
                    border.color: appearancePage.settingsTheme.glassBorder("card", chosen ? appearancePage.settingsTheme.accent : appearancePage.settingsTheme.borderaccent)
                    border.width: appearancePage.settingsTheme.glassBorderWidth("card", 1)
                    GlassLabel { anchors.centerIn:parent; text:lockStyle.modelData.title; color: appearancePage.settingsTheme.foreground; font.family:Fonts.poppins.name; font.pixelSize: Fonts.scale(12) }
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
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: appearancePage.settingsTheme.glassRadius("card", 10)
                color: appearancePage.settingsTheme.glassColor("card", appearancePage.settingsTheme.background)
                RowLayout { anchors.centerIn: parent; spacing: 8
                    Icon { icon: "\ue889"; color: appearancePage.settingsTheme.accent; font.pixelSize: Fonts.scale(18) }
                    GlassLabel { text: "Check native lock"; color: appearancePage.settingsTheme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!rusticqLockProcess.running) rusticqLockProcess.exec(["python3",Quickshell.shellPath("scripts/rusticq-native-lock.py"),"prepare"]) }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 10
                color: appearancePage.settingsTheme.accent
                RowLayout { anchors.centerIn: parent; spacing: 8
                    Icon { icon: "\ue899"; color: appearancePage.settingsTheme.background; font.pixelSize: Fonts.scale(18) }
                    GlassLabel { text: "Lock now"; color: appearancePage.settingsTheme.background; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (!rusticqLockProcess.running) rusticqLockProcess.exec(["python3",Quickshell.shellPath("scripts/rusticq-native-lock.py"),"start"]) }
            }
        }
        GlassLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Native mode needs Quickshell 0.3.1+, Wayland, and system PAM login policy. A separate Quickshell process provides the secure lock surface. Hyprlock remains an explicit emergency fallback via the CLI; neither Omarchy nor PAM files are overwritten."; color: appearancePage.settingsTheme.contentMuted; font.pixelSize: Fonts.scale(12) }
        GlassLabel { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: rusticqLockSection.lockMessage; color: rusticqLockSection.lockSuccess ? appearancePage.settingsTheme.muted : appearancePage.settingsTheme.error; font.pixelSize: Fonts.scale(12) }
    }

}
