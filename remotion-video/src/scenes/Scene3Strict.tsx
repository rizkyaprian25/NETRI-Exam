// Babak 3: Konfirmasi Kiosk & Pengawasan Manual Guru (Tanpa Batas Timer Panik)
// Menampilkan bottom sheet peraturan, otomatisasi layar 100%, volume 100%, dan pengawasan humanis

import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { PhoneMockup } from '../components/PhoneMockup';
import { SubtitleBar } from '../components/SubtitleBar';

export const Scene3Strict: React.FC = () => {
  const frame = useCurrentFrame();

  // Animasi Naiknya Bottom Sheet
  const sheetY = interpolate(frame, [10, 35], [400, 0], { extrapolateRight: 'clamp' });

  return (
    <div
      style={{
        flex: 1,
        width: '100%',
        height: '100%',
        backgroundColor: '#0F172A',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '0 80px',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      {/* Kolom Kiri: Penjelasan Aturan & Pendekatan Humanis */}
      <div style={{ flex: 1, maxWidth: 640, zIndex: 10 }}>
        <div
          style={{
            display: 'inline-block',
            backgroundColor: 'rgba(16, 185, 129, 0.2)',
            color: '#34D399',
            padding: '6px 14px',
            borderRadius: 8,
            fontWeight: 700,
            fontSize: 14,
            marginBottom: 16,
          }}
        >
          FITUR TERBARU • FLEKSIBILITAS GURU
        </div>

        <h2 style={{ color: '#FFFFFF', fontSize: 44, fontWeight: 800, marginBottom: 16 }}>
          Pengawasan Ujian Fleksibel & Terkendali
        </h2>

        <p style={{ color: '#94A3B8', fontSize: 20, lineHeight: 1.5, marginBottom: 28 }}>
          Batas waktu otomatis ditiadakan agar siswa tidak panik terpotong di tengah jalan. Pengingat waktu sepenuhnya dikomandoi langsung oleh bapak/ibu guru pengawas di kelas.
        </p>

        {/* Feature Pills */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>💡</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Layar & Suara Otomatis 100% (Anti Trik Gelap/Mute)
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>👨‍🏫</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Waktu Dikendalikan Penuh oleh Guru Pengawas
            </span>
          </div>
        </div>
      </div>

      {/* Kolom Kanan: Phone Mockup dengan Lembar Konfirmasi Naik */}
      <div style={{ position: 'relative' }}>
        <PhoneMockup>
          <div
            style={{
              flex: 1,
              backgroundColor: '#CBD5E1',
              display: 'flex',
              flexDirection: 'column',
              position: 'relative',
              overflow: 'hidden',
            }}
          >
            {/* Latar Belakang Redup */}
            <div
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                backgroundColor: 'rgba(0,0,0,0.4)',
              }}
            />

            {/* Bottom Sheet Peraturan */}
            <div
              style={{
                marginTop: 'auto',
                transform: `translateY(${sheetY}px)`,
                backgroundColor: '#FFFFFF',
                borderTopLeftRadius: 28,
                borderTopRightRadius: 28,
                padding: '24px 20px',
                display: 'flex',
                flexDirection: 'column',
                gap: 14,
                boxShadow: '0 -10px 30px rgba(0,0,0,0.2)',
              }}
            >
              {/* Header Modal */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div
                  style={{
                    width: 42,
                    height: 42,
                    borderRadius: '50%',
                    backgroundColor: '#EFF6FF',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#2563EB',
                    fontSize: 20,
                  }}
                >
                  🛡️
                </div>
                <div>
                  <div style={{ fontWeight: 800, fontSize: 15, color: '#0F172A' }}>
                    Mode Ujian Ketat
                  </div>
                  <div style={{ fontSize: 11, color: '#2563EB', fontWeight: 600 }}>
                    Pengawasan Guru • Layar 100% • Suara 100%
                  </div>
                </div>
              </div>

              {/* Rincian Poin */}
              <div
                style={{
                  backgroundColor: '#F8FAFC',
                  borderRadius: 14,
                  padding: 12,
                  fontSize: 11,
                  lineHeight: 1.5,
                  color: '#334155',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 6,
                }}
              >
                <div>• Kecerahan layar & volume suara otomatis disetel 100%.</div>
                <div>• Notifikasi ditutup & dilarang membuka aplikasi lain.</div>
                <div>• Mencoba keluar akan membunyikan sirine keras 5 detik!</div>
              </div>

              {/* Tombol Konfirmasi Siap */}
              <div
                style={{
                  backgroundColor: '#2563EB',
                  color: '#FFFFFF',
                  padding: '12px 0',
                  borderRadius: 12,
                  textAlign: 'center',
                  fontWeight: 700,
                  fontSize: 13,
                  marginTop: 6,
                  boxShadow: '0 4px 12px rgba(37, 99, 235, 0.35)',
                }}
              >
                Saya Siap & Mulai Mengerjakan
              </div>
            </div>
          </div>
        </PhoneMockup>
      </div>

      <SubtitleBar
        stepBadge="Babak 3 • Aturan Ujian"
        narrationText="Batas waktu otomatis ditiadakan demi kenyamanan siswa — pengawasan dan peringatan waktu dilakukan sepenuhnya secara manual oleh bapak/ibu guru pengawas di dalam kelas."
        highlightKeyword="Kontrol Humanis Guru"
      />
    </div>
  );
};
