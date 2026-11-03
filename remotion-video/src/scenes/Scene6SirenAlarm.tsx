// Babak 6: Sensor Pelanggaran & Sirine Peringatan Keras 5 Detik
// Menampilkan pemblokiran tombol Back, alarm sirine darurat di kelas, dan dialog pelanggaran terkunci

import React from 'react';
import { useCurrentFrame } from 'remotion';
import { PhoneMockup } from '../components/PhoneMockup';
import { SubtitleBar } from '../components/SubtitleBar';
import { SirenAlertOverlay } from '../components/SirenAlertOverlay';

export const Scene6SirenAlarm: React.FC = () => {
  const frame = useCurrentFrame();

  // Mode Sirine Aktif
  const sirenActive = frame >= 40;

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
      {/* Kolom Kiri: Penjelasan Efek Jera */}
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
          EFEK JERA PSIKOLOGIS • ANTI-KELUAR
        </div>

        <h2 style={{ color: '#FFFFFF', fontSize: 44, fontWeight: 800, marginBottom: 16 }}>
          Sirine Peringatan 5 Detik Saat Coba Keluar
        </h2>

        <p style={{ color: '#94A3B8', fontSize: 20, lineHeight: 1.5, marginBottom: 28 }}>
          Mencoba menekan tombol Back atau meminimalkan aplikasi? Volume suara langsung dipaksa 100% maksimal dan sirine keras meraung selama 5 detik di kelas pengawas!
        </p>

        {/* Feature List */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>🚨</span>
            <span style={{ color: '#FCA5A5', fontSize: 18, fontWeight: 600 }}>
              Sirine Nyata 5 Detik Otomatis Berbunyi Keras di Kelas
            </span>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <span style={{ fontSize: 22 }}>📋</span>
            <span style={{ color: '#E2E8F0', fontSize: 18, fontWeight: 600 }}>
              Pencatatan Log Pelanggaran Otomatis ke Server Pengawas
            </span>
          </div>
        </div>
      </div>

      {/* Kolom Kanan: Phone Mockup dengan Efek Sirine Merah */}
      <div style={{ position: 'relative' }}>
        <PhoneMockup highlightBorder={sirenActive}>
          <div
            style={{
              flex: 1,
              backgroundColor: '#EDE7F6',
              display: 'flex',
              flexDirection: 'column',
              position: 'relative',
            }}
          >
            {/* Latar Belakang Soal */}
            <div style={{ flex: 1, padding: 14, opacity: 0.3 }}>
              <div
                style={{
                  backgroundColor: '#FFFFFF',
                  borderRadius: 12,
                  padding: 16,
                  borderTop: '6px solid #673AB7',
                }}
              >
                <div style={{ fontWeight: 800, fontSize: 14, color: '#202124' }}>
                  Asesmen Matematika Kelas 8
                </div>
              </div>
            </div>

            {/* Overlay Peringatan & Sirine 5 Detik */}
            {sirenActive && (
              <SirenAlertOverlay
                secondsLeft={5}
                reasonText="Sirine peringatan aktif selama 5 detik!"
              />
            )}
          </div>
        </PhoneMockup>
      </div>

      <SubtitleBar
        stepBadge="Babak 6 • Sensor Pelanggaran"
        narrationText="Mencoba menekan tombol kembali atau berpindah aplikasi? Sistem langsung membunyikan sirine peringatan keras selama 5 detik dan mengunci layar, memberikan efek jera seketika di ruang ujian."
        highlightKeyword="Sirine 5 Detik Aktif"
      />
    </div>
  );
};
