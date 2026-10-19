#!/usr/bin/env python3
"""Contract checks: intrinsic Wi-Fi Advanced height and independent secure QR layer."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class WifiOverlayLayoutTests(unittest.TestCase):
    def test_advanced_is_not_clipped_or_nest_scrolled(self):
        bar = (ROOT / 'modules/bar/BarWifi.qml').read_text()
        self.assertNotIn('Layout.preferredHeight: visible ? 335 : 0', bar)
        self.assertNotIn('Flickable {', bar)
        self.assertIn('implicitHeight: standalone ? wifiContent.implicitHeight', bar)
        self.assertIn('Layout.preferredHeight: visible ? implicitHeight : 0', bar)
        self.assertIn('Layout.preferredHeight: wifiWidget.standalone', bar)
        popup = (ROOT / 'modules/main/IndicatorPopup.qml').read_text()
        self.assertIn('widgetLoader.item ? widgetLoader.item.implicitHeight', popup)
        self.assertIn('hostWindow.screen.height - 95', popup)

    def test_qr_owner_is_independent_wayland_overlay_on_selected_monitor(self):
        share = (ROOT / 'modules/main/WifiShareOverlay.qml').read_text()
        power = (ROOT / 'modules/power/PowerMenu.qml').read_text()
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay', power)
        self.assertIn('WlrLayershell.layer: WlrLayer.Overlay', share)
        self.assertIn('screen: Store.wifiQrScreen', share)
        self.assertIn('anchors { top: true; bottom: true; left: true; right: true }', share)
        self.assertIn('HyprlandFocusGrab {', share)
        self.assertIn('Keys.onEscapePressed: root.close()', share)
        self.assertIn('onVisibleChanged:', share)
        self.assertIn('cleanupPending = true', share)
        self.assertIn('retryPending', share)
        self.assertIn('secondsRemaining <= 0', share)
        self.assertIn('qrClear.exec(["python3", helper, "qr-clear"])', share)
        self.assertNotIn('802-11-wireless-security.psk', share)
        self.assertNotIn('passwordText', share)
        self.assertIn('WifiShareOverlay {}', (ROOT / 'shell.qml').read_text())

    def test_qr_cleanup_does_not_require_nmcli(self):
        from unittest.mock import patch
        import importlib.util
        script = ROOT / 'scripts/rusticq-wifi-advanced.py'
        spec = importlib.util.spec_from_file_location('wifi_cleanup_test', script)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        with patch.object(mod.shutil, 'which', return_value=None), \
             patch.object(mod, 'clear_qr', return_value={'ok': True}) as clear:
            self.assertEqual(mod.main(['qr-clear']), {'ok': True})
            clear.assert_called_once()

    def test_open_closes_popup_and_keeps_original_anchor(self):
        widget=(ROOT/'modules/bar/WifiAdvanced.qml').read_text()
        popup=(ROOT/'modules/main/IndicatorPopup.qml').read_text()
        store=(ROOT/'config/Store.qml').read_text()
        self.assertIn('root.shareQrRequested(screen, ssid)', widget)
        self.assertIn('Store.openWifiQr(popup.pendingQrScreen, popup.pendingQrSsid)', popup)
        self.assertIn('interval: 260', popup)
        self.assertNotIn('source: root.qrUrl', widget)
        self.assertIn('function beginWifiQr(screen, ssid)', popup)
        self.assertIn('dismissed();', popup)
        self.assertIn('popupScreen: popup.hostWindow ? popup.hostWindow.screen : null', popup)
        self.assertIn('function closeWifiQr()', store)
        self.assertIn('wifiQrScreen = screen', store)
        self.assertIn('anchor.rect.x:', popup)

if __name__ == '__main__':
    unittest.main()
