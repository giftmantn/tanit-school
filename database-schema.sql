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

-- Levels are grouped: primary/middle ("Base") vs secondary ("secondaire").
-- The live database already has this column as the level_group enum, while a
-- fresh install creates it as text — so we backfill the values with a dynamic
-- cast that matches the actual column type.
alter table public.levels add column if not exists group_level text;
do $$
declare
  col_udt text;
begin
  select udt_name into col_udt
  from information_schema.columns
  where table_schema = 'public' and table_name = 'levels' and column_name = 'group_level';
  execute format(
    'update public.levels set group_level = case when ord <= 9 then ''Base''::%I else ''secondaire''::%I end where group_level is null',
    col_udt, col_udt
  );
end $$;

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

-- ---------- SECTIONS (filières : 2ème → 4ème secondaire) ----------
create table if not exists public.sections (
  id uuid primary key default gen_random_uuid(),
  name_fr text not null unique,
  name_ar text not null,
  name_en text not null,
  ord int default 0
);

insert into public.sections (name_fr, name_ar, name_en, ord) values
  ('Sciences',            'علوم',           'Sciences',              1),
  ('Mathématiques',       'رياضيات',        'Mathematics',           2),
  ('Économie & Gestion',  'اقتصاد وتصرّف',   'Economics & Management', 3),
  ('Lettres',             'آداب',           'Letters',               4),
  ('Informatique',        'إعلامية',         'Computer science',      5),
  ('Technique',           'تقنّي',          'Technical',             6)
on conflict do nothing;

-- Which levels offer which sections (junction).
-- All 3 secondary years share the same 6 sections, hence the junction table.
create table if not exists public.level_sections (
  level_id uuid references public.levels(id) on delete cascade,
  section_id uuid references public.sections(id) on delete cascade,
  primary key (level_id, section_id)
);

-- 2ème, 3ème et 4ème année secondaire (ord 11, 12, 13) have every section.
insert into public.level_sections (level_id, section_id)
select l.id, s.id
from public.levels l
cross join public.sections s
where l.ord in (11, 12, 13)
on conflict do nothing;

-- Documents can optionally belong to a section (only meaningful for levels that have sections).
alter table public.documents add column if not exists section_id uuid references public.sections(id) on delete set null;

-- Enforce that a document's section (if any) is actually offered by the chosen level.
-- RLS policies cannot reference NEW inside subqueries, so this lives in a trigger.
create or replace function public.check_document_section()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.section_id is not null and not exists (
    select 1 from public.level_sections ls
    where ls.level_id = new.level_id and ls.section_id = new.section_id
  ) then
    raise exception 'Section is not available for this level';
  end if;
  return new;
end;
$$;

drop trigger if exists document_section_check on public.documents;
create trigger document_section_check
  before insert or update on public.documents
  for each row execute procedure public.check_document_section();

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
alter table public.sections  enable row level security;
alter table public.level_sections enable row level security;
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

-- --- SECTIONS ---
drop policy if exists "sections_select" on public.sections;
create policy "sections_select" on public.sections for select using (true);
drop policy if exists "sections_insert_admin" on public.sections;
create policy "sections_insert_admin" on public.sections for insert with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "sections_update_admin" on public.sections;
create policy "sections_update_admin" on public.sections for update using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "sections_delete_admin" on public.sections;
create policy "sections_delete_admin" on public.sections for delete using (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);

-- --- LEVEL_SECTIONS (junction) ---
drop policy if exists "level_sections_select" on public.level_sections;
create policy "level_sections_select" on public.level_sections for select using (true);
drop policy if exists "level_sections_insert_admin" on public.level_sections;
create policy "level_sections_insert_admin" on public.level_sections for insert with check (
  exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
);
drop policy if exists "level_sections_delete_admin" on public.level_sections;
create policy "level_sections_delete_admin" on public.level_sections for delete using (
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
-- (Section/level consistency is enforced by the trigger below, not here,
--  because RLS policies cannot reference NEW inside subqueries.)
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
-- SELF-HEALING (safe to re-run at any time)
-- -----------------------------
-- Older installs re-ran the seed inserts before the unique
-- constraints existed, producing duplicate levels/subjects.
-- This block removes the duplicates, re-points any documents to
-- the kept row, and adds the missing unique constraints so that
-- `ON CONFLICT DO NOTHING` actually works from now on.
-- ============================================================

-- 1) Re-point documents that reference a duplicate level to the kept one.
update public.documents d
set level_id = k.id
from public.levels dup
join public.levels k on k.name_fr = dup.name_fr
where d.level_id = dup.id
  and k.id <> dup.id
  and k.id = (select min(id) from public.levels where name_fr = dup.name_fr);

-- 2) Drop duplicate levels (keep the lowest id per name).
delete from public.levels dup
using public.levels k
where k.name_fr = dup.name_fr and dup.id > k.id;

-- 3) Same for subjects.
update public.documents d
set subject_id = k.id
from public.subjects dup
join public.subjects k on k.name_fr = dup.name_fr
where d.subject_id = dup.id
  and k.id <> dup.id
  and k.id = (select min(id) from public.subjects where name_fr = dup.name_fr);

delete from public.subjects dup
using public.subjects k
where k.name_fr = dup.name_fr and dup.id > k.id;

-- 4) Make the duplicates impossible in the future.
--    (Unique indexes are used because PostgreSQL does not support
--     ALTER TABLE ... ADD CONSTRAINT IF NOT EXISTS. A unique index on
--     name_fr enforces the same rule and acts as the ON CONFLICT arbiter;
--     on a fresh install it is skipped because the constraint from the
--     CREATE TABLE statement already created an index with this name.)
create unique index if not exists levels_name_fr_key   on public.levels   (name_fr);
create unique index if not exists subjects_name_fr_key on public.subjects (name_fr);
create unique index if not exists sections_name_fr_key on public.sections (name_fr);

-- ============================================================
-- STORAGE (if you ever want to upload files directly)
-- Optional: create a bucket for direct uploads.
-- ============================================================
-- insert into storage.buckets (id, name, public) values ('documents', 'documents', true)
-- on conflict (id) do nothing;
