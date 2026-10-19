#!/usr/bin/env python3
"""Regression contracts for focus-safe Wi-Fi QR and notification bar migration."""
from pathlib import Path
import json
import re
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[1]

def read(path): return (ROOT / path).read_text()

def extract(js, name):
    match=re.search(r'(?m)^    function ' + re.escape(name) + r'\([^\n]*\) \{',js)
    assert match, name
    depth=0
    for i in range(match.end()-1,len(js)):
        if js[i]=='{': depth+=1
        elif js[i]=='}':
            depth-=1
            if depth==0: return js[match.start()+4:i+1]
    raise AssertionError('Unbalanced: '+name)

class CombinedHotfixTests(unittest.TestCase):
    def test_wifi_scanned_networks_expand_not_advanced_scroll(self):
        wifi=read('modules/bar/BarWifi.qml')
        self.assertIn('listHeightLimit',wifi)
        self.assertIn(': 300',wifi)
        self.assertIn('count * 70 + 8',wifi)
        self.assertNotIn('Flickable {',wifi)
        self.assertIn('Layout.preferredHeight: visible ? implicitHeight : 0',wifi)
        popup=read('modules/main/IndicatorPopup.qml')
        self.assertIn('hostWindow.screen.height - 95',popup)
        self.assertIn('anchor.rect.x:',popup)

    def test_wifi_qr_released_focus_before_overlay_and_secrets_private(self):
        panel=read('modules/main/IndicatorPopup.qml')
        advanced=read('modules/bar/WifiAdvanced.qml')
        bar=read('modules/bar/BarWifi.qml')
        overlay=read('modules/main/WifiShareOverlay.qml')
        self.assertIn('root.shareQrRequested(screen, ssid)',advanced)
        self.assertIn('onShareQrRequested: (screen, ssid) => wifiWidget.shareQrRequested(screen, ssid)',bar)
        self.assertIn('onShareQrRequested: (screen, ssid) => popup.beginWifiQr(screen, ssid)',panel)
        self.assertRegex(panel, r'function beginWifiQr\(screen, ssid\)[\s\S]+?dismissed\(\);[\s\S]+?wifiQrDelay.restart\(\)')
        self.assertIn('interval: 260',panel)
        self.assertIn('Store.openWifiQr(popup.pendingQrScreen, popup.pendingQrSsid)',panel)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay',overlay)
        self.assertIn('active: root.visible && !focusDelay.running',overlay)
        self.assertIn('cleanupPending = true',overlay)
        self.assertNotIn('802-11-wireless-security.psk',overlay)
        self.assertIn("input=content",read('scripts/rusticq-wifi-advanced.py'))

    def test_notifications_dedicated_icon_and_larger_card(self):
        zone=read('components/BarZone.qml')
        popup=read('modules/main/IndicatorPopup.qml')
        center=read('modules/quickcontrol/QuickControlCards.qml')
        store=read('config/SettingsStore.qml')
        self.assertIn('case "notifications": return notificationsPart;',zone)
        self.assertIn('NotificationCenter.unread > 0',zone)
        self.assertIn('root.popup("notifications", parent)',zone)
        self.assertIn('kind === "notifications" ? 405',popup)
        self.assertIn('BarNotifications { standalone: true; expanded: true }',popup)
        self.assertIn('NotificationCenter.markRead()',popup)
        self.assertIn('Math.min(575, Math.max(445',center)
        self.assertIn('"showNotificationIcon"',store)
        self.assertIn('showNotificationIcon: showNotificationIcon',store)
        for path in ('modules/settings/pages/BarAlignmentEditor.qml','modules/settings/pages/BarSpacingEditor.qml'):
            self.assertIn('key:"notifications"',read(path))

    def test_legacy_icon_layout_migration_preserves_saved_positions(self):
        s=read('config/SettingsStore.qml')
        fn='\n'.join(extract(s,name) for name in ('validateBarIconOrder','normalizeBarOrder','validateBarIconOrders','barOrder'))
        # Use a previously saved 18-icon order with an unrelated swapped tile.
        keys=["rusticq", "arch", "launcher", "menu", "workspaces", "weather", "time", "date", "bluetooth", "wifi", "battery", "audio", "notifications", "task", "quickModes", "quickControl", "mic", "down", "up"]
        code='''const assert=require('node:assert/strict');
const barIconKeys=KEYS;
const spacingModes=['compact','simple','clean-compact','separated','professional'];
let barMode='compact',barIconOrderByMode={};
FUNCTIONS
const old=barIconKeys.filter(k=>k!=='notifications');
[old[0],old[1]]=[old[1],old[0]];
barIconOrderByMode.compact=old;
const migrated=barOrder();
assert.equal(migrated.length,barIconKeys.length);
assert.deepEqual(migrated.filter(k=>k!=='notifications'),old);
assert.equal(migrated.indexOf('notifications'),migrated.indexOf('audio')+1);
assert.deepEqual(validateBarIconOrders({compact:old}).compact,migrated);
assert.deepEqual(barOrder('simple'),barIconKeys);
console.log('ok legacy notification migration');
'''.replace('KEYS',json.dumps(keys)).replace('FUNCTIONS',fn)
        res=subprocess.run(['node','-e',code],capture_output=True,text=True,timeout=10)
        self.assertEqual(res.returncode,0,res.stdout+res.stderr)

if __name__=='__main__': unittest.main()
