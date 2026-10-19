import QtQuick
import QtQuick.Layouts
import "../../../config"
import "../../../components"

// Dual-target drag editor: drop on a tile's center to SWAP two exact slots,
// or drop at its edge/between tiles to INSERT and shift adjacent tiles.
// Draw both previews above the Flow without reflowing the icons mid-drag.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 10
    readonly property var entries: [
        {key:"rusticq", name:"RusticQ", icon:"\ue8b8"},
        {key:"arch", name:"Arch / AI", icon:"\uf371"},
        {key:"launcher", name:"Launcher", icon:"\ue8b6"},
        {key:"menu", name:"Menu", icon:"\ue5d2"},
        {key:"workspaces", name:"Workspaces", icon:"\ue30b"},
        {key:"weather", name:"Weather", icon:"\ue430"},
        {key:"time", name:"Clock", icon:"\ue8b5"},
        {key:"date", name:"Calendar", icon:"\uebcc"},
        {key:"bluetooth", name:"Bluetooth", icon:"\ue1a7"},
        {key:"wifi", name:"Wi-Fi", icon:"\ue63e"},
        {key:"battery", name:"Battery", icon:"\uf304"},
        {key:"audio", name:"Volume", icon:"\ue050"},
        {key:"notifications", name:"Notifications", icon:"\ue7f4"},
        {key:"task", name:"Task view", icon:"\ue322"},
        {key:"quickModes", name:"Quick Modes", icon:"\ue429"},
        {key:"quickControl", name:"Quick Control", icon:"\ue69b"},
        {key:"mic", name:"Microphone", icon:"\ue029"},
        {key:"down", name:"Download", icon:"\ue5db"},
        {key:"up", name:"Upload", icon:"\ue5d8"}
    ]
    function details(key) {
        const match = entries.find(item => item.key === key);
        return match || {key:key,name:key,icon:"\ue8b8"};
    }
    function moveBy(key, diff) {
        const zone = SettingsStore.placementFor(key);
        const order = SettingsStore.iconsInZone(zone);
        const i = order.indexOf(key);
        if (i < 0) return;
        if (diff < 0 && i > 0) SettingsStore.moveBarIcon(key, zone, order[i - 1]);
        if (diff > 0 && i < order.length - 1)
            SettingsStore.moveBarIcon(key, zone, i + 2 < order.length ? order[i + 2] : "");
    }
    // Editor state is ephemeral: never persist the hovered slot to SettingsStore.
    property string draggingKey: ""
    property string previewZone: ""
    property string previewKind: "" // "insert" or "swap"
    property string previewBeforeKey: ""
    property string previewSwapKey: ""
    property real previewX: 0
    property real previewY: 0

    // Resolve all three Flow rows using actual mapped geometry, not indices.
    // The inner ~60% of a tile is the swap target; edges and gaps insert.
    // Exclude the dragged tile so hovering its old slot never swaps with itself.
    function findSlot(key, pointX, pointY) {
        if (SettingsStore.barIconKeys.indexOf(key) < 0) return null;
        for (let zi = 0; zi < zoneRepeater.count; ++zi) {
            const panel = zoneRepeater.itemAt(zi);
            if (!panel) continue;
            const panelRect = panel.mapToItem(root, 0, 0);
            if (pointX < panelRect.x || pointX > panelRect.x + panel.width ||
                pointY < panelRect.y || pointY > panelRect.y + panel.height)
                continue;
            const others = [];
            for (let ti = 0; ti < panel.tileCount(); ++ti) {
                const tile = panel.tileAt(ti);
                if (!tile || tile.iconKey === key) continue;
                const pos = tile.mapToItem(root, 0, 0);
                others.push({key:tile.iconKey, x:pos.x, y:pos.y,
                             width:tile.width, height:tile.height});
            }
            if (!others.length) {
                const origin = panel.dropOrigin();
                return {kind:"insert", zone:panel.modelData.zone, beforeKey:"",
                        x:origin.x + 3, y:origin.y + 2};
            }
            // A hover over the central body of a different icon chooses SWAP.
            // This takes precedence over the nearest insertion boundary.
            for (const item of others) {
                if (pointX >= item.x + item.width * .20 &&
                    pointX <= item.x + item.width * .80 &&
                    pointY >= item.y + item.height * .18 &&
                    pointY <= item.y + item.height * .82) {
                    return {kind:"swap", zone:panel.modelData.zone,
                            targetKey:item.key, beforeKey:"", x:item.x, y:item.y};
                }
            }
            let chosen = null;
            let nearest = Infinity;
            for (let ti = 0; ti < others.length; ++ti) {
                const item = others[ti];
                const centerY = item.y + item.height / 2;
                // Both boundaries of each tile are eligible. When the tile
                // is the final one in a wrapped row, its AFTER slot remains
                // visible at the row edge, while the next tile has its own
                // BEFORE slot on the following line.
                const slots = [
                    {x:item.x - 4, beforeKey:item.key},
                    {x:item.x + item.width + 4,
                     beforeKey:ti + 1 < others.length ? others[ti + 1].key : ""}
                ];
                for (const slot of slots) {
                    const dx = pointX - slot.x;
                    const dy = pointY - centerY;
                    const score = dx * dx + 2.5 * dy * dy;
                    if (score < nearest) {
                        nearest = score;
                        chosen = {kind:"insert", zone:panel.modelData.zone,
                                  beforeKey:slot.beforeKey, x:slot.x, y:item.y + 3};
                    }
                }
            }
            return chosen;
        }
        return null;
    }
    function updateDrop(key, pointX, pointY) {
        if (!draggingKey || draggingKey !== key) return;
        const slot = findSlot(key, pointX, pointY);
        if (!slot) {
            previewKind = "";
            previewZone = "";
            previewBeforeKey = "";
            previewSwapKey = "";
            return;
        }
        previewKind = slot.kind;
        previewZone = slot.zone;
        previewBeforeKey = slot.beforeKey || "";
        previewSwapKey = slot.targetKey || "";
        previewX = slot.x;
        previewY = slot.y;
    }
    function finishDrop(key, pointX, pointY) {
        // The final mouse position wins, including a release after crossing a
        // zone boundary or scrolling to another row.
        updateDrop(key, pointX, pointY);
        const kind = previewKind;
        const zone = previewZone;
        const before = previewBeforeKey;
        const swapTarget = previewSwapKey;
        draggingKey = "";
        previewKind = "";
        previewZone = "";
        previewBeforeKey = "";
        previewSwapKey = "";
        if (!zone) return false;
        // Center of another tile: both cards exchange their existing slots.
        // The store preserves separate zone positions and spacing per bar mode.
        if (kind === "swap" && swapTarget && swapTarget !== key)
            return SettingsStore.swapBarIcons(key, swapTarget);
        // Between tiles or at a tile edge: insert at the caret, shifting peers.
        if (kind === "insert")
            return SettingsStore.moveBarIcon(key, zone, before);
        return false;
    }
    RowLayout {
        Layout.fillWidth: true; spacing: 8
        ColumnLayout {
            Layout.fillWidth: true; spacing: 2
            Text { text: "Drag to insert or swap · " + SettingsStore.barMode
                color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(12) }
            Text { Layout.fillWidth: true
                text: "Drop in a gap or near an icon edge to INSERT (accent caret); drop at the center of an icon to SWAP (highlighted card). Works across Left / Center / Right."
                color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap }
        }
        Rectangle {
            Layout.preferredWidth: 90; Layout.preferredHeight: 32
            radius: 9; color: Theme.background
            Text { anchors.centerIn: parent; text: "Reset mode"; color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: SettingsStore.resetIconPlacements() }
        }
    }
    Repeater {
        id: zoneRepeater
        model: [
            {zone:"left",title:"Left / Top"},
            {zone:"center",title:"Center"},
            {zone:"right",title:"Right / Bottom"}
        ]
        delegate: Rectangle {
            id: zonePanel
            required property var modelData
            readonly property var items: SettingsStore.iconsInZone(modelData.zone)
            function tileAt(index) { return zoneTiles.itemAt(index); }
            function tileCount() { return zoneTiles.count; }
            function dropOrigin() { return chips.mapToItem(root, 0, 0); }
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(88, zoneContents.implicitHeight + 23)
            radius: 12
            color: Theme.background
            border.color: Theme.borderaccent
            border.width: 1
            // Persistent-on-hover insertion placeholder. Draw it *over* the
            // Flow instead of adding an item to Flow: the tiles must not reflow
            // before the user actually drops the dragged icon.
            Rectangle {
                id: insertPlaceholder
                visible: root.draggingKey.length > 0 &&
                         root.previewKind === "insert" &&
                         root.previewZone === zonePanel.modelData.zone
                z: 900
                width: 14
                height: 69
                radius: 6
                color: Qt.alpha(Theme.accent, 0.20)
                border.color: Theme.accent
                border.width: 1
                x: zonePanel.mapFromItem(root, root.previewX, root.previewY).x - width / 2
                y: zonePanel.mapFromItem(root, root.previewX, root.previewY).y - 2
                Rectangle {
                    width: 4; height: parent.height - 9; radius: 2
                    anchors.centerIn: parent
                    color: Theme.accent
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top; anchors.topMargin: -2
                    color: Theme.accent
                }
                Rectangle {
                    width: 8; height: 8; radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: -2
                    color: Theme.accent
                }
            }
            ColumnLayout {
                id: zoneContents
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 11; spacing: 8
                RowLayout {
                    Layout.fillWidth: true; spacing: 7
                    Icon { icon: "\ue5d3"; color: Theme.accent; font.pixelSize: Fonts.scale(14) }
                    Text { text: zonePanel.modelData.title; Layout.fillWidth: true
                        color: Theme.foreground; font.family: Fonts.poppinsSB.name; font.pixelSize: Fonts.scale(11) }
                    Text { text: String(zonePanel.items.length) + " icons"
                        color: Theme.muted; font.pixelSize: Fonts.scale(10) }
                }
                Flow {
                    id: chips
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        id: zoneTiles
                        model: zonePanel.items
                        delegate: Rectangle {
                            id: tile
                            required property string modelData
                            readonly property string iconKey: modelData
                            readonly property var iconInfo: root.details(modelData)
                            width: 133; height: 70
                            radius: 10
                            readonly property bool swapTarget: root.draggingKey.length > 0 &&
                                root.previewKind === "swap" &&
                                root.previewZone === zonePanel.modelData.zone &&
                                root.previewSwapKey === tile.iconKey
                            color: tileDrag.active ? Qt.alpha(Theme.accent, .24) :
                                   swapTarget ? Qt.alpha(Theme.accent, .26) : Theme.surface
                            border.color: (tileDrag.active || swapTarget) ? Theme.accent : "transparent"
                            border.width: (tileDrag.active || swapTarget) ? 2 : 0
                            z: tileDrag.active ? 100 : swapTarget ? 10 : 0
                            opacity: tileDrag.active ? .75 : 1
                            DragHandler {
                                id: tileDrag
                                acceptedButtons: Qt.LeftButton
                                target: tile
                                property real previousX: 0
                                property real previousY: 0
                                onActiveChanged: {
                                    if (active) {
                                        previousX = tile.x;
                                        previousY = tile.y;
                                        root.draggingKey = tile.iconKey;
                                        const first = tile.mapToItem(root, tile.width/2, tile.height/2);
                                        root.updateDrop(tile.iconKey, first.x, first.y);
                                    } else if (root.draggingKey === tile.iconKey) {
                                        const point = tile.mapToItem(root, tile.width/2, tile.height/2);
                                        tile.x = previousX;
                                        tile.y = previousY;
                                        root.finishDrop(tile.iconKey, point.x, point.y);
                                    }
                                }
                                onTranslationChanged: {
                                    if (active) {
                                        const point = tile.mapToItem(root, tile.width/2, tile.height/2);
                                        root.updateDrop(tile.iconKey, point.x, point.y);
                                    }
                                }
                            }
                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 3
                                Icon { Layout.alignment: Qt.AlignHCenter; icon: tile.iconInfo.icon
                                    color: Theme.accent; font.pixelSize: Fonts.scale(17) }
                                Text { Layout.alignment: Qt.AlignHCenter; text: tile.iconInfo.name
                                    color: Theme.foreground; font.pixelSize: Fonts.scale(10) }
                            }
                            // Explicit SWAP affordance. Do not show the insertion caret
                            // over a target that would exchange the two icons instead.
                            Rectangle {
                                visible: tile.swapTarget
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.top: parent.top
                                anchors.topMargin: 4
                                width: 44; height: 18
                                radius: 5
                                color: Theme.accent
                                z: 11
                                Text {
                                    anchors.centerIn: parent
                                    text: "↔ Swap"
                                    color: Theme.background
                                    font.family: Fonts.poppinsSB.name
                                    font.pixelSize: Fonts.scale(9)
                                }
                            }
                            // Keyboard/mouse fallback for precision and accessibility.
                            Row {
                                anchors.right: parent.right; anchors.top: parent.top
                                anchors.rightMargin: 3; anchors.topMargin: 3; spacing: 2
                                Repeater {
                                    model: [{label:"‹",diff:-1},{label:"›",diff:1}]
                                    delegate: Rectangle {
                                        id: moveButton
                                        required property var modelData
                                        width: 20; height: 20; radius: 5
                                        color: Qt.alpha(Theme.accent,.12)
                                        Text { anchors.centerIn: parent; text: moveButton.modelData.label
                                            color: Theme.accent; font.pixelSize: Fonts.scale(11) }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.moveBy(tile.iconKey, moveButton.modelData.diff) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Text { Layout.fillWidth: true
        text: "Two drop actions: BETWEEN cards = insert with caret (other icons shift). ON a card's center = swap both cards. The ‹ / › buttons still allow precise moves."
        color: Theme.muted; font.pixelSize: Fonts.scale(10); wrapMode: Text.WordWrap }
}
