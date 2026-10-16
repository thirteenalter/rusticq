# Notification design refresh

## Perubahan
- Toast notification didesain ulang dengan spacing lebih rapi, hierarki teks lebih jelas, dan badge kategori.
- Notification center history card sekarang memakai layout yang lebih seimbang dan konsisten dengan style RusticQ.
- Screenshot notification otomatis memakai styling yang lebih cocok dan dapat menampilkan preview image jika disediakan oleh pengirim notifikasi.
- Parsing source image dinormalisasi agar path lokal dapat dibuka sebagai preview thumbnail.

## File utama
- `services/NotificationCenter.qml`
- `modules/main/NotificationToasts.qml`
- `modules/bar/BarNotifications.qml`
