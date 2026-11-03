// Komponen Visual Tirai Pelindung Keamanan (Security Curtain)
// Meniru tampilan nyata Exam NETRI saat mendeteksi aplikasi mengambang atau mode sematkan belum aktif

import React from 'react';

interface SecurityCurtainProps {
  isObscured: boolean;
  onButtonClickText?: string;
}

export const SecurityCurtain: React.FC<SecurityCurtainProps> = ({
  isObscured,
  onButtonClickText = 'Kunci Layar & Tutup Floating Apps',
}) => {
  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: '#141824',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: 24,
        textAlign: 'center',
        zIndex: 60,
      }}
    >
      {/* Lingkaran Ikon Gembok Berdenyut */}
      <div
        style={{
          width: 80,
          height: 80,
          borderRadius: '50%',
          backgroundColor: 'rgba(239, 68, 68, 0.2)',
          border: '2px solid #EF4444',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          marginBottom: 20,
        }}
      >
        <span style={{ fontSize: 36 }}>🔒</span>
      </div>

      <h3
        style={{
          color: '#FFFFFF',
          fontSize: 18,
          fontWeight: 700,
          marginBottom: 12,
        }}
      >
        {isObscured
          ? 'Aplikasi Mengambang (Floating App) Terdeteksi!'
          : 'Kunci Layar Ujian (Sematkan Layar) Wajib Aktif!'}
      </h3>

      <p
        style={{
          color: 'rgba(255, 255, 255, 0.7)',
          fontSize: 12,
          lineHeight: 1.5,
          marginBottom: 24,
          maxWidth: 320,
        }}
      >
        {isObscured
          ? 'Lembar soal disembunyikan karena terdeteksi jendela mengambang (Chrome) aktif. Tekan tombol di bawah untuk mengunci layar dan menutup paksa floating app.'
          : 'Agar seluruh aplikasi mengambang tertutup otomatis dan tidak dapat dibuka, Anda wajib menekan "Sematkan" pada konfirmasi sistem.'}
      </p>

      {/* Tombol Aksi Kunci Layar */}
      <div
        style={{
          backgroundColor: '#2563EB',
          color: '#FFFFFF',
          padding: '12px 24px',
          borderRadius: 12,
          fontWeight: 600,
          fontSize: 14,
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          boxShadow: '0 8px 16px rgba(37, 99, 235, 0.4)',
        }}
      >
        <span>🛡️</span>
        <span>{onButtonClickText}</span>
      </div>
    </div>
  );
};
