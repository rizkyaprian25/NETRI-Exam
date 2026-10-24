/**
 * Single Source of Truth (SSOT) Kontrak Data NETRI Exam
 * Digunakan bersama oleh Backend Fastify, Dashboard Pengawas, dan Mobile Client.
 */

// Peran Pengguna
export type UserRole = "student" | "proctor" | "teacher" | "admin";

// Status Sesi Ujian Siswa
export type SessionStatus =
  | "scheduled" // Belum masuk waktu ujian
  | "ready"     // Lolos pre-check & berada di ruang tunggu
  | "active"    // Sedang mengerjakan Google Form
  | "locked"    // Terkunci akibat pelanggaran (menunggu pengawas)
  | "finished"  // Telah submit dan diverifikasi
  | "terminated"// Sesi dibatalkan/didiskualifikasi oleh pengawas
  | "offline";  // Hilang sinyal / heartbeat terputus

// Tingkat Keparahan Pelanggaran
export type ViolationSeverity = "info" | "warning" | "danger";

// Tipe Kejadian Pelanggaran Terdeteksi
export type ViolationType =
  | "app_exit"            // Meninggalkan aplikasi / berpindah layar
  | "screenshot_attempt"  // Upaya screenshot layar
  | "screen_recording"    // Upaya merekam layar aktif
  | "split_screen"        // Membuka mode multi-window / PiP
  | "overlay_detected"    // Aplikasi pihak ketiga melayang (chat head, assistive app)
  | "external_navigation" // Berusaha membuka link di luar Google Form
  | "device_tamper"       // Root / Jailbreak terdeteksi
  | "connection_lost";    // Putus koneksi jaringan

// Entitas Institusi Sekolah / Kampus
export interface Institution {
  id: string;
  name: string;
  code: string;
  brand_color?: string;
  logo_url?: string;
  created_at: string;
}

// Entitas Pengguna
export interface User {
  id: string;
  institution_id: string;
  nis_or_nip: string;
  name: string;
  role: UserRole;
  device_id?: string; // Token perangkat hardware terikat
  created_at: string;
}

// Entitas Ujian
export interface Exam {
  id: string;
  institution_id: string;
  title: string;
  subject: string;
  form_url_template: string; // Tautan template Google Form terisi NIS
  start_time: string;        // ISO 8601
  end_time: string;          // ISO 8601
  duration_minutes: number;  // Durasi pengerjaan siswa
  exit_action: "lock_wait_proctor" | "reload_form"; // Default: lock_wait_proctor
  max_strikes: number;       // Default: 3
  allowed_domains: string[]; // Whitelist domain (forms.google.com, etc)
  created_by: string;
}

// Entitas Sesi Ujian Siswa (Student x Exam)
export interface Session {
  id: string;
  exam_id: string;
  student_id: string;
  student_name: string;
  student_nis: string;
  device_id: string;
  status: SessionStatus;
  started_at?: string;
  deadline_at?: string;     // Waktu tenggat server yang mengikat
  finished_at?: string;
  strike_count: number;
  last_heartbeat_at?: string;
  client_version: string;
  platform: "android" | "ios";
}

// Kejadian Pelanggaran (Idempoten via id / client_event_id)
export interface ViolationEvent {
  id: string;               // UUID idempoten dari client
  session_id: string;
  type: ViolationType;
  severity: ViolationSeverity;
  client_timestamp: string; // Waktu lokal HP saat kejadian
  server_timestamp?: string;// Waktu server saat diterima
  duration_seconds?: number;// Durasi keluar aplikasi (jika tipe app_exit)
  is_excused: boolean;      // Benar jika masuk masa tenggang (< 10s telepon/notif)
  notes?: string;
}

// Aksi Pengawas terhadap Sesi Siswa
export type ProctorActionType = "warn" | "lock" | "unlock" | "extend_time" | "terminate";

export interface ProctorAction {
  id: string;
  session_id: string;
  proctor_id: string;
  action: ProctorActionType;
  reason?: string;
  extension_minutes?: number; // Jika action == "extend_time"
  timestamp: string;
}

// Respon Standar API
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    retryable: boolean;
    request_id: string;
  };
}

// Payload Mulai Ujian (Release Link)
export interface StartSessionResponse {
  session_id: string;
  form_url: string;        // Tautan Google Form spesifik siswa yang telah didekripsi
  deadline_at: string;     // Waktu tenggat server
  server_current_time: string;
  allowed_domains: string[];
}
