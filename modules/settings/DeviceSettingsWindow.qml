import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../config"
import "../../components"
import "pages"

FloatingWindow {
    id: root
    visible: Store.deviceSettingsVisible
    screen: Store.deviceSettingsScreen
    title: "RusticQ · Device settings"
    implicitWidth: Math.max(600, Math.min(720, screen ? screen.width - 64 : 720))
    implicitHeight: Math.max(480, Math.min(680, screen ? screen.height - 88 : 680))
    minimumSize: Qt.size(600, 480)
    fullscreen: Store.deviceSettingsFullscreen
    color: Theme.background
    property bool syncingPage: false
    property string loadedKind: ""
    readonly property var categories: [
        {key:"wifi", label:"Wi-Fi", symbol:"\ue63e"},
        {key:"bluetooth", label:"Bluetooth", symbol:"\ue1a7"},
        {key:"audio", label:"Audio", symbol:"\ue050"},
        {key:"power", label:"Battery & power", symbol:"\uf304"}
    ]
    readonly property var category: categories.find(item => item.key === Store.deviceSettingsKind) || categories[0]
    readonly property var features: Store.deviceSettingsKind === "wifi" ? [
        {key:"networks", label:"Networks"}, {key:"hidden", label:"Add Wi-Fi"},
        {key:"details", label:"Details"}, {key:"dns", label:"DNS"}, {key:"sharing", label:"QR sharing"}
    ] : Store.deviceSettingsKind === "audio" ? [
        {key:"applications", label:"Applications"}, {key:"output", label:"Speakers"},
        {key:"microphone", label:"Microphone"}
    ] : Store.deviceSettingsKind === "bluetooth" ? [{key:"devices", label:"Devices"}]
        : [{key:"status", label:"Status & profiles"}]

    function selectFeature(section) {
        if (!features.some(item => item.key === section)) return;
        if (Store.deviceSettingsSection === section) syncPage();
        else Store.deviceSettingsSection = section;
    }
    function scrollToSection() {
        const page = pageLoader.item;
        if (!page || loadedKind !== Store.deviceSettingsKind) return;
        const offset = page.sectionOffset ? page.sectionOffset(Store.deviceSettingsSection) : 0;
        contentView.contentY = Math.max(0, Math.min(offset, contentView.contentHeight - contentView.height));
    }
    function syncPage() {
        const page = pageLoader.item;
        if (!page || loadedKind !== Store.deviceSettingsKind) return;
        syncingPage = true;
        if (loadedKind === "wifi") {
            page.resetState();
            page.showAdvancedNavigation = false;
            page.advancedOpen = Store.deviceSettingsSection !== "networks";
            page.hiddenOpen = Store.deviceSettingsSection === "hidden";
        }
        syncingPage = false;
        Qt.callLater(scrollToSection);
    }
    function syncWifiSelection() {
        if (syncingPage || loadedKind !== "wifi" || !pageLoader.item) return;
        const page = pageLoader.item;
        const next = !page.advancedOpen ? "networks" : page.hiddenOpen ? "hidden" : "details";
        if (next !== Store.deviceSettingsSection) Store.deviceSettingsSection = next;
    }
    function close() { Store.closeDeviceSettings(); }

    onVisibleChanged: {
        if (visible) {
            if (!fullscreen) floatDelay.restart();
        } else Store.closeDeviceSettings();
    }
    onFullscreenChanged: if (visible && !fullscreen) floatDelay.restart()
    Component.onCompleted: if (visible && !fullscreen) floatDelay.restart()
    Connections {
        target: Store
        function onDeviceSettingsSectionChanged() { root.syncPage(); }
    }
    Connections {
        target: pageLoader.item
        ignoreUnknownSignals: true
        function onAdvancedOpenChanged() { root.syncWifiSelection(); }
        function onHiddenOpenChanged() { root.syncWifiSelection(); }
    }
    Timer {
        id: floatDelay
        interval: 320
        onTriggered: if (root.visible && !root.fullscreen && !floatHelper.running) floatHelper.running = true
    }
    Process {
        id: floatHelper
        command: ["python3", Quickshell.shellPath("scripts/rustiq-settings-float.py"), "--device-settings"]
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.sectionGap
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.maximumHeight: 48
            Layout.fillHeight: false
            Icon { icon: root.category.symbol; color: Theme.accent; font.pixelSize: Fonts.scale(24) }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 2
                    Text { text: root.category.label + " settings"; color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(18) }
                    Text { text: "Advanced controls"; color: Theme.muted; font.family: Fonts.poppins.name; font.pixelSize: Theme.helperTextSize }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.SizeAllCursor; onPressed: root.startSystemMove() }
            }
            Rectangle {
                objectName: "toggleDeviceFullscreen"
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                radius: Theme.rowRadius; color: Theme.surface
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: root.fullscreen ? "Exit fullscreen" : "Enter fullscreen"
                function toggle() { Store.deviceSettingsFullscreen = !root.fullscreen; }
                Accessible.onPressAction: toggle()
                Keys.onReturnPressed: toggle()
                Keys.onSpacePressed: toggle()
                Icon { anchors.centerIn: parent; icon: root.fullscreen ? "\ue5d1" : "\ue5d0"; color: Theme.foreground; font.pixelSize: Fonts.scale(18) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.toggle() }
            }
            Rectangle {
                objectName: "closeDeviceSettings"
                Layout.preferredWidth: 32; Layout.preferredHeight: 32
                radius: Theme.rowRadius; color: Theme.surface
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Close device settings"
                Accessible.onPressAction: root.close()
                Keys.onReturnPressed: root.close()
                Keys.onSpacePressed: root.close()
                Icon { anchors.centerIn: parent; icon: "\ue5cd"; color: Theme.foreground; font.pixelSize: Fonts.scale(18) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: root.categories
                delegate: Rectangle {
                    id: categoryButton
                    required property var modelData
                    objectName: "deviceCategory_" + modelData.key
                    Layout.fillWidth: true; Layout.preferredHeight: 35
                    radius: Theme.rowRadius
                    color: Store.deviceSettingsKind === modelData.key ? Qt.alpha(Theme.accent, 0.17) : Theme.surface
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label + " settings"
                    function select() { Store.openDeviceSettings(modelData.key, root.screen, "", root.fullscreen); }
                    Accessible.onPressAction: select()
                    Keys.onReturnPressed: select()
                    Keys.onSpacePressed: select()
                    Text { anchors.centerIn: parent; text: categoryButton.modelData.label; color: Store.deviceSettingsKind === categoryButton.modelData.key ? Theme.accent : Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Theme.helperTextSize }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: categoryButton.select() }
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: implicitHeight
            spacing: 6
            Repeater {
                model: root.features
                delegate: Rectangle {
                    id: featureButton
                    required property var modelData
                    objectName: "deviceFeature_" + modelData.key
                    width: featureLabel.implicitWidth + 24; height: 31
                    radius: Theme.rowRadius
                    color: Store.deviceSettingsSection === modelData.key ? Qt.alpha(Theme.accent, 0.17) : Theme.surface
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.label
                    Accessible.onPressAction: root.selectFeature(modelData.key)
                    Keys.onReturnPressed: root.selectFeature(modelData.key)
                    Keys.onSpacePressed: root.selectFeature(modelData.key)
                    Text { id: featureLabel; anchors.centerIn: parent; text: featureButton.modelData.label; color: Store.deviceSettingsSection === featureButton.modelData.key ? Theme.accent : Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Theme.helperTextSize }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectFeature(featureButton.modelData.key) }
                }
            }
        }
        Flickable {
            id: contentView
            objectName: "deviceSettingsScroll"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 160
            clip: true
            contentWidth: width
            contentHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Loader {
                id: pageLoader
                objectName: "deviceSettingsPageLoader"
                width: contentView.width
                active: root.visible
                sourceComponent: Store.deviceSettingsKind === "wifi" ? wifiPage
                    : Store.deviceSettingsKind === "audio" ? audioPage
                    : Store.deviceSettingsKind === "bluetooth" ? bluetoothPage : powerPage
                onLoaded: { root.loadedKind = Store.deviceSettingsKind; root.syncPage(); }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Rectangle {
                objectName: "deviceSettingsBack"
                Layout.preferredWidth: 88; Layout.preferredHeight: 32
                radius: Theme.rowRadius; color: Theme.surface
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Back"
                function back() {
                    if (Store.deviceSettingsSection !== root.features[0].key) root.selectFeature(root.features[0].key);
                    else root.close();
                }
                Accessible.onPressAction: back()
                Keys.onReturnPressed: back()
                Keys.onSpacePressed: back()
                Text { anchors.centerIn: parent; text: "← Back"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: Theme.helperTextSize }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.back() }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 116; Layout.preferredHeight: 32
                radius: Theme.rowRadius; color: Theme.surface
                Text { anchors.centerIn: parent; text: "Full settings"; color: Theme.accent; font.family: Fonts.poppinsSB.name; font.pixelSize: Theme.helperTextSize }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                    const kind = Store.deviceSettingsKind;
                    const screen = root.screen;
                    Store.closeDeviceSettings();
                    Store.showSettings(kind, screen);
                } }
            }
        }
    }
    Component { id: wifiPage; SettingsWifiPage { popupScreen: root.screen } }
    Component { id: audioPage; SettingsAudioPage { targetScreen: root.screen } }
    Component { id: bluetoothPage; SettingsBluetoothPage { targetScreen: root.screen } }
    Component { id: powerPage; SettingsPowerPage { targetScreen: root.screen } }
}
