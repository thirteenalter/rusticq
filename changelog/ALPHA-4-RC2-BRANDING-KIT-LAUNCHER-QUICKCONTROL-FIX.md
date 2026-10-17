# RusticQ Alpha 4 RC2 — Branding Kit, Launcher Icon & Quick Control Mode

## Ringkasan
Pembaruan ini mengganti aset branding kustom sebelumnya dengan aset resmi dari `rusticq-branding-kit-v1.0`, menambahkan toggle khusus untuk ikon RusticQ, dan memberi dua mode tampilan untuk ikon Quick Control di bar.

## Perubahan utama

### Branding resmi dari branding kit
- Menggunakan SVG resmi `rusticq-app-icon.svg` sebagai sumber ikon RusticQ.
- Menambahkan PNG resmi ke halaman About:
  - `rusticq-about-lockup.png`
  - `rusticq-about-icon.png`
- Komponen `RusticQIcon.qml` sekarang merujuk ke aset SVG resmi dari branding kit.

### Launcher & brand icon
- Ikon **App Launcher** di bar kembali menjadi ikon pencarian / magnifying glass.
- Menambahkan ikon **RusticQ** terpisah di bar sebagai ikon brand khusus.
- Ikon RusticQ dapat diaktifkan / dinonaktifkan dengan setting tersendiri melalui:
  - **Modules**
  - **Launcher settings**
- Ikon RusticQ pada bar membuka Settings.
- Header launcher tetap memakai identitas launcher pencarian, tetapi dapat menampilkan badge RusticQ kecil ketika opsi brand icon aktif.

### About page
- Halaman **About** sekarang memakai gambar PNG resmi dari branding kit.
- Branding dan copy diperbarui agar selaras dengan perilaku launcher yang baru.

### Quick Control icon mode
- Menambahkan 2 mode untuk ikon Quick Control di bar:
  - **No bg with icon**
  - **Bg with icon**
- Mode disimpan secara persisten melalui `SettingsStore.quickControlButtonStyle`.

### Alignment & spacing editor
- Ikon **RusticQ** sekarang ikut masuk ke:
  - **Bar icon alignment**
  - **Icon spacing**
- Berarti ikon brand dapat dipindahkan ke Left / Center / Right seperti ikon lainnya.

### Dock consistency
- Dock memakai ikon SVG RusticQ untuk **Settings**.
- Ikon **Launcher** di dock tetap ikon pencarian agar konsisten dengan fungsi launcher.

## File yang berubah
- `assets/rusticq-app-icon.svg`
- `assets/rusticq-about-lockup.png`
- `assets/rusticq-about-icon.png`
- `components/RusticQIcon.qml`
- `components/BarZone.qml`
- `config/SettingsStore.qml`
- `modules/main/MiniLauncher.qml`
- `modules/main/RusticDock.qml`
- `modules/settings/pages/BarAlignmentEditor.qml`
- `modules/settings/pages/BarSpacingEditor.qml`
- `modules/settings/pages/SettingsAboutPage.qml`
- `modules/settings/pages/SettingsBarPage.qml`
- `modules/settings/pages/SettingsLauncherPage.qml`
- `modules/settings/pages/SettingsModulesPage.qml`
