// Babak 1: Hook & Pengenalan Masalah Ujian di Smartphone Siswa
// Menampilkan logo sekolah, tantangan multitasking/contekan, dan perkenalan NETRI Exam

import React from 'react';
import { interpolate, spring, useCurrentFrame, useVideoConfig } from 'remotion';
import { PhoneMockup } from '../components/PhoneMockup';
import { SubtitleBar } from '../components/SubtitleBar';

export const Scene1Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Animasi Masuk Judul & Logo
  const titleOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: 'clamp' });
  const titleScale = spring({ frame, fps, config: { damping: 12 } });

  // Animasi Telepon Rentan Contekan
  const phoneX = interpolate(frame, [15, 45], [100, 0], { extrapolateRight: 'clamp' });
  const alertBadgeOpacity = interpolate(frame, [45, 60], [0, 1], { extrapolateRight: 'clamp' });

  return (
    <div
      style={{
        flex: 1,
        width: '100%',
        height: '100%',
        backgroundColor: '#0B0F19',
        background: 'radial-gradient(circle at 50% 40%, #1E293B 0%, #0B0F19 100%)',
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '0 80px',
        overflow: 'hidden',
      }}
    >
      {/* Kolom Kiri: Branding & Pesan Kunci */}
      <div
        style={{
          flex: 1,
          opacity: titleOpacity,
          transform: `scale(${titleScale})`,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'flex-start',
          zIndex: 10,
        }}
      >
        {/* Badge Sekolah Resmi */}
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            backgroundColor: 'rgba(37, 99, 235, 0.15)',
            border: '1px solid rgba(59, 130, 246, 0.3)',
            padding: '8px 18px',
            borderRadius: 30,
            marginBottom: 24,
          }}
        >
          <span style={{ fontSize: 20 }}>🏫</span>
          <span style={{ color: '#60A5FA', fontSize: 16, fontWeight: 700 }}>
            SMP Negeri 3 Cibungbulang
          </span>
        </div>

        <h1
          style={{
            color: '#FFFFFF',
            fontSize: 54,
            fontWeight: 800,
            lineHeight: 1.15,
            marginBottom: 16,
          }}
        >
          Ujian Digital Bebas Celah di Smartphone Siswa
        </h1>

        <p
          style={{
            color: '#94A3B8',
            fontSize: 22,
            lineHeight: 1.5,
            maxWidth: 620,
            marginBottom: 36,
          }}
        >
          Mengunci browser, menutup celah aplikasi mengambang, mematikan tombol curang, dan membunyikan alarm sirine seketika.
        </p>

        {/* Feature Pills */}
        <div style={{ display: 'flex', gap: 16 }}>
          <div
            style={{
              backgroundColor: 'rgba(239, 68, 68, 0.15)',
              border: '1px solid rgba(239, 68, 68, 0.4)',
              color: '#F87171',
              padding: '10px 20px',
              borderRadius: 14,
              fontSize: 16,
              fontWeight: 700,
            }}
          >
            🚫 Anti Browsing & Chat
          </div>
          <div
            style={{
              backgroundColor: 'rgba(59, 130, 246, 0.15)',
              border: '1px solid rgba(59, 130, 246, 0.4)',
              color: '#93C5FD',
              padding: '10px 20px',
              borderRadius: 14,
              fontSize: 16,
              fontWeight: 700,
            }}
          >
            🔒 100% Kiosk Terkunci
          </div>
        </div>
      </div>

      {/* Kolom Kanan: Mockup Smartphone dengan Ilusi Gangguan Chat */}
      <div
        style={{
          transform: `translateX(${phoneX}px)`,
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <PhoneMockup highlightBorder={frame > 60}>
          <div
            style={{
              flex: 1,
              backgroundColor: '#F1F5F9',
              padding: 24,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              position: 'relative',
            }}
          >
            {/* Pop-up WA Masuk Palsu (Simulasi Kerentanan HP Biasa) */}
            <div
              style={{
                width: '100%',
                backgroundColor: '#FFFFFF',
                borderRadius: 16,
                padding: 14,
                boxShadow: '0 10px 25px rgba(0, 0, 0, 0.1)',
                border: '1px solid #E2E8F0',
                marginBottom: 16,
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
                <span style={{ fontSize: 18 }}>💬</span>
                <span style={{ fontWeight: 700, fontSize: 13, color: '#166534' }}>WhatsApp Group Kelas</span>
              </div>
              <p style={{ margin: 0, fontSize: 12, color: '#334155' }}>
                "Bro, nomor 15 jawabannya A atau C?"
              </p>
            </div>

            {/* Badge Peringatan Sistem */}
            <div
              style={{
                opacity: alertBadgeOpacity,
                backgroundColor: '#FEE2E2',
                border: '2px solid #EF4444',
                color: '#B91C1C',
                padding: '16px',
                borderRadius: 16,
                textAlign: 'center',
                marginTop: 20,
              }}
            >
              <div style={{ fontSize: 24, marginBottom: 6 }}>⚠️</div>
              <div style={{ fontWeight: 800, fontSize: 14 }}>BAHAYA KECURANGAN!</div>
              <div style={{ fontSize: 11, marginTop: 4 }}>
                Tanpa penguncian Kiosk, siswa bebas membuka aplikasi lain & browsing contekan.
              </div>
            </div>
          </div>
        </PhoneMockup>
      </div>

      {/* Subtitle Bar */}
      <SubtitleBar
        stepBadge="Babak 1 • Tantangan"
        narrationText="Melaksanakan ujian menggunakan smartphone siswa sering kali memicu kekhawatiran: membuka contekan, browsing jawaban, hingga aplikasi mengambang. Kini hadir NETRI Exam!"
        highlightKeyword="Ujian Bebas Curang"
      />
    </div>
  );
};
