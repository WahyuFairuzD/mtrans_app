-- 005_checklist_parts.sql
-- Checklist Pengawas mengikuti bagian Eksterior & Interior pada laporan
-- inspeksi cuci bus (LAPORAN HARIAN INSPEKSI CUCI BUS).
--
-- Template lama (5 item generik: body disabun, kaca & spion, velg & ban,
-- lantai & kursi, sampah) diganti daftar bagian per armada:
--   Eksterior (semua layanan) : Kaca & body depan, Lampu depan & belakang,
--                               Body kanan/kiri/belakang, Ban dan Velg
--   Interior (Cuci Luar+Dalam): Area Dasbor & Kemudi, Area Pantry,
--                               Smoking Area, Toilet, Jok & Kursi Penumpang,
--                               Lantai & Kolong Kursi
--
-- Snapshot checklist pada pekerjaan lama (job_checklist_items) TIDAK diubah;
-- template baru hanya dipakai pekerjaan yang dimulai setelah migrasi ini.
-- Jalankan di Supabase SQL Editor sebelum deploy backend.

begin;

-- 1. Bagian eksterior: berlaku untuk semua jenis layanan.
insert into public.checklist_master_items (service_type_id, label, sort_order)
select null, v.label, v.sort_order
from (values
  ('Kaca & body depan',          1),
  ('Lampu depan & belakang',     2),
  ('Body kanan, kiri & belakang', 3),
  ('Ban dan Velg',               4)
) as v(label, sort_order)
where not exists (
  select 1 from public.checklist_master_items m
  where m.service_type_id is null and m.label = v.label
);

-- 2. Bagian interior: hanya layanan Cuci Luar + Dalam.
insert into public.checklist_master_items (service_type_id, label, sort_order)
select st.id, v.label, v.sort_order
from public.service_types st
cross join (values
  ('Area Dasbor & Kemudi',    5),
  ('Area Pantry',             6),
  ('Smoking Area',            7),
  ('Toilet',                  8),
  ('Jok & Kursi Penumpang',   9),
  ('Lantai & Kolong Kursi',  10)
) as v(label, sort_order)
where st.name = 'Cuci Luar + Dalam'
  and not exists (
    select 1 from public.checklist_master_items m
    where m.service_type_id = st.id and m.label = v.label
  );

-- 3. Pastikan seluruh item baru aktif (aman bila berkas dijalankan ulang).
update public.checklist_master_items
set is_active = true
where label in (
  'Kaca & body depan',
  'Lampu depan & belakang',
  'Body kanan, kiri & belakang',
  'Ban dan Velg',
  'Area Dasbor & Kemudi',
  'Area Pantry',
  'Smoking Area',
  'Toilet',
  'Jok & Kursi Penumpang',
  'Lantai & Kolong Kursi'
);

-- 4. Template lama dinonaktifkan agar tidak tersalin ke pekerjaan baru.
update public.checklist_master_items
set is_active = false
where is_active
  and label not in (
    'Kaca & body depan',
    'Lampu depan & belakang',
    'Body kanan, kiri & belakang',
    'Ban dan Velg',
    'Area Dasbor & Kemudi',
    'Area Pantry',
    'Smoking Area',
    'Toilet',
    'Jok & Kursi Penumpang',
    'Lantai & Kolong Kursi'
  );

commit;
