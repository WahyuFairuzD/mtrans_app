-- Absensi Mtrans. Terapkan manual di Supabase SQL Editor.
-- Role mengikuti aplikasi: owner, pengawas, pegawai.

create table if not exists public.branches (
  id smallint generated always as identity primary key,
  name text not null unique
);

insert into public.branches (name)
values ('Suhat'), ('Panjen'), ('Arjosari')
on conflict (name) do nothing;

alter table public.profiles
  add column if not exists branch_id smallint references public.branches(id);

create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  branch_id smallint not null references public.branches(id),
  type text not null check (type in ('masuk', 'pulang')),
  attended_at timestamptz not null default now(),
  work_date date not null default ((now() at time zone 'Asia/Jakarta')::date),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m real check (accuracy_m is null or accuracy_m >= 0),
  photo_path text not null,
  constraint attendance_one_per_type_per_day unique (user_id, work_date, type)
);

create index if not exists attendance_date_branch_idx
  on public.attendance (work_date, branch_id);
create index if not exists attendance_user_date_idx
  on public.attendance (user_id, work_date);

create or replace function public.attendance_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  profile_role text;
  profile_branch smallint;
  checkin_branch smallint;
begin
  new.attended_at := now();
  new.work_date := (now() at time zone 'Asia/Jakarta')::date;

  select p.role, p.branch_id into profile_role, profile_branch
  from public.profiles p
  where p.id = new.user_id and p.is_active = true;

  if profile_role is null or profile_role = 'owner' then
    raise exception 'Akun ini tidak dapat melakukan absensi' using errcode = 'P0001';
  end if;
  if profile_role not in ('pegawai', 'pengawas') then
    raise exception 'Role akun tidak diizinkan untuk absensi' using errcode = 'P0001';
  end if;
  if profile_role = 'pengawas' and (profile_branch is null or new.branch_id <> profile_branch) then
    raise exception 'Cabang absensi harus sama dengan cabang akun Pengawas' using errcode = 'P0001';
  end if;
  if not exists (select 1 from public.branches b where b.id = new.branch_id) then
    raise exception 'Cabang tidak ditemukan' using errcode = 'P0001';
  end if;

  if new.type = 'pulang' then
    select a.branch_id into checkin_branch
    from public.attendance a
    where a.user_id = new.user_id
      and a.work_date = new.work_date
      and a.type = 'masuk';
    if checkin_branch is null then
      raise exception 'Absen masuk dulu sebelum absen pulang' using errcode = 'P0001';
    end if;
    if checkin_branch <> new.branch_id then
      raise exception 'Cabang absen pulang harus sama dengan cabang absen masuk' using errcode = 'P0001';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists attendance_before_insert_trg on public.attendance;
create trigger attendance_before_insert_trg
before insert on public.attendance
for each row execute function public.attendance_before_insert();

create or replace function public.attendance_is_owner()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'owner' and p.is_active = true
  );
$$;

alter table public.branches enable row level security;
alter table public.attendance enable row level security;

drop policy if exists branches_select_authenticated on public.branches;
create policy branches_select_authenticated on public.branches
  for select to authenticated using (true);

drop policy if exists attendance_insert_own on public.attendance;
create policy attendance_insert_own on public.attendance
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists attendance_select_own_or_owner on public.attendance;
create policy attendance_select_own_or_owner on public.attendance
  for select to authenticated
  using (user_id = auth.uid() or public.attendance_is_owner());
-- Tidak ada policy UPDATE atau DELETE untuk authenticated: koreksi dilakukan admin.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('attendance-photos', 'attendance-photos', false, 1048576, array['image/jpeg'])
on conflict (id) do update set
  public = false,
  file_size_limit = 1048576,
  allowed_mime_types = array['image/jpeg'];

drop policy if exists attendance_photos_insert_own on storage.objects;
create policy attendance_photos_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'attendance-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists attendance_photos_select_own_or_owner on storage.objects;
create policy attendance_photos_select_own_or_owner on storage.objects
  for select to authenticated
  using (
    bucket_id = 'attendance-photos'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.attendance_is_owner())
  );
-- Storage update/delete policies sengaja tidak dibuat untuk pengguna aplikasi.