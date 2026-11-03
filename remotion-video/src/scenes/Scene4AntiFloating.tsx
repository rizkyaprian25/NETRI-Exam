// Babak 4: Anti Floating Apps & Tirai Pelindung Keamanan (Security Curtain)
// Menunjukkan deteksi jendela mengambang (Chrome), tirai hitam proteksi, dan pembunuhan paksa floating apps

import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { PhoneMockup } from '../components/PhoneMockup';
import { SubtitleBar } from '../components/SubtitleBar';
import { SecurityCurtain } from '../components/SecurityCurtain';

export const Scene4AntiFloating: React.FC = () => {
  const frame = useCurrentFrame();

  // Fase 1: Chrome Mengambang Muncul (frame 0 - 150)
  // Fase 2: Tirai Pelindung Jatuh (frame 150 - 350)
  // Fase 3: Tombol Kunci Ditekan & Floating Chrome Hilang (frame 350+)
  const showFloatingChrome = frame < 360;
  const showCurtain = frame >= 140 && frame < 420;
  const examSheetVisible = frame >= 420;

  const chromeScale = interpolate(frame, [0, 40, 340, 360], [0, 1, 1, 0], {
    extrapolateRight: 'clamp',
  });

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
      {/* Kolom Kiri: Penjelasan Mekanisme Proteksi */}
      <div style={{ flex: 1, maxWidth: 650, zIndex: 10 }}>
        <div
          style={{
            display: 'inline-block',
            backgroundColor: 'rgba(239, 68, 68, 0.2)',
            color: '#F87171',
            padding: '6px 14px',
            borderRadius: 8,
            fontWeight: 700,
            fontSize: 14,
            marginBottom: 16,
          }}
        >
          FITUR UNGGULAN • LAPIS KEAMANAN 4 TINGKAT
        </div>

        <h2 style={{ color: '#FFFFFF', fontSize: 44, fontWeight: 800, marginBottom: 16 }}>
          Anti Floating Apps & Tirai Pelindung
        </h2>

        <p style={{ color: '#94A3B8', fontSize: 20, lineHeight: 1.5, marginBottom: 28 }}>
          Siswa mencoba trik membuka Google Chrome dalam jendela mengambang (*floating window*)? Sistem seketika menutup lembar soal dengan Tirai Pelindung dan menutup paksa jendela mengambang.
        </p>

        {/* Feature List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>🛑</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Tirai Pelindung Hitam Menutupi Soal Saat Ada Floating App
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>⚡</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Sematkan Layar (Lock Task) Mematikan Paksa Semua Floating App
            </span>
          </div>
        </div>
      </div>

      {/* Kolom Kanan: Phone Mockup Simulasi */}
      <div style={{ position: 'relative' }}>
        <PhoneMockup highlightBorder={showCurtain}>
          <div
            style={{
              flex: 1,
              backgroundColor: '#F8FAFC',
              display: 'flex',
              flexDirection: 'column',
              position: 'relative',
            }}
          >
            {/* Lembar Soal Latar Belakang */}
            <div style={{ flex: 1, padding: 16, opacity: showCurtain ? 0.2 : 1 }}>
              <div style={{ fontWeight: 700, fontSize: 13, color: '#1E40AF', marginBottom: 10 }}>
                ASESMEN SUMATIF MATEMATIKA KELAS 8
              </div>
              <div
                style={{
                  backgroundColor: '#FFFFFF',
                  borderRadius: 12,
                  padding: 14,
                  border: '1px solid #E2E8F0',
                  marginBottom: 10,
                }}
              >
                <div style={{ fontSize: 12, fontWeight: 600, color: '#1E293B', marginBottom: 6 }}>
                  1. Nilai dari 3x + 5 = 20 adalah...
                </div>
                <div style={{ fontSize: 11, color: '#64748B' }}>○ A. 5</div>
                <div style={{ fontSize: 11, color: '#64748B' }}>○ B. 10</div>
              </div>
            </div>

            {/* Simulasi Jendela Mengambang Chrome (Floating App) */}
            {showFloatingChrome && (
              <div
                style={{
                  position: 'absolute',
                  top: 90,
                  right: 14,
                  width: 170,
                  height: 200,
                  backgroundColor: '#FFFFFF',
                  borderRadius: 16,
                  boxShadow: '0 15px 35px rgba(0,0,0,0.4)',
                  border: '2px solid #3B82F6',
                  transform: `scale(${chromeScale})`,
                  display: 'flex',
                  flexDirection: 'column',
                  overflow: 'hidden',
                  zIndex: 70,
                }}
              >
                {/* Header Floating Chrome */}
                <div
                  style={{
                    backgroundColor: '#E2E8F0',
                    padding: '6px 8px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                  }}
                >
                  <span style={{ fontSize: 10, fontWeight: 700, color: '#334155' }}>
                    🌐 Google Chrome
                  </span>
                  <span style={{ fontSize: 10, color: '#EF4444' }}>✕</span>
                </div>
                {/* Isi Mini Pencarian Google */}
                <div style={{ padding: 10, flex: 1, backgroundColor: '#FFFFFF' }}>
                  <div
                    style={{
                      border: '1px solid #CBD5E1',
                      borderRadius: 14,
                      padding: '4px 6px',
                      fontSize: 9,
                      color: '#475569',
                      marginBottom: 8,
                    }}
                  >
                    🔍 Kunci jawaban mat...
                  </div>
                  <div style={{ fontSize: 8, color: '#64748B' }}>
                    Hasil pencarian rumus matematika...
                  </div>
                </div>
              </div>
            )}

            {/* Tirai Pelindung Menutupi Soal */}
            {showCurtain && (
              <SecurityCurtain
                isObscured={true}
                onButtonClickText="Kunci Layar & Tutup Floating Apps"
              />
            )}
          </div>
        </PhoneMockup>
      </div>

      <SubtitleBar
        stepBadge="Babak 4 • Anti Floating"
        narrationText="Bagaimana jika siswa mencoba membuka Chrome floating window? Sistem pertahanan berlapis NETRI Exam otomatis menutup soal dengan Tirai Pelindung dan menutup paksa semua aplikasi mengambang."
        highlightKeyword="Tutup Paksa Floating Apps"
      />
    </div>
  );
};
