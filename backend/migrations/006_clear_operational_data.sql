-- 006_clear_operational_data.sql
-- Membersihkan data operasional (riwayat pencucian, inspeksi, invoice, absensi,
-- stok) tanpa menyentuh data master dan akun.
--
-- DIHAPUS : wash_jobs + seluruh anaknya (status log, checklist, petugas,
--           inspeksi, laporan PDF, koreksi data), invoices + invoice_items,
--           attendance, stock_movements + stock_items.
-- DIPERTAHANKAN : profiles, branches, units, teams, team_members,
--           service_types, checklist_master_items, vehicle_prices,
--           report_signers (nama & tanda tangan laporan).
--
-- Jalankan di Supabase SQL Editor. Seluruh blok satu transaksi: kalau ada
-- langkah gagal, tidak ada yang terhapus.
--
-- Foto absen tidak ada di database: file-nya tersimpan di Cloudflare R2
-- (bucket mtrans-job-photos) dan sudah dihapus terpisah lewat wrangler.

begin;

-- 1. Putus relasi wash_jobs -> invoices supaya invoice bisa dihapus lebih dulu.
update public.wash_jobs set invoice_id = null where invoice_id is not null;

-- 2. Invoice.
delete from public.invoice_items;
delete from public.invoices;

-- 3. Anak-anak pekerjaan. Dihapus eksplisit agar tidak bergantung pada aturan
--    cascade masing-masing foreign key.
delete from public.job_status_logs;
delete from public.job_checklist_items;
delete from public.job_assignees;
delete from public.inspections;
delete from public.job_operational_reports;
delete from public.data_corrections;

-- 4. Riwayat pencucian.
delete from public.wash_jobs;

-- 5. Absensi.
delete from public.attendance;

-- 6. Stok: riwayat dulu, baru master barang.
delete from public.stock_movements;
delete from public.stock_items;

-- 7. Reset penomoran supaya pekerjaan berikutnya mulai dari WJ-YYMMDD-0001
--    dan invoice berikutnya mulai dari nomor 1.
alter sequence if exists public.wash_job_code_seq restart with 1;

do $$
declare
  seq text;
begin
  for seq in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = 'S'
      and n.nspname = 'public'
      and c.relname ilike '%invoice%'
  loop
    execute format('alter sequence public.%I restart with 1', seq);
    raise notice 'sequence % direset', seq;
  end loop;
end $$;

commit;

-- 8. Verifikasi: semua harus 0, kecuali tabel master di bawah.
select 'wash_jobs' as tabel, count(*) from public.wash_jobs
union all select 'job_status_logs', count(*) from public.job_status_logs
union all select 'job_checklist_items', count(*) from public.job_checklist_items
union all select 'job_assignees', count(*) from public.job_assignees
union all select 'inspections', count(*) from public.inspections
union all select 'job_operational_reports', count(*) from public.job_operational_reports
union all select 'invoices', count(*) from public.invoices
union all select 'invoice_items', count(*) from public.invoice_items
union all select 'data_corrections', count(*) from public.data_corrections
union all select 'attendance', count(*) from public.attendance
union all select 'stock_movements', count(*) from public.stock_movements
union all select 'stock_items', count(*) from public.stock_items
union all select '-- master (tetap) --', 0
union all select 'profiles', count(*) from public.profiles
union all select 'units', count(*) from public.units
union all select 'service_types', count(*) from public.service_types
union all select 'checklist_master_items', count(*) from public.checklist_master_items
union all select 'report_signers', count(*) from public.report_signers;
