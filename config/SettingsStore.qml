pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Small persistent, non-secret UI settings. Never store API keys here.
Singleton {
    id: root
    property string accentName: "orange"
    // Explicit opt-in: keep original Gruvbox when Aether is unavailable.
    property string colorSource: "gruvbox"
    property string barMode: "separated"
    property string barPosition: "top"
    property bool absoluteCenter: true
    property int centerOffsetX: 0
    property string uiFontFamily: "poppins"
    property string uiCustomFont: ""
    property real uiFontScale: 1.0
    property string uiDensity: "comfortable"
    // Desktop-level presets intentionally do not force privileged power profiles,
    // lock/idle settings, wallpaper services, or third-party theme agents.
    property string desktopProfile: "custom"
    property var desktopProfilePrevious: ({})
    readonly property var desktopProfileKeys: ["barMode", "showNotifications", "desktopSystem", "showDock", "uiDensity", "launcherLayoutMode"]
    readonly property var desktopProfilePresets: ({
        coding: {barMode:"compact", showNotifications:true, desktopSystem:true, showDock:true, uiDensity:"compact", launcherLayoutMode:"compact"},
        gaming: {barMode:"simple", showNotifications:false, desktopSystem:false, showDock:false, uiDensity:"compact", launcherLayoutMode:"compact"},
        battery: {barMode:"simple", showNotifications:true, desktopSystem:false, showDock:false, uiDensity:"compact", launcherLayoutMode:"clean-hover"},
        presentation: {barMode:"clean-compact", showNotifications:false, desktopSystem:false, showDock:false, uiDensity:"comfortable", launcherLayoutMode:"clean-hover"}
    })
    function applyDesktopProfile(profile) {
        if (!Object.prototype.hasOwnProperty.call(desktopProfilePresets, profile)) return false;
        const previous = {};
        for (const key of desktopProfileKeys) previous[key] = root[key];
        // Snapshot only when entering a preset from a non-preset state.
        if (desktopProfile === "custom" || !desktopProfilePrevious || !Object.keys(desktopProfilePrevious).length)
            desktopProfilePrevious = previous;
        const data = desktopProfilePresets[profile];
        for (const key of desktopProfileKeys) root[key] = data[key];
        desktopProfile = profile;
        save();
        return true;
    }
    function restoreDesktopProfile() {
        if (desktopProfile === "custom") return;
        if (desktopProfilePrevious && Object.keys(desktopProfilePrevious).length) {
            for (const key of desktopProfileKeys) {
                const value = desktopProfilePrevious[key];
                if (key === "barMode" && spacingModes.indexOf(value) < 0) continue;
                if (key === "uiDensity" && ["compact", "comfortable"].indexOf(value) < 0) continue;
                if (key === "launcherLayoutMode" && ["compact", "clean-hover"].indexOf(value) < 0) continue;
                if (typeof value === "boolean" || typeof value === "string") root[key] = value;
            }
        }
        desktopProfile = "custom";
        desktopProfilePrevious = ({});
        save();
    }
    property string wallpaperPath: ""
    property string wallpaperBackend: "auto"
    // RusticQ Native Lock uses WlSessionLock/PAM; the original Omarchy lock/idle
    // configuration stays untouched. Solid is safest for privacy by default.
    property string lockscreenBackground: "solid" // solid | wallpaper
    property bool showNotifications: true
    property bool showLauncher: true
    property bool showRusticQIcon: true
    // App launcher geometry and density (persisted; monitor size is still clamped).
    property string launcherLayoutMode: "compact" // compact | clean-hover
    property int launcherWidth: 660
    property int launcherHeight: 605
    property int launcherIconSize: 30
    property int launcherRowHeight: 56
    property int launcherFavoriteColumns: 3
    function updateLauncherSize(key, value, persist) {
        const limits = {
            launcherWidth: [440, 1000], launcherHeight: [360, 850],
            launcherIconSize: [20, 64], launcherRowHeight: [50, 92],
            launcherFavoriteColumns: [2, 5]
        };
        if (!limits[key] || !Number.isFinite(value)) return;
        root[key] = Math.max(limits[key][0], Math.min(limits[key][1], Math.round(value)));
        if (persist !== false) save();
    }
    function resetLauncherSize() {
        launcherWidth = 660;
        launcherHeight = 605;
        launcherIconSize = 30;
        launcherRowHeight = 56;
        launcherFavoriteColumns = 3;
        save();
    }
    property bool showTaskView: true
    property bool desktopCalendar: false
    property bool desktopSystem: false
    property bool desktopClock: false
    property bool desktopMedia: false
    property bool desktopWeather: false
    property bool desktopNotes: false
    property bool desktopKanban: false
    property bool desktopRandomImage: false
    property string widgetImageFolder: "" // Empty: user Pictures folder, nothing fetched online.
    property int widgetImageRotateSeconds: 0 // 0 = manual only; 60 / 300 / 900 allowed
    property bool desktopConnectivity: false
    // Per-monitor widget positions in normalized available screen space (0..1).
    // Opt-in per-workspace visibility. Widget windows remain on the Bottom
    // layer; they are hidden on every nonselected workspace of their monitor.
    // Default WS1 for freshly activated interactive widgets.
    property var widgetWorkspaceScopes: ({notes:[1], kanban:[1], randomImage:[1]})
    function widgetAllowedOnWorkspace(kind, workspace) {
        if (!Number.isInteger(workspace) || workspace < 1) return false;
        const scope = widgetWorkspaceScopes[kind];
        return Array.isArray(scope) && scope.indexOf(workspace) !== -1;
    }
    function setWidgetWorkspace(kind, workspace, show) {
        if (["notes", "kanban", "randomImage"].indexOf(kind) < 0 ||
            !Number.isInteger(workspace) || workspace < 1 || workspace > 10) return;
        const next = Object.assign({}, widgetWorkspaceScopes);
        const arr = Array.isArray(next[kind]) ? next[kind].slice() : [1];
        const at = arr.indexOf(workspace);
        if (show && at < 0) arr.push(workspace);
        if (!show && at >= 0) arr.splice(at, 1);
        next[kind] = arr.sort((a,b)=>a-b);
        widgetWorkspaceScopes = next;
        save();
    }
    // A plain-text scratchpad per monitor/workspace, independent of the task
    // board backend. Stored locally with the normal existing settings file.
    property var workspaceNotes: ({})
    function workspaceNoteKey(monitor, workspace) {
        return String(monitor || "default") + ":" + String(workspace);
    }
    function workspaceNote(monitor, workspace) {
        return workspaceNotes[workspaceNoteKey(monitor, workspace)] || "";
    }
    function setWorkspaceNote(monitor, workspace, text) {
        if (!Number.isInteger(workspace) || workspace < 1 || workspace > 10 ||
            typeof text !== "string") return;
        const key = workspaceNoteKey(monitor, workspace);
        const all = Object.assign({}, workspaceNotes);
        all[key] = text.slice(0, 30000);
        workspaceNotes = all;
        save();
    }
    property var widgetSizes: ({})
    function widgetSize(kind, monitor, workspace) {
        return widgetSizes[widgetKey(kind, monitor) + ":" + String(workspace)] || null;
    }
    function setWidgetSize(kind, monitor, workspace, width, height) {
        if (["notes", "kanban", "randomImage"].indexOf(kind) < 0 ||
            !Number.isInteger(workspace) || workspace < 1 || workspace > 10 ||
            !Number.isFinite(width) || !Number.isFinite(height)) return;
        const all = Object.assign({}, widgetSizes);
        all[widgetKey(kind, monitor) + ":" + String(workspace)] = {
            width: Math.round(Math.max(250, Math.min(1050, width))),
            height: Math.round(Math.max(145, Math.min(800, height)))
        };
        widgetSizes = all;
        save();
    }
    property var widgetPositions: ({})
    function widgetKey(kind, monitor) { return String(monitor || "default") + ":" + kind; }
    function widgetPosition(kind, monitor, workspace) {
        const base = widgetKey(kind, monitor);
        if (Number.isInteger(workspace) && workspace > 0 && ["notes","kanban","randomImage"].indexOf(kind) >= 0)
            return widgetPositions[base + ":" + String(workspace)] || widgetPositions[base] || null;
        return widgetPositions[base] || null;
    }
    function setWidgetPosition(kind, monitor, x, y, workspace) {
        if (["clock", "calendar", "system", "media", "weather", "connectivity", "notes", "kanban", "randomImage"].indexOf(kind) < 0) return;
        if (!Number.isFinite(x) || !Number.isFinite(y)) return;
        const copy = Object.assign({}, widgetPositions);
        const perWorkspace = Number.isInteger(workspace) && workspace > 0 && ["notes","kanban","randomImage"].indexOf(kind) >= 0;
        const key = widgetKey(kind, monitor) + (perWorkspace ? ":" + String(workspace) : "");
        copy[key] = {x: Math.max(0, Math.min(1, x)), y: Math.max(0, Math.min(1, y))};
        widgetPositions = copy;
        save();
    }
    function resetWidgetPositions() { widgetPositions = ({}); save(); }
    property bool showDock: false
    property bool dockFiles: true
    property bool dockBrowser: true
    property bool dockSettings: true
    property bool dockTaskView: true
    property bool dockAI: true
    property bool dockRunningApps: false
    // User-controlled Quick Control card order, stored independently of layout modes.
    readonly property var defaultQuickOrder: ["wifi", "bluetooth", "battery", "system", "notifications"]
    property var quickControlOrder: ["wifi", "bluetooth", "battery", "system", "notifications"]
    function validQuickOrder(input) {
        if (!Array.isArray(input) || input.length !== defaultQuickOrder.length) return false;
        return input.every((v, i) => defaultQuickOrder.indexOf(v) >= 0 && input.indexOf(v) === i);
    }
    function moveQuickCard(kind, beforeIndex) {
        const order = quickControlOrder.slice();
        const from = order.indexOf(kind);
        const to = Math.max(0, Math.min(order.length - 1, Math.floor(beforeIndex)));
        if (from < 0 || from === to) return;
        order.splice(from, 1);
        order.splice(to, 0, kind);
        quickControlOrder = order;
        save();
    }
    function resetQuickOrder() { quickControlOrder = defaultQuickOrder.slice(); save(); }
    property bool dockAutoHide: true
    property bool showMenuBar: false // Optional RusticQ contextual menu; off by default
    // Edit, View and Share remain the default menu sections when enabled.
    property bool showMenuEdit: true
    property bool showMenuView: true
    property bool showMenuShare: true
    property bool showMenuFile: false
    property bool showMenuShell: false
    property bool showMenuTools: false
    // Clean Compact: optional detail labels only for the right-hand group.
    // Battery and volume values are always retained.
    property bool cleanRightDetails: true // RC2 migration compatibility
    // clean-compact labels: icons, details, or reveal all on group hover
    property string cleanRightMode: "details"
    // Per-mode edge margins. Empty means keep the original mode defaults.
    property var marginOverrides: ({})
    function marginFor(edge, fallback) {
        const mode = marginOverrides[barMode] || {};
        return typeof mode[edge] === "number" ? mode[edge] : fallback;
    }
    function setBarMargin(edge, value, persist) {
        if (["top", "bottom", "left", "right"].indexOf(edge) === -1) return;
        const all = Object.assign({}, marginOverrides);
        const current = Object.assign({}, all[barMode] || {});
        current[edge] = Math.max(0, Math.min(32, Math.round(value)));
        all[barMode] = current;
        marginOverrides = all; // replace object to notify QML bindings
        if (persist !== false) save();
    }
    function resetBarMargins() {
        const all = Object.assign({}, marginOverrides);
        delete all[barMode];
        marginOverrides = all;
        save();
    }
    // RC2: persistent alignment for every bar item, not only optional indicators.
    // On vertical bars Left / Center / Right map to top / middle / bottom.
    readonly property var barIconKeys: ["rusticq", "arch", "launcher", "menu", "workspaces", "weather", "time", "date",
        "bluetooth", "wifi", "battery", "audio", "notifications", "task", "quickModes", "quickControl", "mic", "down", "up"]
    readonly property var defaultBarPlacements: ({
        rusticq:"left", arch:"left", launcher:"left", menu:"left", workspaces:"left",
        weather:"right", time:"right", date:"right", bluetooth:"right", wifi:"right",
        battery:"right", audio:"right", notifications:"right", task:"right", quickModes:"right", quickControl:"right",
        mic:"right", down:"right", up:"right"
    })
    // v5: independent layout profiles. Legacy barIconPlacements is read ONLY for migration.
    property var barIconPlacements: ({})
    property var barIconPlacementsByMode: ({})
    // Optional order override for each layout; existing profiles retain the RC4 order.
    property var barIconOrderByMode: ({})
    function validateBarIconOrder(order) {
        if (!Array.isArray(order)) return false;
        // Preserve saved placements from releases before the dedicated bell icon.
        const legacy = order.length === barIconKeys.length - 1 && order.indexOf("notifications") < 0;
        if (!legacy && order.length !== barIconKeys.length) return false;
        return order.every((key, index) => barIconKeys.indexOf(key) >= 0 && order.indexOf(key) === index);
    }
    function normalizeBarOrder(order) {
        if (!validateBarIconOrder(order)) return barIconKeys.slice();
        const next = order.slice();
        if (next.indexOf("notifications") < 0) {
            const after = next.indexOf("audio");
            next.splice(after < 0 ? next.length : after + 1, 0, "notifications");
        }
        return next;
    }
    function validateBarIconOrders(data) {
        const clean = {};
        if (!data || typeof data !== "object" || Array.isArray(data)) return clean;
        for (const mode of spacingModes)
            if (validateBarIconOrder(data[mode])) clean[mode] = normalizeBarOrder(data[mode]);
        return clean;
    }
    function barOrder(modeName) {
        const saved = barIconOrderByMode[modeName || barMode];
        return normalizeBarOrder(saved);
    }
    // Swap positions of two tiles, including their Left/Center/Right zones.
    // A dragged tile occupies the target's old slot, and vice versa.
    function swapBarIcons(source, target) {
        if (source === target || barIconKeys.indexOf(source) < 0 ||
            barIconKeys.indexOf(target) < 0) return false;
        const fromZone = placementFor(source), toZone = placementFor(target);
        const order = barOrder().slice();
        const a = order.indexOf(source), b = order.indexOf(target);
        if (a < 0 || b < 0) return false;
        // Exchanging slots also exchanges zones. Keep zone-specific spacing
        // settings attached to the icon when moving between zones.
        if (fromZone !== toZone) {
            transferIconSpacing(source, fromZone, toZone, barMode);
            transferIconSpacing(target, toZone, fromZone, barMode);
            const allPlacements = Object.assign({}, barIconPlacementsByMode);
            const placements = Object.assign({}, allPlacements[barMode] || {});
            placements[source] = toZone;
            placements[target] = fromZone;
            allPlacements[barMode] = placements;
            barIconPlacementsByMode = allPlacements;
        }
        order[a] = target;
        order[b] = source;
        const allOrders = Object.assign({}, barIconOrderByMode);
        allOrders[barMode] = order;
        barIconOrderByMode = allOrders;
        if (fromZone !== toZone) {
            barIconMoved(source, toZone);
            barIconMoved(target, fromZone);
        }
        save();
        return true;
    }
    // Drop a tile before another tile or at the end of a zone. Persist order
    // separately from zone placement so rearranging cannot disable any icon.
    function moveBarIcon(key, zone, beforeKey) {
        if (barIconKeys.indexOf(key) < 0 || spacingZones.indexOf(zone) < 0) return false;
        if (beforeKey && (barIconKeys.indexOf(beforeKey) < 0 || beforeKey === key || placementFor(beforeKey) !== zone)) return false;
        const fromZone = placementFor(key);
        if (fromZone !== zone) {
            transferIconSpacing(key, fromZone, zone, barMode);
            const placements = Object.assign({}, barIconPlacementsByMode);
            const current = Object.assign({}, placements[barMode] || {});
            current[key] = zone;
            placements[barMode] = current;
            barIconPlacementsByMode = placements;
        }
        const order = barOrder().slice();
        order.splice(order.indexOf(key), 1);
        const at = beforeKey ? order.indexOf(beforeKey) : (() => {
            // Insert immediately after the final icon in the destination zone,
            // without affecting the relative order in any other zone.
            let last = -1;
            for (let i = 0; i < order.length; i++)
                if (placementFor(order[i]) === zone) last = i;
            return last + 1;
        })();
        order.splice(at, 0, key);
        const all = Object.assign({}, barIconOrderByMode);
        all[barMode] = order;
        barIconOrderByMode = all;
        if (fromZone !== zone) barIconMoved(key, zone);
        save();
        return true;
    }
    signal barIconMoved(string key, string zone)
    function placementFor(key) {
        if (barIconKeys.indexOf(key) < 0) return "right";
        const value = (barIconPlacementsByMode[barMode] || {})[key];
        return ["left", "center", "right"].indexOf(value) !== -1 ? value : defaultBarPlacements[key];
    }
    function transferIconSpacing(key, fromZone, toZone, onlyMode) {
        if (fromZone === toZone) return;
        const all = Object.assign({}, barSpacingOverrides);
        let changed = false;
        // Never move a different layout mode's spacing when relocating an icon.
        for (const modeName of (onlyMode ? [onlyMode] : spacingModes)) {
            const mode = Object.assign({}, all[modeName] || {});
            const from = Object.assign({}, mode[fromZone] || {});
            const fromItems = Object.assign({}, from.items || {});
            if (!Object.prototype.hasOwnProperty.call(fromItems, key)) continue;
            const to = Object.assign({}, mode[toZone] || {});
            const toItems = Object.assign({}, to.items || {});
            toItems[key] = fromItems[key];
            delete fromItems[key];
            changed = true;
            from.items = fromItems;
            to.items = toItems;
            mode[fromZone] = from;
            mode[toZone] = to;
            all[modeName] = mode;
        }
        if (changed) barSpacingOverrides = all;
    }
    function setIconPlacement(key, zone) {
        if (barIconKeys.indexOf(key) < 0 || ["left", "center", "right"].indexOf(zone) < 0) return;
        const fromZone = placementFor(key);
        if (fromZone === zone) return;
        transferIconSpacing(key, fromZone, zone, barMode);
        const all = Object.assign({}, barIconPlacementsByMode);
        const current = Object.assign({}, all[barMode] || {});
        current[key] = zone;
        all[barMode] = current;
        barIconPlacementsByMode = all;
        barIconMoved(key, zone);
        save();
    }
    function resetIconPlacements() {
        for (const key of barIconKeys)
            transferIconSpacing(key, placementFor(key), defaultBarPlacements[key], barMode);
        const all = Object.assign({}, barIconPlacementsByMode);
        delete all[barMode];
        barIconPlacementsByMode = all;
        const orders = Object.assign({}, barIconOrderByMode);
        delete orders[barMode];
        barIconOrderByMode = orders;
        save();
    }
    function validateIconPlacements(raw) {
        const clean = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return clean;
        for (const key of barIconKeys)
            if (["left", "center", "right"].indexOf(raw[key]) >= 0) clean[key] = raw[key];
        return clean;
    }
    function validateModePlacements(raw) {
        const clean = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return clean;
        for (const mode of spacingModes)
            if (raw[mode] && typeof raw[mode] === "object" && !Array.isArray(raw[mode]))
                clean[mode] = validateIconPlacements(raw[mode]);
        return clean;
    }
    // Manual spacing: three zones, independent for every bar layout mode.
    // All items share ONE registry; a relocated item is editable in its new zone.
    readonly property var spacingModes: ["compact", "clean-compact", "separated", "professional", "simple"]
    readonly property var spacingZones: ["left", "center", "right"]
    property var barSpacingOverrides: ({})
    function validSpacingItem(zone, key) {
        return spacingZones.indexOf(zone) >= 0 && barIconKeys.indexOf(key) >= 0;
    }
    function iconsInZone(zone) {
        return barOrder().filter(key => placementFor(key) === zone);
    }
    function spacingGroup(side, fallback) {
        const sideSettings = (barSpacingOverrides[barMode] || {})[side] || {};
        return Number.isInteger(sideSettings.gap) ? sideSettings.gap : fallback;
    }
    function spacingIcon(side, key, edge) {
        if (!validSpacingItem(side, key) || ["before", "after"].indexOf(edge) === -1) return 0;
        const record = (((barSpacingOverrides[barMode] || {})[side] || {}).items || {})[key] || {};
        return Number.isInteger(record[edge]) ? record[edge] : 0;
    }
    function setGroupSpacing(side, value, persist) {
        if (spacingZones.indexOf(side) < 0 || !Number.isFinite(value)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        group.gap = Math.max(0, Math.min(16, Math.round(value)));
        mode[side] = group; all[barMode] = mode; barSpacingOverrides = all;
        if (persist !== false) save();
    }
    function setIconSpacing(side, key, edge, value, persist) {
        if (!validSpacingItem(side, key) || ["before", "after"].indexOf(edge) < 0 || !Number.isFinite(value)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        const items = Object.assign({}, group.items || {});
        const item = Object.assign({}, items[key] || {});
        item[edge] = Math.max(0, Math.min(24, Math.round(value)));
        items[key] = item; group.items = items; mode[side] = group;
        all[barMode] = mode; barSpacingOverrides = all;
        if (persist !== false) save();
    }
    function resetIconSpacing(side, key) {
        if (!validSpacingItem(side, key)) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        const group = Object.assign({}, mode[side] || {});
        const items = Object.assign({}, group.items || {});
        delete items[key]; group.items = items; mode[side] = group;
        all[barMode] = mode; barSpacingOverrides = all; save();
    }
    function resetSideSpacing(side) {
        if (spacingZones.indexOf(side) < 0) return;
        const all = Object.assign({}, barSpacingOverrides);
        const mode = Object.assign({}, all[barMode] || {});
        delete mode[side]; all[barMode] = mode; barSpacingOverrides = all; save();
    }
    function validateSpacingOverrides(raw) {
        const result = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return result;
        for (const mode of spacingModes) {
            const sourceMode = raw[mode];
            if (!sourceMode || typeof sourceMode !== "object" || Array.isArray(sourceMode)) continue;
            const parsedMode = {};
            for (const side of spacingZones) {
                const source = sourceMode[side];
                if (!source || typeof source !== "object" || Array.isArray(source)) continue;
                const parsed = { items: {} };
                if (Number.isInteger(source.gap) && source.gap >= 0 && source.gap <= 16) parsed.gap = source.gap;
                for (const key of barIconKeys) {
                    const item = (source.items || {})[key];
                    if (!item || typeof item !== "object" || Array.isArray(item)) continue;
                    const value = {};
                    for (const edge of ["before", "after"])
                        if (Number.isInteger(item[edge]) && item[edge] >= 0 && item[edge] <= 24) value[edge] = item[edge];
                    if (Object.keys(value).length > 0) parsed.items[key] = value;
                }
                parsedMode[side] = parsed;
            }
            result[mode] = parsedMode;
        }
        return result;
    }
    // v5: display preferences are scoped to the selected BAR LAYOUT, not the device.
    // Keep global legacy show* properties so old settings files can migrate safely.
    readonly property var barVisibilityKeys: [
        "showRusticQIcon", "showLauncher", "showArch", "showWorkspaces", "showQuickControl", "showNotificationIcon",
        "showTaskView", "showWeather", "showTime", "showDate", "showWifi", "showBluetooth",
        "showBattery", "showAudio", "showMicrophoneStatus", "showDownloadSpeed",
        "showUploadSpeed", "showIndicators", "showMenuBar", "showMenuFile", "showMenuEdit",
        "showMenuView", "showMenuShare", "showMenuShell", "showMenuTools", "showQuickModes",
        "showKeepAwake", "showSilent", "showGamingMode", "showNightMode", "showMicMute"
    ]
    // The simple mode starts lean for fresh installations. Existing RC4 users keep
    // their current configuration through a one-time legacy migration below.
    readonly property var simpleHiddenIcons: [
        "showArch", "showTaskView", "showWeather", "showDate", "showBluetooth",
        "showMenuBar", "showMenuFile", "showMenuEdit", "showMenuView", "showMenuShare",
        "showMenuShell", "showMenuTools", "showQuickModes", "showMicrophoneStatus",
        "showDownloadSpeed", "showUploadSpeed"
    ]
    property var barIconVisibilityProfiles: ({})
    function modeIconVisible(key, modeName) {
        if (barVisibilityKeys.indexOf(key) < 0) return root[key] === true;
        const mode = modeName || barMode;
        const record = barIconVisibilityProfiles[mode] || {};
        if (typeof record[key] === "boolean") return record[key];
        if (mode === "simple" && simpleHiddenIcons.indexOf(key) >= 0) return false;
        return root[key] === true;
    }
    function setModeIconVisible(key, visible) {
        if (barVisibilityKeys.indexOf(key) < 0 || typeof visible !== "boolean") return;
        const all = Object.assign({}, barIconVisibilityProfiles);
        const record = Object.assign({}, all[barMode] || {});
        record[key] = visible;
        all[barMode] = record;
        barIconVisibilityProfiles = all;
        save();
    }
    function validateVisibilityProfiles(raw) {
        const clean = {};
        if (!raw || typeof raw !== "object" || Array.isArray(raw)) return clean;
        for (const mode of spacingModes) {
            const values = raw[mode];
            if (!values || typeof values !== "object" || Array.isArray(values)) continue;
            const record = {};
            for (const key of barVisibilityKeys)
                if (typeof values[key] === "boolean") record[key] = values[key];
            clean[mode] = record;
        }
        return clean;
    }
    function resetModeVisibility() {
        const all = Object.assign({}, barIconVisibilityProfiles);
        delete all[barMode];
        barIconVisibilityProfiles = all;
        save();
    }
    function useMinimalModePreset() {
        const keep = ["showRusticQIcon", "showLauncher", "showWorkspaces", "showTime",
            "showWifi", "showBattery", "showAudio", "showQuickControl", "showIndicators"];
        const record = {};
        for (const key of barVisibilityKeys)
            record[key] = keep.indexOf(key) >= 0;
        const all = Object.assign({}, barIconVisibilityProfiles);
        all[barMode] = record;
        barIconVisibilityProfiles = all;
        save();
    }
    function copyVisibilityFromMode(sourceMode) {
        if (spacingModes.indexOf(sourceMode) < 0 || sourceMode === barMode) return;
        const record = {};
        for (const key of barVisibilityKeys)
            record[key] = modeIconVisible(key, sourceMode);
        const all = Object.assign({}, barIconVisibilityProfiles);
        all[barMode] = record;
        barIconVisibilityProfiles = all;
        save();
    }
    // Individual bar modules/icons (all enabled initially, safely migrates RC1).
    property bool showArch: true
    property bool showTime: true
    property bool showDate: true
    property bool showWifi: true
    property bool showBluetooth: true
    property bool showBattery: true
    property bool showAudio: true
    property bool showQuickControl: true
    property bool showNotificationIcon: true
    property string quickControlButtonStyle: "plain" // plain | filled
    property bool showWeather: true
    property bool showWorkspaces: true
    property bool showIndicators: true
    property bool showQuickModes: true
    property bool quickModesAutoHide: true
    property bool showKeepAwake: true
    property bool showSilent: true
    property bool showGamingMode: true
    property bool showNightMode: true
    property bool showMicMute: true
    property bool showMicrophoneStatus: false
    property bool showDownloadSpeed: false
    property bool showUploadSpeed: false
    property string aiProvider: "openai"
    property string aiModel: "gpt-4.1-mini"
    readonly property color accentColor: accentName === "green" ? "#b8bb26" :
        accentName === "blue" ? "#83a598" :
        accentName === "purple" ? "#d3869b" : "#d65d0e"

    FileView {
        id: settingsFile
        path: Qt.resolvedUrl("../user-settings.json")
        blockLoading: true
    }
    Component.onCompleted: {
        try {
            const data = JSON.parse(settingsFile.text());
            if (["aether", "gruvbox"].indexOf(data.colorSource) !== -1) colorSource = data.colorSource;
            if (["orange", "green", "blue", "purple"].indexOf(data.accentName) !== -1)
                accentName = data.accentName;
            if (["compact", "clean-compact", "separated", "professional", "simple"].indexOf(data.barMode) !== -1) barMode = data.barMode;
            if (["top", "bottom", "left", "right"].indexOf(data.barPosition) !== -1) barPosition = data.barPosition;
            if (typeof data.absoluteCenter === "boolean") absoluteCenter = data.absoluteCenter;
            if (Number.isInteger(data.centerOffsetX) && data.centerOffsetX >= -400 && data.centerOffsetX <= 400) centerOffsetX = data.centerOffsetX;
            if (["poppins", "sans", "mono", "custom"].indexOf(data.uiFontFamily) >= 0) uiFontFamily = data.uiFontFamily;
            if (typeof data.uiCustomFont === "string" && data.uiCustomFont.length < 140) uiCustomFont = data.uiCustomFont;
            if (typeof data.uiFontScale === "number" && data.uiFontScale >= 0.85 && data.uiFontScale <= 1.2) uiFontScale = data.uiFontScale;
            if (["compact", "comfortable"].indexOf(data.uiDensity) >= 0) uiDensity = data.uiDensity;
            if (typeof data.wallpaperPath === "string" && data.wallpaperPath.length < 1024) wallpaperPath = data.wallpaperPath;
            if (["auto", "swww", "awww", "hyprpaper"].indexOf(data.wallpaperBackend) >= 0) wallpaperBackend = data.wallpaperBackend;
            if (["solid", "wallpaper"].indexOf(data.lockscreenBackground) >= 0) lockscreenBackground = data.lockscreenBackground;
            if (["icons", "details", "hover"].indexOf(data.cleanRightMode) !== -1)
                cleanRightMode = data.cleanRightMode;
            else if (typeof data.cleanRightDetails === "boolean")
                cleanRightMode = data.cleanRightDetails ? "details" : "icons";
            if (data.marginOverrides && typeof data.marginOverrides === "object" && !Array.isArray(data.marginOverrides)) {
                const validated = {};
                for (const mode of ["compact", "clean-compact", "separated", "professional", "simple"]) {
                    const m = data.marginOverrides[mode];
                    if (!m || typeof m !== "object" || Array.isArray(m)) continue;
                    const values = {};
                    for (const edge of ["top", "bottom", "left", "right"])
                        if (Number.isInteger(m[edge]) && m[edge] >= 0 && m[edge] <= 32) values[edge] = m[edge];
                    validated[mode] = values;
                }
                marginOverrides = validated;
            }
            barSpacingOverrides = validateSpacingOverrides(data.barSpacingOverrides);
            barIconOrderByMode = validateBarIconOrders(data.barIconOrderByMode);
            barIconPlacements = validateIconPlacements(data.barIconPlacements);
            // Upgrade old global alignment into 5 isolated layout profiles.
            for (const pair of [["mic", "microphoneStatusPlacement"], ["down", "downloadSpeedPlacement"], ["up", "uploadSpeedPlacement"]])
                if (!barIconPlacements[pair[0]] && ["left", "center", "right"].indexOf(data[pair[1]]) !== -1)
                    barIconPlacements[pair[0]] = data[pair[1]];
            if (data.barIconPlacementsByMode && typeof data.barIconPlacementsByMode === "object")
                barIconPlacementsByMode = validateModePlacements(data.barIconPlacementsByMode);
            else {
                const legacy = {};
                for (const modeName of spacingModes) legacy[modeName] = Object.assign({}, barIconPlacements);
                barIconPlacementsByMode = legacy;
            }
            // Normalize legacy per-zone spacing only within its own layout mode.
            for (const modeName of spacingModes) {
                const targetPlacement = barIconPlacementsByMode[modeName] || {};
                for (const key of barIconKeys) {
                    const targetZone = targetPlacement[key] || defaultBarPlacements[key];
                    for (const zone of spacingZones)
                        if (zone !== targetZone) transferIconSpacing(key, zone, targetZone, modeName);
                }
            }
            if (["compact", "clean-hover"].indexOf(data.launcherLayoutMode) !== -1)
                launcherLayoutMode = data.launcherLayoutMode;
            if (["plain", "filled"].indexOf(data.quickControlButtonStyle) !== -1)
                quickControlButtonStyle = data.quickControlButtonStyle;
            for (const key of ["launcherWidth", "launcherHeight", "launcherIconSize", "launcherRowHeight", "launcherFavoriteColumns"])
                if (Number.isInteger(data[key])) updateLauncherSize(key, data[key], false);
            if (data.widgetWorkspaceScopes && typeof data.widgetWorkspaceScopes === "object" &&
                !Array.isArray(data.widgetWorkspaceScopes)) {
                const cleanScopes = {};
                for (const kind of ["notes", "kanban", "randomImage"]) {
                    const ids = data.widgetWorkspaceScopes[kind];
                    cleanScopes[kind] = Array.isArray(ids)
                        ? ids.filter((id, i) => Number.isInteger(id) && id >= 1 && id <= 10 && ids.indexOf(id) === i)
                        : [1];
                }
                widgetWorkspaceScopes = cleanScopes;
            }
            if (data.workspaceNotes && typeof data.workspaceNotes === "object" && !Array.isArray(data.workspaceNotes)) {
                const notes = {};
                for (const key in data.workspaceNotes)
                    if (/^[a-zA-Z0-9_.:-]{1,120}$/.test(key) && typeof data.workspaceNotes[key] === "string")
                        notes[key] = data.workspaceNotes[key].slice(0, 30000);
                workspaceNotes = notes;
            }
            if (data.widgetSizes && typeof data.widgetSizes === "object" && !Array.isArray(data.widgetSizes)) {
                const sizes = {};
                for (const key in data.widgetSizes) {
                    const v = data.widgetSizes[key];
                    if (/^[a-zA-Z0-9_.:-]{1,120}$/.test(key) && v && typeof v === "object" &&
                        Number.isFinite(v.width) && Number.isFinite(v.height))
                        sizes[key] = {width:Math.round(Math.max(250,Math.min(1050,v.width))),
                                      height:Math.round(Math.max(145,Math.min(800,v.height)))};
                }
                widgetSizes = sizes;
            }
            if (data.widgetPositions && typeof data.widgetPositions === "object" && !Array.isArray(data.widgetPositions)) {
                const validPositions = {};
                for (const key in data.widgetPositions) {
                    const v = data.widgetPositions[key];
                    if (/^[a-zA-Z0-9_.:-]{1,120}$/.test(key) && v && typeof v === "object" &&
                        Number.isFinite(v.x) && Number.isFinite(v.y) && v.x >= 0 && v.x <= 1 && v.y >= 0 && v.y <= 1)
                        validPositions[key] = { x:v.x, y:v.y };
                }
                widgetPositions = validPositions;
            }
            for (const name of ["desktopNotes", "desktopKanban", "desktopRandomImage"])
                if (typeof data[name] === "boolean") root[name] = data[name];
            if (typeof data.widgetImageFolder === "string" && data.widgetImageFolder.length <= 1024 &&
                data.widgetImageFolder.indexOf("\0") < 0) widgetImageFolder = data.widgetImageFolder;
            if ([0, 60, 300, 900].indexOf(data.widgetImageRotateSeconds) >= 0)
                widgetImageRotateSeconds = data.widgetImageRotateSeconds;
            if (validQuickOrder(data.quickControlOrder)) quickControlOrder = data.quickControlOrder.slice();
            if (typeof data.showMenuBar === "boolean") showMenuBar = data.showMenuBar;
            for (const key of ["showMenuEdit", "showMenuView", "showMenuShare", "showMenuFile", "showMenuShell", "showMenuTools", "showNotifications", "showLauncher", "showRusticQIcon", "showTaskView", "desktopCalendar", "desktopSystem", "desktopClock", "desktopMedia", "desktopWeather", "desktopConnectivity", "showDock", "dockAutoHide", "dockFiles", "dockBrowser", "dockSettings", "dockTaskView", "dockAI", "dockRunningApps", "cleanRightDetails", "showArch", "showTime", "showDate", "showWifi", "showBluetooth", "showBattery", "showAudio", "showQuickControl", "showNotificationIcon"])
                if (typeof data[key] === "boolean") root[key] = data[key];
            if (typeof data.showWeather === "boolean") showWeather = data.showWeather;
            if (typeof data.showWorkspaces === "boolean") showWorkspaces = data.showWorkspaces;
            if (typeof data.showIndicators === "boolean") showIndicators = data.showIndicators;
            for (const key of ["showQuickModes", "quickModesAutoHide", "showKeepAwake", "showSilent", "showGamingMode", "showNightMode", "showMicMute", "showMicrophoneStatus", "showDownloadSpeed", "showUploadSpeed"])
                if (typeof data[key] === "boolean") root[key] = data[key];
            // Migrate RC4's single global icon toggle set *after* loading its flags.
            // Existing users do not unexpectedly lose icons in Simple mode.
            if (data.barIconVisibilityProfiles && typeof data.barIconVisibilityProfiles === "object")
                barIconVisibilityProfiles = validateVisibilityProfiles(data.barIconVisibilityProfiles);
            else {
                const migrated = {};
                for (const modeName of spacingModes) {
                    const record = {};
                    for (const key of barVisibilityKeys) record[key] = root[key] === true;
                    migrated[modeName] = record;
                }
                barIconVisibilityProfiles = migrated;
            }
            if (["coding", "gaming", "battery", "presentation"].indexOf(data.desktopProfile) !== -1)
                desktopProfile = data.desktopProfile;
            if (data.desktopProfilePrevious && typeof data.desktopProfilePrevious === "object" && !Array.isArray(data.desktopProfilePrevious)) {
                const clean = {};
                for (const key of desktopProfileKeys)
                    if (typeof data.desktopProfilePrevious[key] === "string" || typeof data.desktopProfilePrevious[key] === "boolean")
                        clean[key] = data.desktopProfilePrevious[key];
                desktopProfilePrevious = clean;
            }
            if (["openai", "anthropic", "gemini"].indexOf(data.aiProvider) !== -1) aiProvider = data.aiProvider;
            if (typeof data.aiModel === "string" && data.aiModel.length > 0 && data.aiModel !== "llama3.2") aiModel = data.aiModel;
        } catch (e) {
            console.warn("Settings: defaults in use (user-settings.json): " + e);
        }
    }
    function save() {
        settingsFile.setText(JSON.stringify({
            accentName: accentName,
            colorSource: colorSource,
            barMode: barMode,
            barPosition: barPosition,
            absoluteCenter: absoluteCenter,
            centerOffsetX: centerOffsetX,
            uiFontFamily: uiFontFamily,
            uiCustomFont: uiCustomFont,
            uiFontScale: uiFontScale,
            uiDensity: uiDensity,
            desktopProfile: desktopProfile,
            desktopProfilePrevious: desktopProfilePrevious,
            wallpaperPath: wallpaperPath,
            wallpaperBackend: wallpaperBackend,
            lockscreenBackground: lockscreenBackground,
            showNotifications: showNotifications,
            showLauncher: showLauncher,
            showRusticQIcon: showRusticQIcon,
            launcherLayoutMode: launcherLayoutMode,
            launcherWidth: launcherWidth,
            launcherHeight: launcherHeight,
            launcherIconSize: launcherIconSize,
            launcherRowHeight: launcherRowHeight,
            launcherFavoriteColumns: launcherFavoriteColumns,
            showTaskView: showTaskView,
            desktopCalendar: desktopCalendar,
            desktopSystem: desktopSystem,
            desktopClock: desktopClock,
            desktopMedia: desktopMedia,
            desktopWeather: desktopWeather,
            desktopConnectivity: desktopConnectivity,
            desktopNotes: desktopNotes,
            desktopKanban: desktopKanban,
            desktopRandomImage: desktopRandomImage,
            widgetImageFolder: widgetImageFolder,
            widgetImageRotateSeconds: widgetImageRotateSeconds,
            widgetPositions: widgetPositions,
            widgetWorkspaceScopes: widgetWorkspaceScopes,
            workspaceNotes: workspaceNotes,
            widgetSizes: widgetSizes,
            showDock: showDock,
            dockFiles: dockFiles,
            dockBrowser: dockBrowser,
            dockSettings: dockSettings,
            dockTaskView: dockTaskView,
            dockAI: dockAI,
            dockRunningApps: dockRunningApps,
            quickControlOrder: quickControlOrder,
            dockAutoHide: dockAutoHide,
            showMenuBar: showMenuBar,
            showMenuEdit: showMenuEdit,
            showMenuView: showMenuView,
            showMenuShare: showMenuShare,
            showMenuFile: showMenuFile,
            showMenuShell: showMenuShell,
            showMenuTools: showMenuTools,
            cleanRightDetails: cleanRightMode === "details", // older clients
            cleanRightMode: cleanRightMode,
            marginOverrides: marginOverrides,
            barSpacingOverrides: barSpacingOverrides,
            barIconPlacements: barIconPlacements, // legacy compatibility; not changed by v5 UI
            barIconPlacementsByMode: barIconPlacementsByMode,
            barIconOrderByMode: barIconOrderByMode,
            barIconVisibilityProfiles: barIconVisibilityProfiles,
            showArch: showArch,
            showTime: showTime,
            showDate: showDate,
            showWifi: showWifi,
            showBluetooth: showBluetooth,
            showBattery: showBattery,
            showAudio: showAudio,
            showQuickControl: showQuickControl,
            showNotificationIcon: showNotificationIcon,
            quickControlButtonStyle: quickControlButtonStyle,
            showWeather: showWeather,
            showWorkspaces: showWorkspaces,
            showIndicators: showIndicators,
            showQuickModes: showQuickModes,
            quickModesAutoHide: quickModesAutoHide,
            showKeepAwake: showKeepAwake,
            showSilent: showSilent,
            showGamingMode: showGamingMode,
            showNightMode: showNightMode,
            showMicMute: showMicMute,
            showMicrophoneStatus: showMicrophoneStatus,
            showDownloadSpeed: showDownloadSpeed,
            showUploadSpeed: showUploadSpeed,
            aiProvider: aiProvider,
            aiModel: aiModel
        }, null, 2) + "\n");
    }
}
