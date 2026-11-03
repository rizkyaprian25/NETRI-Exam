// Komponen Akar Remotion (Root Provider)
// Mendefinisikan komposisi utama video panduan & demonstrasi fitur NETRI Exam

import React from 'react';
import { Composition } from 'remotion';
import { NetriExamDemo } from './compositions/NetriExamDemo';

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="NetriExamDemo"
        component={NetriExamDemo}
        durationInFrames={3300} // 110 detik pada 30 FPS
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          schoolName: 'SMP Negeri 3 Cibungbulang',
          appVersion: 'v1.0.0 (Release)',
        }}
      />
    </>
  );
};
