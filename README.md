# NETRI Exam (Tahap 1)
> **Ujian Terkunci & Pengawasan Realtime untuk Google Forms**

NETRI Exam adalah platform ujian terkunci (*secure exam browser & proctoring shield*) berbasis mobile (Android 10+ dan iOS 16+) yang membuka Google Forms di dalam jendela aman, mencatat setiap indikasi kecurangan secara terukur, dan menyediakan pengawasan realtime bagi institusi pendidikan (sekolah dan perguruan tinggi).

---

## 1. Arsitektur & Filosofi Sistem

Sistem beroperasi berdasarkan filosofi **Ponytail Protocol (YAGNI & Zero-Bloat)**:
- **Google Forms sebagai Runtime Soal:** Beban penyimpanan soal, kalkulasi, dan pengiriman jawaban ditanggung langsung oleh infrastruktur Google.
- **NETRI sebagai Pembungkus Aman (*Secure Wrapper*):** Server NETRI hanya menangani autentikasi perangkat tunggal, pelepasan tautan form secara bergelombang (*jittered release*), heartbeat periodik (20 detik), dan pencatatan pelanggaran idempoten.
- **Ketahanan Jaringan (*Fail-Open Resilience*):** Jika server NETRI atau koneksi internet lokal mengalami gangguan sementara, ujian siswa tidak akan digugurkan. Kejadian pelanggaran diantrekan secara lokal di perangkat dan disinkronkan kembali menggunakan strategi *exponential backoff* dan *jitter*.

---

## 2. Fitur Utama

- 🔒 **Lock Task & Screen Pinning:** Mencegah siswa keluar dari jendela ujian atau membuka aplikasi lain tanpa izin pengawas.
- 🚫 **Proteksi Tangkapan Layar & Rekam Layar:** Mengaktifkan `FLAG_SECURE` di Android (tangkapan layar otomatis menjadi layar hitam) serta deteksi *screen capture* di iOS.
- ⏱️ **ExamBar Tipis & Timer Tabular:** Menampilkan hitung mundur waktu ujian yang disinkronkan dengan server menggunakan angka tabular (*tabular figures*) untuk mencegah pergeseran tata letak (*CLS < 0.1*).
- 🌐 **Whitelist Navigasi Domain:** Hanya mengizinkan pemuatan domain resmi Google Form (`docs.google.com`, `forms.google.com`, `gstatic.com`). Seluruh navigasi ke tautan luar diblokir dan dicatat.
- 🛡️ **Masa Tenggang & Sistem Strike Terukur:** Masa tenggang 10 detik untuk interupsi sah (panggilan telepon darurat masuk / panel notifikasi sistem). Pelanggaran berat mengunci sesi dan mewajibkan verifikasi PIN pengawas.
- 📱 **Satu Perangkat Aktif (Single Device Binding):** Akun siswa terikat pada satu ID perangkat keras untuk mencegah joki atau login ganda.

---

## 3. Sistem Desain: Apple HIG & UI/UX Pro Max

Antarmuka NETRI Exam dirancang dengan prinsip **Calm & Focused** berbasis estetika *Minimalism & Swiss Style*:
- **Sumber Kebenaran Tunggal (SSOT):** Seluruh token warna, skala tipografi, spasi kelipatan 4pt, dan radius border didefinisikan di `tokens/tokens.json` dan dikompilasi ke Dart (`lib/core/theme/tokens.g.dart`) serta CSS Variables (`tokens/tokens.css`).
- **Aksesibilitas Tinggi:** Kontras warna memenuhi standar WCAG AA ($\ge 4.5:1$) pada mode Terang maupun Gelap (OLED Dark Mode).
- **Interaksi Ergonomis:** Seluruh elemen interaktif memiliki target sentuh minimal $44 \times 44\text{ pt}$ (`kMinInteractiveDimension`).
- **Pola Kontekstual Apple HIG:** Lembar penjelas privasi (*Pre-permission Contextual Sheet*) ditampilkan sebelum meminta izin sistem operasi. Pesan pelanggaran dirancang objektif dan tidak menuduh (*non-accusatory copy*).

---

## 4. Struktur Proyek (`Feature-First`)

```text
lib/
├── core/
│   ├── theme/             # Design tokens yang di-generate dari tokens.json & ThemeData
│   ├── network/           # API Client dengan fallback antrean offline
│   ├── storage/           # Antrean lokal pelanggaran (OfflineViolationQueue)
│   └── errors/            # Global Error Boundary untuk mencegah white screen crash
├── contracts/             # SSOT Model Data & DTO serialisasi
├── features/
│   ├── auth/              # Layar login & pengikatan ID perangkat
│   ├── exam_list/         # Daftar ujian dengan 5 state (Default, Loading, Empty, Error, Disabled)
│   ├── precheck/          # Pemeriksaan baterai, DND, integritas OS, & lembar persetujuan
│   ├── exam_session/      # Secure WebView, ExamBar, & LockScreenDialog
│   ├── lockdown/          # Layanan penguncian native platform channel
│   └── result/            # Tanda terima bukti selesai ujian
└── app.dart & main.dart   # Root App Shell & Handler Error Platform
```

---

## 5. Panduan Instalasi & Menjalankan

### Prasyarat
- Flutter SDK $\ge 3.22.0$ (disarankan Flutter 3.44+)
- Dart SDK $\ge 3.4.0$
- Python 3.10+ (untuk generator token)

### Menjalankan Aplikasi Mobile
```bash
# 1. Unduh seluruh dependensi
flutter pub get

# 2. Kompilasi ulang token desain (jika tokens.json diubah)
python scripts/generate_tokens.py

# 3. Jalankan pemeriksaan kualitas statis
flutter analyze

# 4. Jalankan pengujian smoke-test
flutter test

# 5. Jalankan aplikasi di emulator atau perangkat fisik
flutter run
```

---

## 6. Lisensi & Hak Cipta

Hak Cipta © 2026 Tim Pengembang NETRI Exam. Seluruh hak cipta dilindungi undang-undang.
