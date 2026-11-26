# Launcher dan dock: perbaikan animasi tersendat

Perbaikan incremental tanpa pengaturan tampilan baru atau perubahan durasi global.

## Penyebab yang ditemukan

- Dock menganimasikan `PanelWindow.implicitWidth/implicitHeight`. Margin centering
  ikut berubah pada setiap frame, sehingga compositor mengulang configure, resize
  buffer dan penempatan. Isi dock juga langsung disembunyikan saat tutup dimulai.
- Tinggi hasil launcher langsung menentukan tinggi jendela native. Resize hasil
  yang seharusnya ringan di QML mengirim beberapa resize Wayland per transisi.
- Dock belum termasuk aturan `no_anim` RusticQ, sehingga animasi compositor dapat
  bertumpuk dengan motion QML.
- Probe/rule blur berjalan lagi 180 ms setelah setiap buka/tutup launcher. Pada
  Launchpad, blur/opacity dapat berubah di tengah animasi. Carrier blur 1/255 yang
  ikut fade juga terkuantisasi ke nol pada frame awal.
- Launcher dibongkar setiap ditutup. Membuka lagi membuat controller dan frontend
  baru. Rebuild query juga mempublikasikan ulang indeks aplikasi yang sama.
- Animasi entry mulai sebelum frame native pertama siap; waktu membangun window
  dan memuat ikon menghabiskan sebagian animasi sebelum pengguna melihatnya.

## Perubahan

Dock sekarang menyimpan buffer native pada ukuran expanded dan menganimasikan
GlassSurface internal. Input region mengikuti surface yang terlihat. Layout isi
berukuran tetap dan memudar sampai akhir penutupan; area kosong tidak menerima
klik. Hasil polling aplikasi yang identik tidak membongkar delegate lagi.

Launcher menggunakan canvas transparan terbatas pada kapasitas layout. Hanya
surface/posisi QML yang berubah saat hasil membesar atau mengecil; native window
stabil. Input region mengikuti surface sebenarnya, termasuk dua bagian Detached.
Low-memory/animations-off tetap memakai geometri aktual tanpa ruang animasi ekstra.

Aturan blur disiapkan ketika layout/backdrop dipilih, tanpa proses baru pada setiap
buka/tutup. Window backdrop hanya ada ketika launcher dipresentasikan. Carrier
native stabil sejak frame pertama; dim tetap mengikuti progres motion. Backdrop
bertahan selama exit dengan input region kosong begitu penutupan diminta.

Launcher dimuat setelah pemakaian pertama dan dipertahankan pada mode normal.
Low-memory mode membuang cache saat ditutup, tanpa memuatnya kembali ketika mode
itu dimatikan. Query baru tetap bersih sesuai perilaku sebelumnya. Ikon dimuat
asinkron, indeks yang tidak berubah tidak dipublikasikan ulang.

SurfaceMotion menambah `startReady` (default true untuk pemakai lain). Launcher dan
dock menunggu sinyal frame native pertama sebelum entry. Animasi disabled tetap
langsung. Ini memakai
[Qt Window.frameSwapped](https://doc.qt.io/qt-6/qml-qtquick-window.html#frameSwapped-signal),
bukan loop polling. Aturan presentation yang sudah dimiliki RusticQ mencakup dock,
launcher dan backdrop melalui namespace eksak, memakai
[API layer rule Hyprland 0.56](https://wiki.hypr.land/0.56.0/configuring/basics/window-rules/#layer-rules).
Global blur/animasi compositor dan konfigurasi Omarchy tidak diubah.

## Hasil aktual

Di Hyprland 0.56.2, Quickshell 0.3.2, eDP-1 1920×1080 sekitar 60 Hz:

| Transisi | Resize native sebelum | Sesudah | Perpindahan native sebelum → sesudah |
| --- | ---: | ---: | ---: |
| Dock expand | 10 | 0 | 12 → 0 |
| Dock collapse | 12 | 0 | 11 → 0 |
| Detached hasil muncul | 6 | 0 | 0 → 0 |
| Spotlight hasil membesar | 7 | 0 | 0 → 0 |

Dalam fixture animasi dock yang sama, p95 interval callback frame submit turun
sekitar 50–51 ms menjadi 21 ms. Ini bukan klaim FPS/GPU seluruh desktop: callback
QtTest memakai waktu GUI, dan jeda pada fase yang tidak sedang beranimasi bisa
berarti tidak ada frame yang perlu digambar. Remap window ketika launcher dibuka
masih dapat mengirim configure awal; yang dihilangkan adalah resize per frame.

Native regression: 6/6 hasil lulus, termasuk reversal, isi tetap ada saat exit,
input anchor stabil, cache controller sama setelah reopen, pelepasan low-memory,
aturan blur siap sebelum buka, dan delegate dock tetap sama untuk data identik.
Global motion QtTest 10/10; Launcher Studio QtTest 11/11; native popup/lifecycle
6/6; backend/material 23 tests; kontrak Launcher Studio 7 tests. Pemeriksaan
struktur mencakup 166 QML tanpa issue. Tes reload/IPC terisolasi juga lulus.

Capture native tambahan: 30 keadaan, lima gaya launcher, lima backdrop, input
wtype/Escape, serta dock expanded/collapsed. Perbandingan piksel membuktikan tidak
ada fill/blur di luar surface aktual dalam 17 keadaan None, celah Detached bersih
pada 7 keadaan, dan tidak ada halo persegi dock dalam 3 keadaan.

[Profil sebelum](audit/launcher-dock-motion/before-native.json) ·
[Profil sesudah](audit/launcher-dock-motion/after-native.json) ·
[Hasil piksel](audit/launcher-dock-motion/pixel-proof.json) ·
[Dock expanded](audit/launcher-dock-motion/dock-expanded.png) ·
[Dock collapsed](audit/launcher-dock-motion/dock-collapsed.png) ·
[Detached](audit/launcher-dock-motion/detached-populated.png)

File utama: SurfaceMotion.qml, LauncherAppIcon.qml, LauncherController.qml,
LauncherView.qml, MiniLauncher.qml, LauncherOverlay.qml, RusticDock.qml,
shell.qml, GlassService.qml dan rusticq-glass.py. Regression baru ada pada
`tools/test_launcher_dock_motion.py --native`; tes motion, material, static
launcher dan capture diperluas. Lihat [validation.json](audit/launcher-dock-motion/validation.json) untuk perintah dan hasil.

Verifikasi native memakai fixture dengan source produksi dan aturan privat yang
dinonaktifkan setelah tes. Tidak ada aplikasi diluncurkan atau global blur
berubah. Pengujian fisik multi-monitor/fractional scale dan benchmark GPU belum
dilakukan. Patch sudah dipasang ke salinan shell aktif dan dimuat ulang melalui IPC tanpa
error QML. Preferensi byte-identical. Backup kode lama: `/home/ryznxx/.local/state/rusticq/backups/motion-20261125-105313`.
Catatan lengkap tersimpan pada [deployment.json](audit/launcher-dock-motion/deployment.json);
file preferensi pengguna tidak disertakan dalam patch.
