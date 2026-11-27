-- 007_delete_test_accounts.sql
-- Menghapus akun testing dan tanda tangan laporan milik akun tersebut.
--
-- DIHAPUS : auth.users untuk 4 email di bawah. Baris public.profiles ikut
--           terhapus karena foreign key profiles.id -> auth.users.id memakai
--           on delete cascade. Baris public.report_signers milik akun itu juga
--           dihapus, sehingga Pengawas Operational pengganti mengisi nama &
--           tanda tangannya sendiri saat pertama kali export PDF.
-- DIPERTAHANKAN : tanda tangan milik akun lain (mis. ARIS / YOKO) dan seluruh
--           data master, akun, unit, serta harga kendaraan.
--
-- Jalankan di Supabase SQL Editor. Satu transaksi: kalau ada langkah gagal,
-- tidak ada yang terhapus. Kalau akun target masih punya data yang menahan
-- (mis. baris absensi), query sengaja gagal dan seluruh perubahan dibatalkan.

begin;

-- 1. Hapus tanda tangan milik akun testing saja.
delete from public.report_signers
where profile_id in (
  select id
  from auth.users
  where email in (
    'pengawasoperational@gmail.com',
    'pengawasoperanitional@gmail.com',
    'wahyufairuz05@gmail.com',
    'petugas2@mtrans.test'
  )
);

-- 2. Hapus akun testing. Profil ikut terhapus lewat cascade.
delete from auth.users
where email in (
  'pengawasoperational@gmail.com',
  'pengawasoperanitional@gmail.com',
  'wahyufairuz05@gmail.com',
  'petugas2@mtrans.test'
);

commit;

-- 3. Verifikasi.
select 'akun tersisa' as keterangan, count(*) from auth.users
union all select 'profil tersisa', count(*) from public.profiles
union all select 'tanda tangan tersisa', count(*) from public.report_signers
union all select 'pengawas aktif', count(*) from public.profiles where role = 'pengawas' and is_active
union all select 'owner aktif', count(*) from public.profiles where role = 'owner' and is_active;

select p.role, p.full_name, p.is_active, u.email
from public.profiles p
join auth.users u on u.id = p.id
order by p.role, p.full_name;

select s.qc_name, s.operational_name, u.email
from public.report_signers s
join auth.users u on u.id = s.profile_id;
