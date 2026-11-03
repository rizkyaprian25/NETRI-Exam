// Komposisi Utama Video Walkthrough NETRI Exam (Master Timeline)
// Menggabungkan 7 Babak Adegan Berurutan dengan Durasi Total 110 Detik (3300 Frames @ 30 FPS)

import React from 'react';
import { Sequence } from 'remotion';
import { Scene1Hook } from '../scenes/Scene1Hook';
import { Scene2Login } from '../scenes/Scene2Login';
import { Scene3Strict } from '../scenes/Scene3Strict';
import { Scene4AntiFloating } from '../scenes/Scene4AntiFloating';
import { Scene5ExamSheet } from '../scenes/Scene5ExamSheet';
import { Scene6SirenAlarm } from '../scenes/Scene6SirenAlarm';
import { Scene7LegitFinish } from '../scenes/Scene7LegitFinish';

export const NetriExamDemo: React.FC = () => {
  return (
    <div
      style={{
        flex: 1,
        width: 1920,
        height: 1080,
        backgroundColor: '#0F172A',
        position: 'relative',
      }}
    >
      {/* Babak 1: Hook & Masalah (00:00 - 00:15) = 450 frame */}
      <Sequence from={0} durationInFrames={450}>
        <Scene1Hook />
      </Sequence>

      {/* Babak 2: Beranda & Scan QR (00:15 - 00:30) = 450 frame */}
      <Sequence from={450} durationInFrames={450}>
        <Scene2Login />
      </Sequence>

      {/* Babak 3: Konfirmasi Kiosk & Pengawasan Guru (00:30 - 00:43) = 390 frame */}
      <Sequence from={900} durationInFrames={390}>
        <Scene3Strict />
      </Sequence>

      {/* Babak 4: Anti Floating Apps & Tirai Pelindung (00:43 - 01:03) = 600 frame */}
      <Sequence from={1290} durationInFrames={600}>
        <Scene4AntiFloating />
      </Sequence>

      {/* Babak 5: Pengerjaan Soal Fullscreen & Anti-Copy (01:03 - 01:20) = 510 frame */}
      <Sequence from={1890} durationInFrames={510}>
        <Scene5ExamSheet />
      </Sequence>

      {/* Babak 6: Sensor Pelanggaran & Sirine 5 Detik (01:20 - 01:38) = 540 frame */}
      <Sequence from={2400} durationInFrames={540}>
        <Scene6SirenAlarm />
      </Sequence>

      {/* Babak 7: Selesai Sah & Penutup (01:38 - 01:50) = 360 frame */}
      <Sequence from={2940} durationInFrames={360}>
        <Scene7LegitFinish />
      </Sequence>
    </div>
  );
};
