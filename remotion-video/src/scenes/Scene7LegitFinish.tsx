// Babak 7: Pengiriman Sah & Penutup Elegan
// Menampilkan deteksi otomatis formResponse, pelepasan kunci sah, dan ResultScreen terverifikasi

import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { PhoneMockup } from '../components/PhoneMockup';
import { SubtitleBar } from '../components/SubtitleBar';

export const Scene7LegitFinish: React.FC = () => {
  const frame = useCurrentFrame();

  // Transisi dari Form Terkirim ke ResultScreen
  const isFinished = frame >= 80;
  const resultCardY = interpolate(frame, [80, 110], [50, 0], { extrapolateRight: 'clamp' });

  return (
    <div
      style={{
        flex: 1,
        width: '100%',
        height: '100%',
        backgroundColor: '#0B0F19',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '0 80px',
        position: 'relative',
        overflow: 'hidden',
      }}
    >
      {/* Kolom Kiri: Penutup & Pesan Integritas */}
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
          SELESAI RESMI & SAH
        </div>

        <h2 style={{ color: '#FFFFFF', fontSize: 44, fontWeight: 800, marginBottom: 16 }}>
          Pengiriman Sah Tanpa Celah Curang
        </h2>

        <p style={{ color: '#94A3B8', fontSize: 20, lineHeight: 1.5, marginBottom: 28 }}>
          Satu-satunya jalan keluar adalah menekan tombol Kirim pada Google Form. Begitu terkirim, status penguncian dilepas otomatis dengan verifikasi integritas penuh.
        </p>

        {/* Feature List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>✅</span>
            <span style={{ color: '#86EFAC', fontSize: 18, fontWeight: 600 }}>
              Deteksi Otomatis formResponse Google Form
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>🏫</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Siap untuk Asesmen Sumatif & Ujian Sekolah SMPN 3 Cibungbulang
            </span>
          </div>
        </div>
      </div>

      {/* Kolom Kanan: Phone Mockup ResultScreen */}
      <div style={{ position: 'relative' }}>
        <PhoneMockup>
          <div
            style={{
              flex: 1,
              backgroundColor: '#FFFFFF',
              display: 'flex',
              flexDirection: 'column',
              padding: 24,
              justifyContent: 'center',
              alignItems: 'center',
              textAlign: 'center',
              fontFamily: 'sans-serif',
            }}
          >
            {/* Lingkaran Sukses Hijau Besar */}
            <div
              style={{
                width: 90,
                height: 90,
                borderRadius: '50%',
                backgroundColor: '#DCFCE7',
                border: '3px solid #22C55E',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                marginBottom: 20,
                boxShadow: '0 10px 25px rgba(34, 197, 94, 0.3)',
              }}
            >
              <span style={{ fontSize: 44 }}>✅</span>
            </div>

            <div
              style={{
                backgroundColor: '#F0FDF4',
                color: '#15803D',
                padding: '4px 14px',
                borderRadius: 20,
                fontSize: 12,
                fontWeight: 700,
                marginBottom: 12,
                border: '1px solid #BBF7D0',
              }}
            >
              Terkunci & Sah
            </div>

            <h3 style={{ fontSize: 20, fontWeight: 800, color: '#0F172A', marginBottom: 8 }}>
              Sesi Ujian Selesai!
            </h3>

            <p style={{ fontSize: 12, color: '#64748B', lineHeight: 1.5, marginBottom: 24 }}>
              Jawaban Anda telah berhasil dikirim ke server sekolah. Seluruh sistem penguncian telah dinonaktifkan.
            </p>

            {/* Tombol Kembali ke Beranda */}
            <div
              style={{
                width: '100%',
                backgroundColor: '#2563EB',
                color: '#FFFFFF',
                padding: '12px 0',
                borderRadius: 12,
                fontWeight: 700,
                fontSize: 13,
                boxShadow: '0 4px 12px rgba(37, 99, 235, 0.3)',
              }}
            >
              Kembali ke Beranda
            </div>
          </div>
        </PhoneMockup>
      </div>

      <SubtitleBar
        stepBadge="Babak 7 • Selesai Sah"
        narrationText="Satu-satunya cara menyelesaikan ujian adalah dengan mengirimkan formulir jawaban secara sah. Bersama NETRI Exam, mari ciptakan asesmen digital yang jujur dan berintegritas!"
        highlightKeyword="Ujian Jujur & Berintegritas"
      />
    </div>
  );
};
