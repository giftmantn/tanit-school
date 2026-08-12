-- ============================================================
-- TANIT SCHOOL — DATABASE SETUP
-- Run this whole file in the Supabase SQL Editor:
--   Dashboard > SQL Editor > New query > paste > Run
-- ============================================================

-- ---------- PROFILES ----------
create table if not exists public.profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  email text,
  full_name text,
  role text not null default 'student' check (role in ('student','teacher','admin')),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now()
);

-- If the table already existed (created before the approval feature),
-- add the status column to it.
alter table public.profiles add column if not exists status text not null default 'pending' check (status in ('pending','approved','rejected'));

-- Auto-create a profile row when a user signs up.
-- New accounts start as 'pending' until the admin approves them.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
declare
  requested text;
begin
  requested := coalesce(new.raw_user_meta_data ->> 'role', 'student');
  if requested not in ('student','teacher','admin') then
    requested := 'student';
  end if;
  insert into public.profiles (id, email, full_name, role, status)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data ->> 'full_name', ''),
          requested,
          'pending');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ---------- LEVELS ----------
create table if not exists public.levels (
  id uuid primary key default gen_random_uuid(),
  name_fr text not null unique,
  name_ar text not null,
  name_en text not null,
  ord int default 0
);

insert into public.levels (name_fr, name_ar, name_en, ord) values
  ('1ère année primaire',   'السنة الأولى ابتدائي',  '1st grade primary',     1),
  ('2ème année primaire',   'السنة الثانية ابتدائي', '2nd grade primary',     2),
  ('3ème année primaire',   'السنة الثالثة ابتدائي', '3rd grade primary',     3),
  ('4ème année primaire',   'السنة الرابعة ابتدائي', '4th grade primary',     4),
  ('5ème année primaire',   'السنة الخامسة ابتدائي', '5th grade primary',     5),
  ('6ème année primaire',   'السنة السادسة ابتدائي', '6th grade primary',     6),
  ('7ème année',            'السنة السابعة',         '7th grade',             7),
  ('8ème année',            'السنة الثامنة',         '8th grade',             8),
  ('9ème année',            'السنة التاسعة',         '9th grade',             9),
  ('1ère année secondaire', 'سنة أولى ثانوي',        '1st year secondary',   10),
  ('2ème année secondaire', 'سنة ثانية ثانوي',       '2nd year secondary',   11),
  ('3ème année secondaire', 'سنة ثالثة ثانوي',       '3rd year secondary',   12),
  ('4ème année - Bac',      'سنة رابعة - باكالوريا', '4th year - Bac',       13)
on conflict do nothing;

-- ---------- SUBJECTS ----------
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  name_fr text not null unique,
  name_ar text not null,
  name_en text not null,
  ord int default 0
);

insert into public.subjects (name_fr, name_ar, name_en, ord) values
  ('Mathématiques',        'رياضيات',       'Mathematics',        1),
  ('Français',             'فرنسية',        'French',             2),
  ('Arabe',                'عربية',         'Arabic',             3),
  ('Anglais',              'إنجليزية',      'English',            4),
  ('Physique',             'فيزياء',        'Physics',            5),
  ('Chimie',               'كيمياء',        'Chemistry',          6),
  ('SVT',                  'علوم الحياة',   'Life sciences',      7),
  ('Histoire-Géo',         'تاريخ وجغرافيا', 'History-Geo',        8),
  ('Éducation islamique',  'تربية إسلامية', 'Islamic education',  9),
  ('Philosophie',          'فلسفة',         'Philosophy',        10),
  ('Informatique',         'إعلامية',       'Computer science',  11),
  ('Autre',                'أخرى',          'Other',             12)
on conflict do nothing;

-- ---------- DOCUMENTS ----------
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  title_fr text not null,
  title_ar text not null,
  title_en text not null,
  desc_fr text default '',
  desc_ar text default '',
  desc_en text default '',
  level_id uuid references public.levels(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  drive_url text not null,
  uploader_id uuid references public.profiles(id) on delete set null,
  approved boolean not null default true,
  created_at timestamptz default now()
);

-- ---------- FAVORITES ----------
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  document_id uuid references public.documents(id) on delete cascade,
  created_at timestamptz default now(),
  unique (user_id, document_id)
);

-- ============================================================
-- ROW LEVEL SECURITY
-- (Safe to re-run: each policy is dropped before being created)
-- ============================================================
alter table public.profiles  enable row level security;
alter table public.levels    enable row level security;
alter table public.subjects  enable row level security;
alter table public.documents enable row level security;
alter table public.favorites enable row level security;

-- --- PROFILES ---
-- Anyone can read profiles (needed to show the uploader name).
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles for select using (true);
-- Users can update their own name.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update using (auth.uid() = id);
-- Admins can update any profile (change roles / approve accounts).
drop policy if exists "profiles_update_admin" on public.profiles;
create policy "profiles_update_admin" on public.profiles for update using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- --- LEVELS / SUBJECTS ---
-- Readable by everyone.
drop policy if exists "levels_select" on public.levels;
create policy "levels_select" on public.levels for select using (true);
drop policy if exists "subjects_select" on public.subjects;
create policy "subjects_select" on public.subjects for select using (true);
-- Only admins can write.
drop policy if exists "levels_insert_admin" on public.levels;
create policy "levels_insert_admin" on public.levels for insert with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "levels_update_admin" on public.levels;
create policy "levels_update_admin" on public.levels for update using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "levels_delete_admin" on public.levels;
create policy "levels_delete_admin" on public.levels for delete using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "subjects_insert_admin" on public.subjects;
create policy "subjects_insert_admin" on public.subjects for insert with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "subjects_update_admin" on public.subjects;
create policy "subjects_update_admin" on public.subjects for update using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "subjects_delete_admin" on public.subjects;
create policy "subjects_delete_admin" on public.subjects for delete using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- --- DOCUMENTS ---
-- Everyone can read approved documents.
drop policy if exists "documents_select_public" on public.documents;
create policy "documents_select_public" on public.documents for select using (approved = true);
-- Teachers/admins can also see their own unapproved drafts.
drop policy if exists "documents_select_own" on public.documents;
create policy "documents_select_own" on public.documents for select using (
  auth.uid() = uploader_id
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
-- Teachers and admins can insert.
drop policy if exists "documents_insert_teacher" on public.documents;
create policy "documents_insert_teacher" on public.documents for insert with check (
  exists (select 1 from public.profiles p
          where p.id = auth.uid() and p.role in ('teacher','admin'))
  and auth.uid() = uploader_id
);
-- Teachers can update their own, admins can update any.
drop policy if exists "documents_update_owner" on public.documents;
create policy "documents_update_owner" on public.documents for update using (
  auth.uid() = uploader_id
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "documents_delete_owner" on public.documents;
create policy "documents_delete_owner" on public.documents for delete using (
  auth.uid() = uploader_id
  or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- --- FAVORITES ---
drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own" on public.favorites for select using (auth.uid() = user_id);
drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own" on public.favorites for insert with check (auth.uid() = user_id);
drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own" on public.favorites for delete using (auth.uid() = user_id);

-- ============================================================
-- STORAGE (if you ever want to upload files directly)
-- Optional: create a bucket for direct uploads.
-- ============================================================
-- insert into storage.buckets (id, name, public) values ('documents', 'documents', true)
-- on conflict (id) do nothing;
