// Babak 5: Pengerjaan Soal Nyaman & Proteksi Anti-Copy
// Menampilkan WebView Immersive Fullscreen, anti-salin teks soal, dan pengetikan lancar pada kolom isian

import React from 'react';
import { useCurrentFrame } from 'remotion';
import { PhoneMockup } from '../components/PhoneMockup';
import { SubtitleBar } from '../components/SubtitleBar';

export const Scene5ExamSheet: React.FC = () => {
  const frame = useCurrentFrame();

  // Efek klik opsi jawaban & pengetikan
  const isOptionSelected = frame > 100;
  const typedAnswer = frame > 180 ? 'Hasil perhitungan adalah 5' : '';

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
      {/* Kolom Kiri: Keunggulan Proteksi Soal */}
      <div style={{ flex: 1, maxWidth: 640, zIndex: 10 }}>
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
          PENGALAMAN PENGERJAAN NYAMAN
        </div>

        <h2 style={{ color: '#FFFFFF', fontSize: 44, fontWeight: 800, marginBottom: 16 }}>
          100% Layar Penuh & Bebas Salin Teks
        </h2>

        <p style={{ color: '#94A3B8', fontSize: 20, lineHeight: 1.5, marginBottom: 28 }}>
          Teks soal dilindungi injeksi JavaScript anti-copy sehingga tidak dapat disalin atau dibagikan ke AI/search engine, namun seluruh kotak isian esai dan pilihan ganda tetap berfungsi normal.
        </p>

        {/* Feature List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>🔒</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Anti-Copy & Anti-Selection pada Seluruh Teks Soal
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>✏️</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Input Esai & Opsi Ganda Tetap 100% Responsif Menjawab
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>🚫</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Tombol "Selesai" di Top Bar Ditiadakan (Wajib Kirim Form)
            </span>
          </div>
        </div>
      </div>

      {/* Kolom Kanan: Phone Mockup WebView Google Form */}
      <div style={{ position: 'relative' }}>
        <PhoneMockup>
          <div
            style={{
              flex: 1,
              backgroundColor: '#EDE7F6',
              display: 'flex',
              flexDirection: 'column',
              fontFamily: 'Roboto, sans-serif',
            }}
          >
            {/* Top Bar Exam NETRI */}
            <div
              style={{
                backgroundColor: '#1E40AF',
                padding: '12px 16px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                color: '#FFFFFF',
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 14 }}>🔒</span>
                <span style={{ fontWeight: 700, fontSize: 13 }}>Exam NETRI (Terkunci)</span>
              </div>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  backgroundColor: 'rgba(255,255,255,0.2)',
                  padding: '4px 10px',
                  borderRadius: 14,
                  fontSize: 11,
                  fontWeight: 600,
                }}
              >
                <span style={{ color: '#4ADE80' }}>●</span>
                <span>Terhubung</span>
              </div>
            </div>

            {/* Konten Google Form */}
            <div style={{ flex: 1, padding: 14, overflowY: 'auto' }}>
              {/* Header Kartu Form */}
              <div
                style={{
                  backgroundColor: '#FFFFFF',
                  borderRadius: 12,
                  padding: 16,
                  borderTop: '6px solid #673AB7',
                  marginBottom: 12,
                  boxShadow: '0 2px 6px rgba(0,0,0,0.06)',
                }}
              >
                <div style={{ fontWeight: 800, fontSize: 15, color: '#202124' }}>
                  Asesmen Matematika Kelas 8
                </div>
                <div style={{ fontSize: 11, color: '#5F6368', marginTop: 4 }}>
                  SMP Negeri 3 Cibungbulang • Tahun Ajaran 2026/2027
                </div>
              </div>

              {/* Soal 1 Pilihan Ganda */}
              <div
                style={{
                  backgroundColor: '#FFFFFF',
                  borderRadius: 12,
                  padding: 14,
                  marginBottom: 12,
                  boxShadow: '0 2px 6px rgba(0,0,0,0.06)',
                  userSelect: 'none',
                }}
              >
                <div style={{ fontSize: 12, fontWeight: 600, color: '#202124', marginBottom: 10 }}>
                  1. Bentuk sederhana dari 4(2x - 3) + 5 adalah...
                </div>

                <div
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    gap: 8,
                    fontSize: 12,
                    color: '#3C4043',
                  }}
                >
                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 8,
                      backgroundColor: isOptionSelected ? '#EDE7F6' : 'transparent',
                      padding: '6px 8px',
                      borderRadius: 6,
                    }}
                  >
                    <span>{isOptionSelected ? '🔘' : '⚪'}</span>
                    <span style={{ fontWeight: isOptionSelected ? 700 : 400 }}>A. 8x - 7</span>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '6px 8px' }}>
                    <span>⚪</span>
                    <span>B. 8x + 7</span>
                  </div>
                </div>
              </div>

              {/* Soal 2 Isian Jawaban Singkat */}
              <div
                style={{
                  backgroundColor: '#FFFFFF',
                  borderRadius: 12,
                  padding: 14,
                  boxShadow: '0 2px 6px rgba(0,0,0,0.06)',
                }}
              >
                <div style={{ fontSize: 12, fontWeight: 600, color: '#202124', marginBottom: 8 }}>
                  2. Tuliskan jawaban akhir Anda:
                </div>
                <div
                  style={{
                    borderBottom: '2px solid #673AB7',
                    padding: '6px 4px',
                    fontSize: 12,
                    color: typedAnswer ? '#202124' : '#9AA0A6',
                  }}
                >
                  {typedAnswer || 'Jawaban Anda...'}
                </div>
              </div>
            </div>
          </div>
        </PhoneMockup>
      </div>

      <SubtitleBar
        stepBadge="Babak 5 • Proteksi Soal"
        narrationText="Siswa mengerjakan soal Google Form dengan nyaman dalam mode layar penuh. Teks soal dilindungi anti-copy sehingga tidak dapat disalin atau dibagikan, sementara kolom isian tetap 100% responsif."
        highlightKeyword="Anti-Copy & Fullscreen"
      />
    </div>
  );
};
