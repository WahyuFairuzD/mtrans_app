-- 003_pengawas_operational.sql
-- Peran baru: Pengawas Operational.
-- Tugasnya hanya memastikan kondisi "after" dari pekerjaan yang checklist-nya
-- sudah diperiksa Pengawas, lalu mengekspor laporan inspeksi (PDF) dari aplikasi.
-- Tidak ada absensi, stok, maupun unit pada peran ini.
--
-- Jalankan di Supabase SQL Editor. Nilai enum baru tidak boleh dipakai pada
-- transaksi yang sama dengan ALTER TYPE, jadi berkas ini dibagi dua blok.

-- ---------------------------------------------------------------------
-- 1. Nilai enum peran
-- ---------------------------------------------------------------------
begin;
alter type public.user_role add value if not exists 'pengawas_operational';
commit;

-- ---------------------------------------------------------------------
-- 2. Tabel laporan
-- ---------------------------------------------------------------------
begin;

-- Satu laporan per pekerjaan. Isinya teks yang diketik Pengawas Operational;
-- PDF dibuat di aplikasi dari baris ini, jadi tidak ada berkas yang disimpan.
create table if not exists public.job_operational_reports (
  job_id       uuid primary key references public.wash_jobs (id) on delete cascade,
  report_date  date not null,                       -- Tanggal Inspeksi di laporan
  shift        text not null,                       -- mis. "Shift 1 (08.00-16.00)"
  pool_name    text not null,                       -- mis. "MTrans Pool Suhat"
  team_name    text not null,                       -- mis. "Adit, Budi (2 Personel)"
  bus_label    text not null,                       -- mis. "GREGORY /Single Decker/N 7204 UJ"
  after_notes  text not null,                       -- konfirmasi kondisi after (wajib)
  findings     text not null default '',            -- Temuan Hasil Inspeksi
  constraints  text not null default '',            -- Kendala Lapangan
  final_status text not null,                       -- Ket. final (diketik manual, mis. DONE)
  created_by   uuid not null references public.profiles (id) on delete restrict,
  created_at   timestamptz not null default now(),
  updated_by   uuid references public.profiles (id) on delete set null,
  updated_at   timestamptz not null default now()
);
create index if not exists job_operational_reports_date_idx
  on public.job_operational_reports (report_date desc);

-- Nama & tanda tangan yang tercetak di laporan, disimpan per akun
-- Pengawas Operational supaya export berikutnya tidak perlu menggambar ulang.
create table if not exists public.report_signers (
  profile_id            uuid primary key references public.profiles (id) on delete cascade,
  qc_name               text not null,              -- "Dibuat Oleh, PIC QC Cuci Bus"
  qc_signature          text,                       -- PNG base64
  operational_name      text not null,              -- "Diperiksa Oleh, PIC Operasional Mtrans"
  operational_signature text,                       -- PNG base64
  updated_at            timestamptz not null default now()
);

create or replace trigger trg_operational_report_updated_at
  before update on public.job_operational_reports
  for each row execute function public.set_updated_at();

create or replace trigger trg_report_signers_updated_at
  before update on public.report_signers
  for each row execute function public.set_updated_at();

-- Backend memakai service_role (melewati RLS). Policy di bawah hanya untuk
-- akses langsung lewat Supabase client, mengikuti pola tabel lain.
alter table public.job_operational_reports enable row level security;
alter table public.report_signers         enable row level security;

drop policy if exists job_operational_reports_select on public.job_operational_reports;
create policy job_operational_reports_select on public.job_operational_reports
  for select to authenticated
  using (exists (select 1 from public.wash_jobs w where w.id = job_operational_reports.job_id));

drop policy if exists report_signers_select on public.report_signers;
create policy report_signers_select on public.report_signers
  for select to authenticated
  using (profile_id = auth.uid());

commit;
