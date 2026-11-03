// Babak 2: Beranda & Dua Metode Input Soal (Scan QR / Paste Link)
// Menampilkan kecepatan pemindaian QR Code kamera dan validasi otomatis Google Forms

import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { PhoneMockup } from '../components/PhoneMockup';
import { SubtitleBar } from '../components/SubtitleBar';

export const Scene2Login: React.FC = () => {
  const frame = useCurrentFrame();

  // Mode Animasi Scan QR (frame 90 - 240)
  const isScanning = frame >= 80 && frame <= 220;
  const scanLineY = interpolate(frame % 60, [0, 60], [20, 220]);
  const urlFilled = frame > 230;

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
      {/* Kolom Kiri: Penjelasan Alur */}
      <div style={{ flex: 1, maxWidth: 650, zIndex: 10 }}>
        <div
          style={{
            display: 'inline-block',
            backgroundColor: 'rgba(37, 99, 235, 0.2)',
            color: '#60A5FA',
            padding: '6px 14px',
            borderRadius: 8,
            fontWeight: 700,
            fontSize: 14,
            marginBottom: 16,
          }}
        >
          LANGKAH 1 DARI 3
        </div>

        <h2 style={{ color: '#FFFFFF', fontSize: 46, fontWeight: 800, marginBottom: 16 }}>
          Input Soal Instan & Terverifikasi
        </h2>

        <p style={{ color: '#94A3B8', fontSize: 20, lineHeight: 1.5, marginBottom: 30 }}>
          Siswa tidak perlu mengetik alamat panjang. Cukup pindai QR Code di lembar soal pengawas atau tempel tautan formulir Google Forms.
        </p>

        {/* Feature List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>📷</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Scan QR Code Kamera Cepat (1 Detik)
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>🛡️</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Whitelist Validasi Ketat Google Forms
            </span>
          </div>
        </div>
      </div>

      {/* Kolom Kanan: Phone Mockup LoginScreen */}
      <div style={{ position: 'relative' }}>
        <PhoneMockup>
          <div
            style={{
              flex: 1,
              backgroundColor: '#FFFFFF',
              padding: '24px 20px',
              display: 'flex',
              flexDirection: 'column',
              fontFamily: 'sans-serif',
              position: 'relative',
            }}
          >
            {/* Header Status */}
            <div style={{ textAlign: 'center', marginTop: 16, marginBottom: 20 }}>
              <div
                style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: 6,
                  backgroundColor: '#EFF6FF',
                  padding: '4px 12px',
                  borderRadius: 20,
                  border: '1px solid #BFDBFE',
                }}
              >
                <span style={{ fontSize: 12 }}>🛡️</span>
                <span style={{ fontSize: 11, fontWeight: 700, color: '#1D4ED8' }}>
                  Aplikasi Ujian Aman (Anti-Curang)
                </span>
              </div>
            </div>

            {/* Kotak Formulir */}
            <div
              style={{
                backgroundColor: '#F8FAFC',
                borderRadius: 16,
                padding: 16,
                border: '1px solid #E2E8F0',
                display: 'flex',
                flexDirection: 'column',
                gap: 12,
              }}
            >
              <div style={{ fontWeight: 700, fontSize: 13, color: '#0F172A' }}>
                Tautan Formulir Ujian
              </div>

              {/* Input Field */}
              <div
                style={{
                  backgroundColor: '#FFFFFF',
                  border: '1px solid #CBD5E1',
                  borderRadius: 10,
                  padding: '10px 12px',
                  fontSize: 12,
                  color: urlFilled ? '#1E293B' : '#94A3B8',
                  overflow: 'hidden',
                  textOverflow: 'ellipsis',
                  whiteSpace: 'nowrap',
                }}
              >
                {urlFilled
                  ? 'https://forms.gle/UjianMatematikaSMPN3'
                  : 'Pindai QR Code atau tempel link...'}
              </div>

              {/* Tombol Scan QR */}
              <div
                style={{
                  border: '1px solid #2563EB',
                  borderRadius: 10,
                  padding: '10px 0',
                  textAlign: 'center',
                  color: '#2563EB',
                  fontWeight: 700,
                  fontSize: 12,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: 6,
                  backgroundColor: isScanning ? '#EFF6FF' : '#FFFFFF',
                }}
              >
                <span>📷</span>
                <span>Scan QR Code Soal</span>
              </div>

              {/* Tombol Mulai Ujian */}
              <div
                style={{
                  backgroundColor: '#2563EB',
                  borderRadius: 10,
                  padding: '12px 0',
                  textAlign: 'center',
                  color: '#FFFFFF',
                  fontWeight: 700,
                  fontSize: 14,
                  marginTop: 6,
                  boxShadow: '0 4px 10px rgba(37, 99, 235, 0.3)',
                }}
              >
                Mulai Ujian ▶
              </div>
            </div>

            {/* Simulasi Pop-up Pemindai QR Kamera */}
            {isScanning && (
              <div
                style={{
                  position: 'absolute',
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  backgroundColor: '#000000',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  zIndex: 40,
                }}
              >
                {/* Kotak Bidik Scanner */}
                <div
                  style={{
                    width: 200,
                    height: 200,
                    border: '3px solid #3B82F6',
                    borderRadius: 20,
                    position: 'relative',
                    overflow: 'hidden',
                  }}
                >
                  {/* Garis Laser Merah Pemindai */}
                  <div
                    style={{
                      position: 'absolute',
                      left: 0,
                      right: 0,
                      top: scanLineY,
                      height: 3,
                      backgroundColor: '#EF4444',
                      boxShadow: '0 0 10px #EF4444',
                    }}
                  />
                </div>
                <div style={{ color: '#FFFFFF', fontSize: 12, marginTop: 16 }}>
                  Arahkan kamera ke QR Code Soal
                </div>
              </div>
            )}
          </div>
        </PhoneMockup>
      </div>

      <SubtitleBar
        stepBadge="Babak 2 • Masuk Soal"
        narrationText="Siswa cukup memindai QR Code soal dari pengawas hanya dalam 1 detik, atau menempelkan tautan Google Forms. Sistem otomatis memvalidasi tautan resmi sekolah."
        highlightKeyword="Scan QR 1 Detik"
      />
    </div>
  );
};
