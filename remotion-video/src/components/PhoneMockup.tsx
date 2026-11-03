// Komponen Mockup Smartphone Realistis (Apple HIG / Modern Android Bezel)
// Membungkus layar aplikasi Flutter NETRI Exam dengan bayangan lembut dan dynamic notch

import React from 'react';

interface PhoneMockupProps {
  children: React.ReactNode;
  scale?: number;
  rotation?: number;
  highlightBorder?: boolean;
}

export const PhoneMockup: React.FC<PhoneMockupProps> = ({
  children,
  scale = 1,
  rotation = 0,
  highlightBorder = false,
}) => {
  return (
    <div
      style={{
        transform: `scale(${scale}) rotate(${rotation}deg)`,
        transition: 'transform 0.4s ease-out',
        width: 400,
        height: 820,
        backgroundColor: '#0F172A',
        borderRadius: 48,
        padding: 12,
        boxShadow: highlightBorder
          ? '0 0 60px rgba(239, 68, 68, 0.6), 0 25px 50px -12px rgba(0, 0, 0, 0.7)'
          : '0 25px 50px -12px rgba(0, 0, 0, 0.8), 0 0 40px rgba(59, 130, 246, 0.2)',
        border: highlightBorder ? '3px solid #EF4444' : '3px solid #334155',
        position: 'relative',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Dynamic Island / Notch Speaker */}
      <div
        style={{
          position: 'absolute',
          top: 18,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 120,
          height: 24,
          backgroundColor: '#000000',
          borderRadius: 20,
          zIndex: 50,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {/* Lensa Kamera Depan */}
        <div
          style={{
            width: 10,
            height: 10,
            borderRadius: '50%',
            backgroundColor: '#1E293B',
            marginLeft: 60,
          }}
        />
      </div>

      {/* Area Layar Utama (Viewport Aplikasi) */}
      <div
        style={{
          flex: 1,
          backgroundColor: '#FFFFFF',
          borderRadius: 38,
          overflow: 'hidden',
          position: 'relative',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        {children}
      </div>

      {/* Baris Navigasi Bawah (Home Indicator) */}
      <div
        style={{
          position: 'absolute',
          bottom: 18,
          left: '50%',
          transform: 'translateX(-50%)',
          width: 130,
          height: 5,
          backgroundColor: '#64748B',
          borderRadius: 10,
        }}
      />
    </div>
  );
};
