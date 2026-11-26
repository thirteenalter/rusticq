import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../../config"
import "../../components"
import "../../services"
import "../quickcontrol"

// Separate advanced page, reached through the footer. Never replaces the
// classic Gruvbox UI; the regular control page is restored with Back.
Flickable {
    id: root
    QuickControlInputBridge {target:root;active:QuickControlStyle.modular && root.visible}
    clip: true
    contentHeight: advanceContent.implicitHeight + (QuickControlStyle.modular ? 0 : 10)
    boundsBehavior: Flickable.StopAtBounds

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    readonly property var outputDevices: Pipewire.nodes.values.filter(
        (node) => node.audio !== null && node.isSink && !node.isStream)
    readonly property var inputDevices: Pipewire.nodes.values.filter(
        (node) => node.audio !== null && !node.isSink && !node.isStream)
    property bool audioExpanded: true
    property bool screenExpanded: false
    property bool mediaExpanded: true
    readonly property real brightness: BrightnessService.brightness
    readonly property bool brightnessAvailable: BrightnessService.available
    readonly property string brightnessError: BrightnessService.error
    readonly property int preferredContentHeight: Math.ceil(contentHeight)
    function setBrightness(level) { BrightnessService.setBrightness(level); }
    PwObjectTracker { objects: root.visible ? [root.sink, root.source].concat(root.outputDevices, root.inputDevices).filter(node => node !== null) : [] }

    ColumnLayout {
        id: advanceContent
        width: root.width
        spacing: QuickControlStyle.modular ? QuickControlStyle.sectionGap : 10
        RowLayout {
            visible: QuickControlStyle.modular
            Layout.fillWidth: true
            spacing: QuickControlStyle.gap
            Repeater {
                model: [{key:"audio",label:"Audio",icon:"\ue050"},{key:"display",label:"Display",icon:"\ue30b"},{key:"media",label:"Media",icon:"\ue3a1"}]
                QuickControlDeviceRow {
                    required property var modelData
                    objectName: "advancedTab_" + modelData.key
                    Layout.fillWidth: true
                    label: modelData.label
                    symbol: modelData.icon
                    selected: Store.quickAdvancedTab === modelData.key
                    color: selected ? QuickControlStyle.surface(true,false,false) : "transparent"
                    onClicked: {Store.quickAdvancedTab=modelData.key;root.contentY=0;}
                }
            }
        }
        GlassLabel {
            visible: !QuickControlStyle.modular
            text: "Advanced controls"
            font.family: Fonts.poppinsSB.name
            font.pixelSize: Fonts.scale(18)
            color: Theme.foreground
            Layout.leftMargin: 10
            Layout.topMargin: 6
        }
        GlassLabel {
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.bottomMargin: 4
            visible: !QuickControlStyle.modular
            text: "Audio, screen, monitors and media"
            font.family: Fonts.poppins.name
            font.pixelSize: Fonts.scale(11)
            color: Theme.contentMuted
        }

        Rectangle {
            id: audioCard
            visible: !QuickControlStyle.modular || Store.quickAdvancedTab === "audio"
            opacity: !QuickControlStyle.modular || Store.quickAdvancedTab === "audio" ? 1 : 0
            Behavior on opacity {enabled:QuickControlStyle.modular && QuickControlStyle.motion;NumberAnimation {duration:Theme.motionEnterDuration;easing.type:Easing.OutCubic}}
            Layout.fillWidth: true
            Layout.preferredHeight: QuickControlStyle.modular ? audioInner.implicitHeight : root.audioExpanded ? audioInner.implicitHeight + 28 : 64
            radius: Theme.glassRadius("card", 18); clip: true
            color: QuickControlStyle.modular ? "transparent" : Theme.glassColor("card", Qt.alpha(Theme.foreground, 0.025))
            border.width: QuickControlStyle.modular ? 0 : Theme.glassBorderWidth("card", 1)
            border.color: Theme.glassBorder("card", Theme.borderaccent)
            ColumnLayout {
                id: audioInner
                anchors.fill: parent; anchors.margins: QuickControlStyle.modular ? 0 : Theme.panelPadding
                spacing: 9
                RowLayout {
                    Layout.fillWidth: true
                    visible: !QuickControlStyle.modular
                    Layout.preferredHeight: 36
                    Layout.maximumHeight: 36
                    SectionHeader {
                        Layout.fillWidth: true
                        title: "Audio"
                        iconName: "\ue050"
                        expanded: root.audioExpanded
                        onToggleRequested: root.audioExpanded = !root.audioExpanded
                    }
                    DeviceSettingsButton {
                        kind: "audio"
                        section: "applications"
                        label: "Open audio fullscreen"
                        symbol: "\ue5d0"
                        iconOnly: true
                        fullscreen: true
                        targetScreen: Store.sidebarScreen
                    }
                }
                ColumnLayout {
                    visible: root.audioExpanded || QuickControlStyle.modular
                    Layout.fillWidth: true
                    spacing: 6
                    Loader {
                        Layout.fillWidth: true
                        active: QuickControlStyle.modular
                        visible: active
                        sourceComponent: QuickControlSlider {
                            objectName: "advancedSinkSlider"
                            label: "Output volume"
                            symbol: "\ue050"
                            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                            maximumValue: Math.max(1.5,value)
                            adjustable: !!(root.sink && root.sink.audio)
                            muted: !!(root.sink && root.sink.audio && root.sink.audio.muted)
                            onUserChanged: next => {if(root.sink && root.sink.audio)root.sink.audio.volume=next;}
                            onIconClicked: if(root.sink && root.sink.audio)root.sink.audio.muted=!root.sink.audio.muted
                        }
                    }
                    RowLayout {
                        visible: !QuickControlStyle.modular
                        Layout.fillWidth: true
                        Icon {
                            icon: root.sink && root.sink.audio && root.sink.audio.muted ? "\ue04f" : "\ue050"
                            font.pixelSize: Fonts.scale(19)
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                enabled: root.sink !== null && root.sink.audio !== null
                                onClicked: root.sink.audio.muted = !root.sink.audio.muted
                            }
                        }
                        GlassLabel { text: "Output"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: Fonts.scale(12); font.family: Fonts.poppins.name }
                        GlassLabel {
                            text: root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) + "%" : "N/A"
                            color: Theme.contentMuted; font.pixelSize: Fonts.scale(12)
                        }
                    }
                    ControlSlider {
                        visible: !QuickControlStyle.modular
                        Layout.fillWidth: true
                        value: root.sink && root.sink.audio ? Math.min(1, root.sink.audio.volume) : 0
                        adjustable: root.sink && root.sink.audio
                        onUserChanged: (next) => { if (root.sink && root.sink.audio) root.sink.audio.volume = next; }
                    }
                    ApplicationAudioMixer { Layout.fillWidth: true; framelessQuickControl: QuickControlStyle.modular }
                    Loader {
                        Layout.fillWidth: true
                        active: QuickControlStyle.modular
                        visible: active
                        sourceComponent: QuickControlSlider {
                            objectName: "advancedSourceSlider"
                            label: "Microphone"
                            symbol: "\ue029"
                            value: root.source && root.source.audio ? root.source.audio.volume : 0
                            maximumValue: Math.max(1.5,value)
                            adjustable: !!(root.source && root.source.audio)
                            muted: !!(root.source && root.source.audio && root.source.audio.muted)
                            onUserChanged: next => {if(root.source && root.source.audio)root.source.audio.volume=next;}
                            onIconClicked: if(root.source && root.source.audio)root.source.audio.muted=!root.source.audio.muted
                        }
                    }
                    RowLayout {
                        visible: !QuickControlStyle.modular
                        Layout.fillWidth: true
                        Icon {
                            icon: root.source && root.source.audio && root.source.audio.muted ? "\ue02b" : "\ue029"
                            font.pixelSize: Fonts.scale(19)
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                enabled: root.source !== null && root.source.audio !== null
                                onClicked: root.source.audio.muted = !root.source.audio.muted
                            }
                        }
                        GlassLabel { text: "Microphone"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: Fonts.scale(12); font.family: Fonts.poppins.name }
                        GlassLabel {
                            text: root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) + "%" : "N/A"
                            color: Theme.contentMuted; font.pixelSize: Fonts.scale(12)
                        }
                    }
                    ControlSlider {
                        visible: !QuickControlStyle.modular
                        Layout.fillWidth: true
                        value: root.source && root.source.audio ? Math.min(1, root.source.audio.volume) : 0
                        adjustable: root.source && root.source.audio
                        onUserChanged: (next) => { if (root.source && root.source.audio) root.source.audio.volume = next; }
                    }
                    GlassLabel {
                        text: QuickControlStyle.modular ? "Output devices" : "Output device"
                        color: Theme.contentMuted; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppinsSB.name
                    }
                    Repeater {
                        model: root.outputDevices
                        delegate: Rectangle {
                            id: outputDevice
                            activeFocusOnTab: QuickControlStyle.modular
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.description || modelData.name
                            Accessible.onPressAction: Pipewire.preferredDefaultAudioSink = modelData
                            Keys.onReturnPressed: Pipewire.preferredDefaultAudioSink = modelData
                            Keys.onSpacePressed: Pipewire.preferredDefaultAudioSink = modelData
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 30
                            radius: Theme.glassRadius("card", 8); color: QuickControlStyle.modular ? (outputPointer.containsMouse || activeFocus ? QuickControlStyle.surface(false,true,false) : "transparent") : Theme.glassColor("card", Pipewire.defaultAudioSink === modelData ? Qt.alpha(Theme.accent, 0.15) : Theme.surface)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                                Icon {visible:QuickControlStyle.modular;icon:"\ue050";font.pixelSize:Fonts.scale(16);color:Pipewire.defaultAudioSink===outputDevice.modelData ? Theme.accent : Theme.contentMuted}
                                GlassLabel {
                                    Layout.fillWidth: true
                                    text: outputDevice.modelData.description || outputDevice.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name; color: Theme.foreground
                                }
                                Icon {
                                    icon: "\ue5ca"; font.pixelSize: Fonts.scale(16); color: Theme.accent
                                    visible: Pipewire.defaultAudioSink === outputDevice.modelData
                                }
                            }
                            MouseArea {
                                id: outputPointer
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSink = outputDevice.modelData
                            }
                        }
                    }
                    GlassLabel {
                        text: QuickControlStyle.modular ? "Input devices" : "Input device · microphone"
                        color: Theme.contentMuted; font.pixelSize: Fonts.scale(11); font.family: Fonts.poppinsSB.name
                    }
                    GlassLabel {
                        visible: root.inputDevices.length === 0
                        text: "No microphone capture source found"
                        font.pixelSize: Fonts.scale(10); color: Theme.contentMuted; font.family: Fonts.poppins.name
                    }
                    Repeater {
                        model: root.inputDevices
                        delegate: Rectangle {
                            id: inputDevice
                            activeFocusOnTab: QuickControlStyle.modular
                            Accessible.role: Accessible.Button
                            Accessible.name: modelData.description || modelData.name
                            Accessible.onPressAction: Pipewire.preferredDefaultAudioSource = modelData
                            Keys.onReturnPressed: Pipewire.preferredDefaultAudioSource = modelData
                            Keys.onSpacePressed: Pipewire.preferredDefaultAudioSource = modelData
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            radius: Theme.glassRadius("card", 8)
                            color: QuickControlStyle.modular ? (inputPointer.containsMouse || activeFocus ? QuickControlStyle.surface(false,true,false) : "transparent") : Theme.glassColor("card", Pipewire.defaultAudioSource === modelData ? Qt.alpha(Theme.accent, 0.15) : Theme.surface)
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                Icon { icon: "\ue029"; font.pixelSize: Fonts.scale(16); color: Theme.accent; Layout.preferredWidth: 20 }
                                GlassLabel {
                                    Layout.fillWidth: true
                                    text: inputDevice.modelData.description || inputDevice.modelData.nickname || inputDevice.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: Fonts.scale(10); font.family: Fonts.poppins.name; color: Theme.foreground
                                }
                                Icon {
                                    icon: "\ue5ca"; font.pixelSize: Fonts.scale(16); color: Theme.accent
                                    Layout.preferredWidth: 20
                                    visible: Pipewire.defaultAudioSource === inputDevice.modelData
                                }
                            }
                            MouseArea {
                                id: inputPointer
                                hoverEnabled: true
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Pipewire.preferredDefaultAudioSource = inputDevice.modelData
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            visible: !QuickControlStyle.modular || Store.quickAdvancedTab === "display"
            opacity: !QuickControlStyle.modular || Store.quickAdvancedTab === "display" ? 1 : 0
            Behavior on opacity {enabled:QuickControlStyle.modular && QuickControlStyle.motion;NumberAnimation {duration:Theme.motionEnterDuration;easing.type:Easing.OutCubic}}
            Layout.preferredHeight: QuickControlStyle.modular ? screenInner.implicitHeight : root.screenExpanded ? 180 + monitorControls.implicitHeight : 64
            radius: Theme.glassRadius("card", 18); clip: true
            color: QuickControlStyle.modular ? "transparent" : Theme.glassColor("card", Qt.alpha(Theme.foreground, 0.025))
            border.width: QuickControlStyle.modular ? 0 : Theme.glassBorderWidth("card", 1)
            border.color: Theme.glassBorder("card", Theme.borderaccent)
            ColumnLayout {
                id: screenInner
                anchors.fill: parent; anchors.margins: QuickControlStyle.modular ? 0 : Theme.panelPadding
                spacing: 8
                SectionHeader {
                    visible: !QuickControlStyle.modular
                    title: "Screen"
                    iconName: "\ue30b"
                    expanded: root.screenExpanded
                    onToggleRequested: root.screenExpanded = !root.screenExpanded
                }
                ColumnLayout {
                    visible: root.screenExpanded || QuickControlStyle.modular
                    Layout.fillWidth: true
                    spacing: 6
                    Loader {Layout.fillWidth:true;active:QuickControlStyle.modular;visible:active
                        sourceComponent:QuickControlSlider {label:"Brightness";iconInteractive:false;symbol:"\ue3ab";value:root.brightness;adjustable:root.brightnessAvailable;onUserChanged:next=>root.setBrightness(next)}
                    }
                    RowLayout {
                        visible: !QuickControlStyle.modular
                        Layout.fillWidth: true
                        Icon { icon: "\ue3ab"; font.pixelSize: Fonts.scale(19) }
                        GlassLabel { text: "Brightness"; Layout.fillWidth: true; color: Theme.foreground; font.pixelSize: Fonts.scale(12); font.family: Fonts.poppins.name }
                        GlassLabel { text: root.brightnessAvailable ? Math.round(root.brightness * 100) + "%" : "N/A"; color: Theme.contentMuted; font.pixelSize: Fonts.scale(12) }
                    }
                    ControlSlider {
                        visible: !QuickControlStyle.modular
                        Layout.fillWidth: true
                        value: root.brightness
                        adjustable: root.brightnessAvailable
                        onUserChanged: (next) => root.setBrightness(next)
                    }
                    GlassLabel {
                        Layout.fillWidth: true
                        text: root.brightnessError || "Backlight via brightnessctl (laptop displays)"
                        color: root.brightnessError ? Theme.error : Theme.muted
                        font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap
                    }
                    Loader {Layout.fillWidth:true;active:QuickControlStyle.modular;visible:active
                        sourceComponent:ColumnLayout {
                            QuickControlDeviceRow {Layout.fillWidth:true;label:"Night Light";symbol:"\ue51c";selected:QuickModesService.active("night");enabled:QuickModesService.available("night");onClicked:QuickModesService.toggle("night")}
                            QuickControlSlider {Layout.fillWidth:true;iconInteractive:false;label:"Night Light warmth";stepSize:100;symbol:"\ue51c";maximumValue:4000;value:SettingsStore.nightLightTemperature-2000;valueText:SettingsStore.nightLightTemperature+" K";onUserChanged:next=>QuickModesService.setNightLightTemperature(next+2000)}
                        }
                    }
                    BarMonitors {
                        objectName: "advancedMonitorControls"
                        framelessQuickControl: QuickControlStyle.modular
                        id: monitorControls
                        Layout.fillWidth: true
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            visible: !QuickControlStyle.modular || Store.quickAdvancedTab === "media"
            opacity: !QuickControlStyle.modular || Store.quickAdvancedTab === "media" ? 1 : 0
            Behavior on opacity {enabled:QuickControlStyle.modular && QuickControlStyle.motion;NumberAnimation {duration:Theme.motionEnterDuration;easing.type:Easing.OutCubic}}
            Layout.preferredHeight: QuickControlStyle.modular ? mediaPage.implicitHeight : root.mediaExpanded ? 158 : 64
            Loader {id:mediaPage;anchors.left:parent.left;anchors.right:parent.right;active:QuickControlStyle.modular;visible:active;sourceComponent:QuickControlMedia {detailed:true}}
            radius: Theme.glassRadius("card", 18); clip: true
            color: QuickControlStyle.modular ? "transparent" : Theme.glassColor("card", Qt.alpha(Theme.foreground, 0.025))
            border.width: QuickControlStyle.modular ? 0 : Theme.glassBorderWidth("card", 1)
            border.color: Theme.glassBorder("card", Theme.borderaccent)
            ColumnLayout {
                visible: !QuickControlStyle.modular
                anchors.fill: parent; anchors.margins: QuickControlStyle.modular ? 0 : Theme.panelPadding
                spacing: 8
                SectionHeader {
                    title: "Media"
                    iconName: "\ue3a1"
                    expanded: root.mediaExpanded
                    onToggleRequested: root.mediaExpanded = !root.mediaExpanded
                }
                ColumnLayout {
                    visible: root.mediaExpanded
                    Layout.fillWidth: true
                    spacing: 5
                    GlassLabel {
                        Layout.fillWidth: true
                        text: root.player ? (root.player.trackTitle || root.player.identity) : "No media player"
                        elide: Text.ElideRight
                        color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(12)
                    }
                    GlassLabel {
                        Layout.fillWidth: true; elide: Text.ElideRight
                        text: root.player ? (root.player.trackArtist || root.player.identity) : "Open a music player to use media controls"
                        color: Theme.contentMuted; font.family: Fonts.poppins.name; font.pixelSize: Fonts.scale(10)
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 18
                        Icon {
                            icon: "\ue045"; font.pixelSize: Fonts.scale(24)
                            opacity: root.player && root.player.canGoPrevious ? 1 : 0.4
                            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canGoPrevious; cursorShape: Qt.PointingHandCursor; onClicked: root.player.previous() }
                        }
                        Icon {
                            icon: root.player && root.player.isPlaying ? "\ue034" : "\ue037"
                            font.pixelSize: Fonts.scale(27); color: Theme.accent
                            opacity: root.player && root.player.canTogglePlaying ? 1 : 0.4
                            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canTogglePlaying; cursorShape: Qt.PointingHandCursor; onClicked: root.player.togglePlaying() }
                        }
                        Icon {
                            icon: "\ue044"; font.pixelSize: Fonts.scale(24)
                            opacity: root.player && root.player.canGoNext ? 1 : 0.4
                            MouseArea { anchors.fill: parent; enabled: root.player && root.player.canGoNext; cursorShape: Qt.PointingHandCursor; onClicked: root.player.next() }
                        }
                    }
                }
            }
        }
        Rectangle {
            visible: !QuickControlStyle.modular
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: Theme.glassRadius("card", 12)
            color: Theme.glassColor("card", Theme.surface)
            border.width: Theme.glassBorderWidth("card", 1); border.color: Theme.glassBorder("card", Theme.borderaccent)
            RowLayout {
                anchors.centerIn: parent; spacing: 9
                Icon { icon: "\ue8b8"; font.pixelSize: Fonts.scale(19); color: Theme.accent }
                GlassLabel {
                    text: "SEE FULL SETTINGS"
                    font.family: Fonts.poppinsSB.name
                    font.pixelSize: Fonts.scale(12)
                    color: Theme.foreground
                }
                Icon { icon: "\ue5cc"; font.pixelSize: Fonts.scale(18); color: Theme.accent }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: Store.showSettings("home")
            }
        }
    }
}
