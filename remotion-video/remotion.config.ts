// Konfigurasi Standar Remotion untuk NETRI Exam Video Walkthrough
// Menghasilkan video beresolusi Full HD 1920x1080 pada 30 FPS

import { Config } from '@remotion/cli/config';

Config.setVideoImageFormat('jpeg');
Config.setOverwriteOutput(true);
Config.setPixelFormat('yuv420p');
