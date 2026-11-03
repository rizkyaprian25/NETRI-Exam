// Komponen Efek Visual Alarm Sirine 5 Detik & Dialog Peringatan
// Menggambarkan respons Exam NETRI saat siswa mencoba menekan tombol Back atau berpindah aplikasi

import React from 'react';

interface SirenAlertOverlayProps {
  secondsLeft?: number;
  reasonText?: string;
}

export const SirenAlertOverlay: React.FC<SirenAlertOverlayProps> = ({
  secondsLeft = 5,
  reasonText = 'Dilarang Keluar! Sirine peringatan aktif selama 5 detik!',
}) => {
  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.75)',
        backdropFilter: 'blur(8px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 20,
        zIndex: 80,
      }}
    >
      {/* Kartu Dialog Peringatan Merah */}
      <div
        style={{
          width: '100%',
          maxWidth: 340,
          backgroundColor: '#FFFFFF',
          borderRadius: 24,
          padding: 24,
          boxShadow: '0 25px 50px -12px rgba(239, 68, 68, 0.5)',
          border: '2px solid #EF4444',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          textAlign: 'center',
        }}
      >
        {/* Ikon Sirine Bergetar */}
        <div
          style={{
            width: 72,
            height: 72,
            borderRadius: '50%',
            backgroundColor: '#FEE2E2',
            border: '2px solid #F87171',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            marginBottom: 16,
          }}
        >
          <span style={{ fontSize: 32 }}>🚨</span>
        </div>

        <h4
          style={{
            color: '#B91C1C',
            fontSize: 18,
            fontWeight: 800,
            marginBottom: 8,
          }}
        >
          PERINGATAN KERAS!
        </h4>

        {/* Kotak Sirine Aktif */}
        <div
          style={{
            backgroundColor: '#FEF2F2',
            border: '1px solid #FECACA',
            borderRadius: 12,
            padding: '8px 14px',
            marginBottom: 14,
            display: 'flex',
            alignItems: 'center',
            gap: 8,
            color: '#DC2626',
            fontSize: 12,
            fontWeight: 700,
          }}
        >
          <span>🔊</span>
          <span>{reasonText}</span>
        </div>

        <p
          style={{
            color: '#475569',
            fontSize: 12,
            lineHeight: 1.45,
            marginBottom: 20,
          }}
        >
          Tombol kembali dinonaktifkan demi integritas ujian. Tindakan ini dicatat ke log pengawas sekolah.
        </p>

        {/* Tombol Lanjut Ujian */}
        <div
          style={{
            width: '100%',
            backgroundColor: '#1E40AF',
            color: '#FFFFFF',
            padding: '12px 0',
            borderRadius: 12,
            fontWeight: 700,
            fontSize: 13,
            cursor: 'pointer',
          }}
        >
          Lanjut Mengerjakan Ujian
        </div>
      </div>
    </div>
  );
};
