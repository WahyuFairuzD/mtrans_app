-- 004_stock_duplicate_names.sql
-- Nama barang boleh sama selama kategorinya berbeda.
--
-- Sebelumnya nama barang unik per cabang saja (stock_items_branch_name_key),
-- sehingga "silikon" tidak bisa dibuat di Gudang ketika "silikon" sudah ada di
-- Operasional Harian. Pengguna mengakalinya dengan menambah huruf ("SILIKONN").
-- Kini kuncinya per cabang + kategori + nama, tanpa peduli huruf besar/kecil
-- dan spasi di tepi nama.
--
-- Jalankan di Supabase SQL Editor sebelum deploy backend.

begin;

-- Kunci lama bisa berupa unique index maupun unique constraint, tergantung
-- cara pembuatannya; keduanya dibersihkan agar tidak ada yang tertinggal.
alter table public.stock_items
  drop constraint if exists stock_items_branch_name_key;
drop index if exists public.stock_items_branch_name_key;

create unique index if not exists stock_items_branch_category_name_key
  on public.stock_items (branch_id, lower(btrim(category)), lower(btrim(name)));

commit;
