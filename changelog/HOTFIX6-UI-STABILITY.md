# Hotfix 6 — Stabilitas Quick Control, Arch AI, dan Settings

Target: **Quickshell 0.3.1** (Arch Linux), Hyprland. Basis: Hotfix 5 milik proyek ini.

## Diagnosis berdasarkan screenshot + audit source Hotfix 5

1. **Bluetooth dropdown tampak tidak berfungsi.** `cardHeight` bergantung pada `details.implicitHeight`, padahal `details.visible` terkait state expanded. Pengukuran tinggi konten yang sedang tersembunyi tidak aman dan tidak dibatasi terhadap daftar device. Perbaikannya: `Layout.preferredHeight` eksplisit, `Flickable` internal, scroll untuk daftar device, status adapter/kondisi kosong, tombol scan/pair/connect/disconnect tetap native BlueZ.
2. **Battery dropdown tampak tidak berfungsi.** Pola pengukuran tinggi konten yang sama dengan Bluetooth. Profil daya dapat terpotong di luar batas `Rectangle { clip: true }`. Perbaikannya: tinggi panel yang pasti dan body scroll; 3 profil + status UPower tetap terlihat. Persentase baterai dari hotfix sebelumnya dipertahankan (`percentage * 100`).
3. **System overlapping / clipping.** Baris indikator bercampur posisi absolut dan layout, sementara baris Storage meminta dua teks dalam tinggi mirip baris lain. Di screenshot, System juga panjang karena Wi-Fi bersamaan expanded. Perbaikan: `ColumnLayout` per metrik, Storage mendapat row khusus 74px, progress bar terpisah, `GiB available` tetap dari `df -B1 /`, dan accordion hanya membuka satu seksi Quick Control.
4. **Arch AI rusak total secara visual.** Composer menggunakan child `Layout.fillHeight` di area footer tanpa batas tinggi maksimum sehingga bisa mencuri ruang chat dan tombol Send menjadi setinggi panel. Perbaikan: header 48px, area pesan `Layout.fillHeight`, footer status 18px dan composer persis 48px; welcome state di tengah; bubble respons terbungkus teks (`PlainText`), bukan melebar keluar panel.
5. **Full Settings tampak aneh dan terlalu kosong.** Halaman lama hanya mengisi area atas dengan deretan option, tanpa area pratinjau dan navigasi yang jelas. Perbaikan: sidebar navigasi konsisten, area konten terpisah, live palette preview, choice kartu 46px, ringkasan bar, monitor, Ollama, About, footer status. `SettingsStore` dan palet lama tidak diganti.

## Perubahan arsitektur

- `Store.activeQuickSection`: state satu accordion untuk Wi-Fi, Bluetooth, Battery dan System; klik item aktif akan menutupnya; klik item lain menutup yang lama dan membuka yang baru.
- Bluetooth/Battery memakai tinggi expanded eksplisit dan scroll sendiri sehingga isi tidak tergantung `implicitHeight` children tersembunyi.
- Status sebenarnya diambil dari API Quickshell 0.3.1 (`Quickshell.Bluetooth`, `UPower`, `PowerProfiles`), tanpa data atau hasil fiktif.
- Arch AI tetap menggunakan localhost Ollama via `curl` dengan argv (tanpa interpolasi shell). Sidebar **tidak akan** menghasilkan jawaban AI jika Ollama/model tidak ada. Untuk mengaktifkan: `ollama serve` dan `ollama pull llama3.2` (atau model lain dari Settings).
- Base Gruvbox `#282828`, `#3c3836`, `#ebdbb2`, Google Material Symbols (`assets/google.ttf`) dan Poppins dipertahankan. Aksen tetap dapat dipilih dari Settings.

## Smoke test di lingkungan asli

1. Backup direktori lama. Ekstrak ZIP, lalu jalankan `qs -p ./quickshell` dari folder induk ekstraksi. Gunakan `qs log -f` di terminal lain.
2. Klik Quick Control: Wi-Fi terbuka. Klik Bluetooth: Wi-Fi menutup dan Bluetooth terbuka. Nyalakan Bluetooth dan coba Scan. Tanpa adapter harus muncul penjelasan, **bukan** panel kosong.
3. Klik Battery: profil Power Saver, Balanced, Performance terlihat; coba switch. Diperlukan backend power-profile yang kompatibel (contoh `power-profiles-daemon` atau `tuned-ppd`, jangan jalankan dua layanan yang berkonflik).
4. Klik System: keempat metrik terlihat tanpa overlap; Storage memiliki nilai used/total dan nilai GiB available. Cek hasil terhadap `df -B1 /`.
5. Klik logo Arch: chat dan tombol kirim berukuran tetap di bagian bawah; coba kirim prompt, cek error offline atau respons real dari Ollama. Klik Settings dari header AI.
6. Dari Advance > See full settings: pilih empat aksen, tukar tab Bar, Displays, Local AI dan About; kembali ke Appearance dan cek preview mengikuti aksen.
7. Kecilkan resolusi layar atau naikkan UI scale bila diperlukan; pastikan konten panjang masih bisa di-scroll.

## Yang belum dapat diklaim

- **Belum diuji runtime di sesi Hyprland pengguna**. Pemeriksaan yang tersedia di lingkungan penyiapan adalah statis: integritas ZIP, kurung QML, import lokal, registrasi `qmldir`, dan glyph icon.
- Bluetooth scan/pair perlu hardware, BlueZ, izin dan agent pairing.
- PowerProfiles butuh backend profile sistem yang aktif.
- AI butuh service Ollama, model terpasang, serta `curl`.
- Tidak mengubah modul aplikasi lain di luar bug yang dibahas.

Referensi API resmi Quickshell 0.3.1:
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/BluetoothAdapter/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Bluetooth/BluetoothDevice/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.UPower/PowerProfiles/
- https://quickshell.org/docs/v0.3.1/types/Quickshell/PanelWindow/
