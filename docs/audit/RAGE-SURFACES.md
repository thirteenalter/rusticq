# RAGE surface audit

Date: 2026-11-24. Source audit of Rectangle-derived decorations and Quickshell
windows; counts include component definitions and conditional/lazy branches,
not the number of live windows. `Bindings` counts semantic glass references and
BarSurface/Pill instances; inherited material also covers files without direct
color bindings. Text, icons, graphs, progress, QR quiet zones, secure backing
and functional state markers deliberately retain their original contrast.

## Active and lazy ownership

- `shell.qml`: bars/recovery/OSD/widgets/dock per screen; one notification server,
  QR owner and package confirmation; native Polkit agent and hardware observer.
- MotionLoader: Quick Control, Settings, device settings, AI, launcher, system
  monitor, task view, power and shortcut confirmation. AI can remain loaded
  while hidden. All consume reactive Theme tokens, including already-open UI.
- IndicatorPopup: menu, Wi-Fi, Ethernet, Bluetooth, battery, audio, weather,
  time, calendar, system dashboard and notification history. These now use one
  anchored PanelWindow per bar, namespace `rusticq-popups`, owning keyboard and
  outside-click focus independently of the bar. No extra dismissal windows.
- BarWrapper uses `modules/quickcontrol/QuickControlCards.qml`. `BarMain.qml`
  remains a legacy composition; its children also use the shared tokens.
- `lockscreen.qml` owns a separate secure process; only its view component
  changes. `PackageAuthorizationOverlay.qml` is legacy, not a second agent.
- `modules/process/ProcessManager.qml` is an unloaded prototype. It is not
  presented as an active shell feature.

## Decoration policy

PanelWindow canvases stay transparent; the lock canvas stays opaque.
FloatingWindow canvases use the window role and retain compositor decorations.
PopupWindow surfaces belong to their popup/tooltip role, never layer namespaces.
IndicatorPopup is a PanelWindow and uses the existing `rusticq-popups` rule.
Bar outer/segment/module decorations use BarSurface; hiding one never hides
content or changes an input region. Purely functional hover, selection, active
workspace and focus feedback bypass decorative visibility.

The original full-width Separated outline came from promoting an originally
zero-width border through `glassBorderWidth("primary", 0)`. The fix preserves
zero on the native empty Separated rail; explicit Outline Only requests a
visible outline. GlassSurface effects follow actual fill and layer visibility,
so an empty rail cannot retain specular highlights or contact shading.

## File inventory

| QML file | Surface nodes | Window nodes | Bindings / material uses |
| --- | ---: | ---: | ---: |
| [components/ActionButton.qml](../../components/ActionButton.qml) | 1 | 0 | 4 |
| [components/ApplicationAudioMixer.qml](../../components/ApplicationAudioMixer.qml) | 4 | 0 | 4 |
| [components/Arch.qml](../../components/Arch.qml) | 1 | 0 | 1 |
| [components/BarSurface.qml](../../components/BarSurface.qml) | 1 | 0 | 2 |
| [components/BarSurfacePreview.qml](../../components/BarSurfacePreview.qml) | 4 | 0 | 3 |
| [components/BarZone.qml](../../components/BarZone.qml) | 9 | 0 | 8 |
| [components/Clock.qml](../../components/Clock.qml) | 1 | 0 | 1 |
| [components/ContextMenuBar.qml](../../components/ContextMenuBar.qml) | 2 | 0 | 2 |
| [components/ControlSlider.qml](../../components/ControlSlider.qml) | 3 | 0 | 0 |
| [components/DeviceSettingsButton.qml](../../components/DeviceSettingsButton.qml) | 1 | 0 | 2 |
| [components/ExtraStatusIcons.qml](../../components/ExtraStatusIcons.qml) | 1 | 0 | 1 |
| [components/GlassHighlight.qml](../../components/GlassHighlight.qml) | 2 | 0 | 4 |
| [components/GlassPreview.qml](../../components/GlassPreview.qml) | 3 | 0 | 2 |
| [components/GlassSurface.qml](../../components/GlassSurface.qml) | 1 | 0 | 6 |
| [components/Indicators.qml](../../components/Indicators.qml) | 1 | 0 | 1 |
| [components/MarginSlider.qml](../../components/MarginSlider.qml) | 3 | 0 | 2 |
| [components/MotionStylePicker.qml](../../components/MotionStylePicker.qml) | 2 | 0 | 4 |
| [components/NameSearchField.qml](../../components/NameSearchField.qml) | 1 | 0 | 4 |
| [components/Pill.qml](../../components/Pill.qml) | 1 | 0 | 1 |
| [components/PowerButton.qml](../../components/PowerButton.qml) | 1 | 0 | 0 |
| [components/QuickModes.qml](../../components/QuickModes.qml) | 5 | 1 | 6 |
| [components/RecordingDot.qml](../../components/RecordingDot.qml) | 1 | 0 | 0 |
| [components/ScanButton.qml](../../components/ScanButton.qml) | 1 | 0 | 2 |
| [components/SettingRangeSlider.qml](../../components/SettingRangeSlider.qml) | 3 | 0 | 0 |
| [components/SettingsToggle.qml](../../components/SettingsToggle.qml) | 4 | 0 | 6 |
| [components/Tooltip.qml](../../components/Tooltip.qml) | 1 | 0 | 4 |
| [components/Weather.qml](../../components/Weather.qml) | 1 | 0 | 1 |
| [components/Workspaces.qml](../../components/Workspaces.qml) | 1 | 0 | 1 |
| [modules/ai/AiWrapper.qml](../../modules/ai/AiWrapper.qml) | 14 | 1 | 31 |
| [modules/bar/BarAdvanced.qml](../../modules/bar/BarAdvanced.qml) | 6 | 0 | 17 |
| [modules/bar/BarBattery.qml](../../modules/bar/BarBattery.qml) | 4 | 0 | 8 |
| [modules/bar/BarBluetooth.qml](../../modules/bar/BarBluetooth.qml) | 5 | 0 | 8 |
| [modules/bar/BarFooter.qml](../../modules/bar/BarFooter.qml) | 1 | 0 | 0 |
| [modules/bar/BarHeader.qml](../../modules/bar/BarHeader.qml) | 4 | 0 | 6 |
| [modules/bar/BarMain.qml](../../modules/bar/BarMain.qml) | 3 | 0 | 5 |
| [modules/bar/BarMonitors.qml](../../modules/bar/BarMonitors.qml) | 15 | 0 | 40 |
| [modules/bar/BarNotifications.qml](../../modules/bar/BarNotifications.qml) | 15 | 0 | 36 |
| [modules/bar/BarSystem.qml](../../modules/bar/BarSystem.qml) | 7 | 0 | 8 |
| [modules/bar/BarWifi.qml](../../modules/bar/BarWifi.qml) | 11 | 0 | 17 |
| [modules/bar/BarWrapper.qml](../../modules/bar/BarWrapper.qml) | 2 | 1 | 6 |
| [modules/bar/WifiAdvanced.qml](../../modules/bar/WifiAdvanced.qml) | 6 | 0 | 10 |
| [modules/bar/WifiHiddenNetwork.qml](../../modules/bar/WifiHiddenNetwork.qml) | 5 | 0 | 8 |
| [modules/lock/RusticQLockSurface.qml](../../modules/lock/RusticQLockSurface.qml) | 9 | 1 | 16 |
| [modules/main/Bar.qml](../../modules/main/Bar.qml) | 2 | 1 | 2 |
| [modules/main/BarAutoHide.qml](../../modules/main/BarAutoHide.qml) | 0 | 1 | 0 |
| [modules/main/BarRecoveryHandle.qml](../../modules/main/BarRecoveryHandle.qml) | 1 | 1 | 4 |
| [modules/main/ClockAlarmControls.qml](../../modules/main/ClockAlarmControls.qml) | 2 | 0 | 8 |
| [modules/main/ContextMenu.qml](../../modules/main/ContextMenu.qml) | 5 | 0 | 14 |
| [modules/main/DesktopNotesCard.qml](../../modules/main/DesktopNotesCard.qml) | 12 | 0 | 16 |
| [modules/main/DesktopRandomImageCard.qml](../../modules/main/DesktopRandomImageCard.qml) | 3 | 0 | 8 |
| [modules/main/DesktopScratchpadCard.qml](../../modules/main/DesktopScratchpadCard.qml) | 2 | 0 | 6 |
| [modules/main/DesktopWidgetWindow.qml](../../modules/main/DesktopWidgetWindow.qml) | 14 | 1 | 34 |
| [modules/main/IndicatorPopup.qml](../../modules/main/IndicatorPopup.qml) | 1 | 1 | 4 |
| [modules/main/KeepAwakeSurface.qml](../../modules/main/KeepAwakeSurface.qml) | 0 | 1 | 0 |
| [modules/main/LauncherOverlay.qml](../../modules/main/LauncherOverlay.qml) | 1 | 1 | 1 |
| [modules/main/MiniAudio.qml](../../modules/main/MiniAudio.qml) | 11 | 0 | 16 |
| [modules/main/MiniDate.qml](../../modules/main/MiniDate.qml) | 8 | 0 | 20 |
| [modules/main/MiniEthernetInfo.qml](../../modules/main/MiniEthernetInfo.qml) | 3 | 0 | 7 |
| [modules/main/MiniLauncher.qml](../../modules/main/MiniLauncher.qml) | 11 | 0 | 29 |
| [modules/main/MiniTime.qml](../../modules/main/MiniTime.qml) | 1 | 0 | 4 |
| [modules/main/MiniWeather.qml](../../modules/main/MiniWeather.qml) | 1 | 0 | 2 |
| [modules/main/MonitorGraphCard.qml](../../modules/main/MonitorGraphCard.qml) | 2 | 0 | 5 |
| [modules/main/NativePolkitAgent.qml](../../modules/main/NativePolkitAgent.qml) | 7 | 1 | 12 |
| [modules/main/NotificationToasts.qml](../../modules/main/NotificationToasts.qml) | 5 | 1 | 12 |
| [modules/main/PackageAuthorizationOverlay.qml](../../modules/main/PackageAuthorizationOverlay.qml) | 8 | 1 | 14 |
| [modules/main/PackageConfirmationWindow.qml](../../modules/main/PackageConfirmationWindow.qml) | 8 | 1 | 19 |
| [modules/main/RecordingIndicator.qml](../../modules/main/RecordingIndicator.qml) | 1 | 1 | 0 |
| [modules/main/RusticDock.qml](../../modules/main/RusticDock.qml) | 5 | 1 | 10 |
| [modules/main/ShortcutBackupConfirmationWindow.qml](../../modules/main/ShortcutBackupConfirmationWindow.qml) | 6 | 1 | 17 |
| [modules/main/SystemDashboard.qml](../../modules/main/SystemDashboard.qml) | 6 | 0 | 10 |
| [modules/main/SystemMonitorWindow.qml](../../modules/main/SystemMonitorWindow.qml) | 3 | 1 | 7 |
| [modules/main/SystemOsd.qml](../../modules/main/SystemOsd.qml) | 5 | 1 | 6 |
| [modules/main/TaskViewWindow.qml](../../modules/main/TaskViewWindow.qml) | 0 | 1 | 1 |
| [modules/main/WifiShareOverlay.qml](../../modules/main/WifiShareOverlay.qml) | 5 | 1 | 11 |
| [modules/power/PowerMenu.qml](../../modules/power/PowerMenu.qml) | 4 | 1 | 11 |
| [modules/quickcontrol/QuickControlCards.qml](../../modules/quickcontrol/QuickControlCards.qml) | 3 | 0 | 5 |
| [modules/settings/DeviceSettingsWindow.qml](../../modules/settings/DeviceSettingsWindow.qml) | 5 | 1 | 11 |
| [modules/settings/SettingsSection.qml](../../modules/settings/SettingsSection.qml) | 2 | 0 | 6 |
| [modules/settings/SettingsWindow.qml](../../modules/settings/SettingsWindow.qml) | 10 | 1 | 20 |
| [modules/settings/pages/BarAlignmentEditor.qml](../../modules/settings/pages/BarAlignmentEditor.qml) | 9 | 0 | 16 |
| [modules/settings/pages/BarIconSizeEditor.qml](../../modules/settings/pages/BarIconSizeEditor.qml) | 1 | 0 | 4 |
| [modules/settings/pages/BarPaddingEditor.qml](../../modules/settings/pages/BarPaddingEditor.qml) | 1 | 0 | 2 |
| [modules/settings/pages/BarSpacingEditor.qml](../../modules/settings/pages/BarSpacingEditor.qml) | 6 | 0 | 16 |
| [modules/settings/pages/ClockSettingsEditor.qml](../../modules/settings/pages/ClockSettingsEditor.qml) | 5 | 0 | 18 |
| [modules/settings/pages/RecordingIndicatorSettings.qml](../../modules/settings/pages/RecordingIndicatorSettings.qml) | 1 | 0 | 2 |
| [modules/settings/pages/SettingsAIPage.qml](../../modules/settings/pages/SettingsAIPage.qml) | 9 | 0 | 16 |
| [modules/settings/pages/SettingsAboutPage.qml](../../modules/settings/pages/SettingsAboutPage.qml) | 5 | 0 | 18 |
| [modules/settings/pages/SettingsAppearancePage.qml](../../modules/settings/pages/SettingsAppearancePage.qml) | 33 | 0 | 82 |
| [modules/settings/pages/SettingsBarPage.qml](../../modules/settings/pages/SettingsBarPage.qml) | 13 | 0 | 38 |
| [modules/settings/pages/SettingsCompositorPage.qml](../../modules/settings/pages/SettingsCompositorPage.qml) | 8 | 0 | 16 |
| [modules/settings/pages/SettingsHomePage.qml](../../modules/settings/pages/SettingsHomePage.qml) | 2 | 0 | 4 |
| [modules/settings/pages/SettingsInfoPage.qml](../../modules/settings/pages/SettingsInfoPage.qml) | 17 | 0 | 36 |
| [modules/settings/pages/SettingsIntegrationPage.qml](../../modules/settings/pages/SettingsIntegrationPage.qml) | 41 | 0 | 82 |
| [modules/settings/pages/SettingsLauncherPage.qml](../../modules/settings/pages/SettingsLauncherPage.qml) | 3 | 0 | 8 |
| [modules/settings/pages/SettingsModulesPage.qml](../../modules/settings/pages/SettingsModulesPage.qml) | 5 | 0 | 12 |
| [modules/settings/pages/SettingsNotesPage.qml](../../modules/settings/pages/SettingsNotesPage.qml) | 6 | 0 | 10 |
| [modules/settings/pages/SettingsShortcutsPage.qml](../../modules/settings/pages/SettingsShortcutsPage.qml) | 15 | 0 | 34 |
| [modules/settings/pages/SettingsUpdaterPage.qml](../../modules/settings/pages/SettingsUpdaterPage.qml) | 10 | 0 | 20 |
| [modules/settings/pages/SettingsWidgetsPage.qml](../../modules/settings/pages/SettingsWidgetsPage.qml) | 6 | 0 | 16 |
