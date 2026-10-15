# Catatan perbaikan — 15 Oktober 2026

**Basis API:** Quickshell v0.3.1 / Qt 6 / Wayland + Hyprland.

## Investigasi

1. `shell.qml`: `BarWrapper` selalu di-load (dan `HyprlandFocusGrab.active` selalu true), terlepas dari `Store.sidebarVisible`. Tombol toggle tidak menutup panel sebenarnya.
2. `services/` tidak memiliki `qmldir`, sementara service dideklarasikan `pragma Singleton` dan dipanggil dari banyak komponen. QML memerlukan registrasi singleton pada impor direktori.
3. `config/Theme.qml` tidak mempunyai token `error`, tetapi `BarWifi` memakainya; `Fonts.poppinsB` direferensikan padahal belum didefinisikan.
4. `components/Workspaces.qml` masih string statis `1 2 3`; belum mengacu ke workspace Hyprland.
5. `BarWifi.qml` memakai `Component` terpisah yang merujuk `delegateLoader` di scope lain. Referensi QML id tidak tersedia secara leksikal pada konteks tersebut.
6. `BatteryService` membaca `/sys/class/power_supply/BAT*` via shell dan menebak icon yang bukan glyph Material Symbols. BluetoothService menjalankan `bluetoothctl` tiap 3 detik.
7. Weather widget menggandakan simbol derajat (`%t` sudah memuat satuan).
8. Kode lama mengandalkan font Nerd Font eksternal walaupun project sudah mem-bundle font Poppins dan Material Symbols Rounded.

## Perubahan

- `Variants` menghasilkan bar per monitor; tombol bar menyimpan target monitor sebelum membuka sidebar.
- `LazyLoader` sidebar hanya aktif ketika diminta; close button / dismiss outside menggunakan state singleton.
- Workspace 1–6 kini highlight berdasarkan `Hyprland.focusedWorkspace`, dan klik melakukan dispatch.
- Service UPower + BlueZ menggantikan polling battery dan Bluetooth; indikator Wi-Fi memakai API Networking, fallback deteksi USB dengan interval lebih rendah.
- Wi-Fi card menggunakan delegate langsung, bukan Loader lintas-scope, dengan connect/disconnect/forget, PSK input, dan error handler.
- Token palet tetap Gruvbox Dark original (background, surface, foreground, borderaccent, accent); warna `error`, `success`, `muted` ditambah dari Gruvbox.
- Poppins (bundled) dipakai konsisten. Simbol indikator diverifikasi ada dalam font Material Symbols Rounded dari ZIP original.
- System monitor menangani sensor suhu yang tidak tersedia dan perhitungan CPU tidak lagi menghitung guest time dua kali.
- Placeholder `PowerMenu.qml` dan `ProcessManager.qml` *tidak* dimuat di entrypoint; ditinggalkan tanpa memperkenalkan aksi power destruktif.

## Verifikasi

Pemeriksaan statis berhasil untuk keseimbangan tanda kurung, import direktori lokal, singleton vs `qmldir`, referensi token konfigurasi, dan codepoint icon pada font asli. **Belum ada uji eksekusi QML/Hyprland** karena lingkungan ini tidak menyediakan Quickshell maupun compositor; koneksi Wi-Fi nyata dan multi-monitor harus divalidasi di mesin pengguna.

## Paket

ZIP hasil perbaikan tidak menyertakan riwayat `.git/` yang memenuhi sebagian besar ukuran arsip asal. Source, file `.qml.bak`, font dan asset asli tetap dipertahankan. Sebelum memasang, backup dotfiles lama.
