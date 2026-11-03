// Komponen Subtitle Narasi Dinamis (Bilingual / Bahasa Indonesia Terstruktur)
// Menampilkan naskah panduan dengan badge babak dan efek sorot kata

import React from 'react';

interface SubtitleBarProps {
  stepBadge: string;
  narrationText: string;
  highlightKeyword?: string;
}

export const SubtitleBar: React.FC<SubtitleBarProps> = ({
  stepBadge,
  narrationText,
  highlightKeyword,
}) => {
  return (
    <div
      style={{
        position: 'absolute',
        bottom: 50,
        left: '50%',
        transform: 'translateX(-50%)',
        maxWidth: 1400,
        width: '90%',
        backgroundColor: 'rgba(15, 23, 42, 0.85)',
        backdropFilter: 'blur(16px)',
        borderRadius: 24,
        padding: '20px 32px',
        border: '1px solid rgba(255, 255, 255, 0.12)',
        boxShadow: '0 20px 40px rgba(0, 0, 0, 0.6)',
        display: 'flex',
        alignItems: 'center',
        gap: 24,
        zIndex: 100,
      }}
    >
      {/* Badge Babak */}
      <div
        style={{
          padding: '8px 18px',
          backgroundColor: '#2563EB',
          color: '#FFFFFF',
          borderRadius: 12,
          fontWeight: 700,
          fontSize: 16,
          letterSpacing: 0.5,
          whiteSpace: 'nowrap',
          textTransform: 'uppercase',
        }}
      >
        {stepBadge}
      </div>

      {/* Teks Narasi */}
      <div
        style={{
          color: '#F8FAFC',
          fontSize: 22,
          fontWeight: 500,
          lineHeight: 1.45,
          flex: 1,
        }}
      >
        {narrationText}
      </div>

      {/* Indikator Kata Kunci Sorotan jika ada */}
      {highlightKeyword && (
        <div
          style={{
            padding: '6px 14px',
            backgroundColor: 'rgba(239, 68, 68, 0.18)',
            border: '1px solid rgba(239, 68, 68, 0.5)',
            color: '#FCA5A5',
            borderRadius: 10,
            fontSize: 14,
            fontWeight: 600,
          }}
        >
          {highlightKeyword}
        </div>
      )}
    </div>
  );
};
