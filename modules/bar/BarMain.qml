import QtQuick
import QtQuick.Layouts
import "../../config"
import "../../components"
import "../../services"

// One ordered list is shared with user-settings.json. The drag grip appears
// only in 'reorder' mode; normal use keeps every section at full width.
Item {
    id: root
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    function dragTarget(y) {
        for (let i = 0; i < orderedCards.count; ++i) {
            const item = orderedCards.itemAt(i);
            if (item && y < item.y + item.height / 2) return i;
        }
        return Math.max(0, orderedCards.count - 1);
    }

    Flickable {
        id: quickScroll
        anchors.fill: parent
        visible: !Store.advancedVisible
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: sectionColumn.implicitHeight + 2

        ColumnLayout {
            id: sectionColumn
            width: quickScroll.width
            spacing: Theme.sectionGap

            RowLayout {
                visible: Store.quickReorderMode
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 40 : 0
                spacing: 8
                Text {
                    text: "Drag the handles to reorder sections"
                    Layout.fillWidth: true
                    color: Theme.muted
                    font.family: Fonts.poppins.name
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 28
                    radius: 9
                    color: Theme.surface
                    Text { anchors.centerIn: parent; text: "Reset"; color: Theme.foreground; font.family: Fonts.poppins.name; font.pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsStore.resetQuickOrder() }
                }
            }

            Repeater {
                id: orderedCards
                model: SettingsStore.quickControlOrder
                delegate: Item {
                    id: orderedCard
                    required property string modelData
                    required property int index
                    readonly property bool isVisibleCard: modelData !== "notifications" || SettingsStore.showNotifications
                    readonly property real openedHeight: {
                        const widget = cardLoader.item;
                        if (modelData === "wifi") return widget && widget.expanded ? Math.max(310, Math.min(480, root.height * 0.47)) : 64;
                        if (modelData === "bluetooth") return widget && widget.expanded ? 336 : 68;
                        if (modelData === "battery") return widget && widget.expanded ? 366 : 68;
                        if (modelData === "notifications") return widget && widget.expanded ? Math.min(475, Math.max(320, 205 + NotificationCenter.history.length * 78 + (NotificationCenter.receivesSystemNotifications ? 0 : 130))) : 66;
                        return 372;
                    }
                    readonly property bool highlighted: Store.quickReorderMode && root.dragSelection === index
                    Layout.fillWidth: true
                    Layout.preferredHeight: isVisibleCard ? openedHeight : 0
                    visible: isVisibleCard
                    property real startY: 0
                    Loader {
                        id: cardLoader
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: Store.quickReorderMode ? 22 : 0
                        sourceComponent: orderedCard.modelData === "wifi" ? wifiSection
                            : orderedCard.modelData === "bluetooth" ? bluetoothSection
                            : orderedCard.modelData === "battery" ? batterySection
                            : orderedCard.modelData === "system" ? systemSection
                            : notificationsSection
                    }
                    Rectangle {
                        visible: Store.quickReorderMode
                        anchors.left: cardLoader.left
                        anchors.right: cardLoader.right
                        anchors.top: cardLoader.top
                        anchors.bottom: cardLoader.bottom
                        color: "transparent"
                        radius: Theme.sectionRadius
                        border.width: orderedCard.highlighted ? 2 : 0
                        border.color: Theme.accent
                        z: 1
                    }
                    Rectangle {
                        id: grip
                        visible: Store.quickReorderMode
                        x: 0
                        y: Math.max(8, (orderedCard.height - 44) / 2)
                        width: 21
                        height: 44
                        radius: 9
                        color: grabArea.pressed ? Qt.alpha(Theme.accent, .26) : Theme.surface
                        border.width: 0
                        Icon { anchors.centerIn: parent; icon: "\ue8d5"; color: Theme.accent; font.pixelSize: 18 }
                        MouseArea {
                            id: grabArea
                            anchors.fill: parent
                            cursorShape: Qt.OpenHandCursor
                            preventStealing: true
                            onPressed: mouse => {
                                orderedCard.startY = grabArea.mapToItem(sectionColumn, mouse.x, mouse.y).y;
                                root.dragSelection = orderedCard.index;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                const pos = grabArea.mapToItem(sectionColumn, mouse.x, mouse.y);
                                root.dragSelection = root.dragTarget(pos.y);
                            }
                            onReleased: mouse => {
                                const pos = grabArea.mapToItem(sectionColumn, mouse.x, mouse.y);
                                const targetIndex = root.dragTarget(pos.y);
                                root.dragSelection = -1;
                                SettingsStore.moveQuickCard(orderedCard.modelData, targetIndex);
                            }
                            onCanceled: root.dragSelection = -1
                        }
                    }
                }
            }
        }
    }
    property int dragSelection: -1
    Component { id: wifiSection; BarWifi { onExpandedChanged: if (expanded) quickScroll.contentY = 0 } }
    Component { id: bluetoothSection; BarBluetooth {} }
    Component { id: batterySection; BarBattery {} }
    Component { id: systemSection; BarSystem {} }
    Component { id: notificationsSection; BarNotifications {} }

    BarAdvanced {
        anchors.fill: parent
        visible: Store.advancedVisible
    }
}
