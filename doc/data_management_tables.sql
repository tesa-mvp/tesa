-- SAM. data management tables
-- Purpose:
--   Store editable master data in Supabase without changing the current
--   production app, which still reads JSON files from GitHub/Vercel.
--
-- Safe naming:
--   All tables use the data_ prefix so they are easy to distinguish from
--   production app tables such as profiles, entitlements, usage_counters,
--   search_events, and support_tickets.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  );
$$;

-- =========================
-- Model index data
-- =========================

create table if not exists public.data_makes (
  id text primary key,                         -- index.json make_id, e.g. ducati
  name text not null,                          -- index.json make, e.g. Ducati
  sort_order integer not null default 1000,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_data_makes_updated_at on public.data_makes;
create trigger set_data_makes_updated_at
before update on public.data_makes
for each row execute function public.set_updated_at();

create table if not exists public.data_model_groups (
  id uuid primary key default gen_random_uuid(),
  make_id text not null references public.data_makes(id) on delete cascade,
  group_id text not null,                      -- index.json group_id, e.g. superbike
  group_label text not null,                   -- index.json group_label, e.g. Superbike
  sort_order integer not null default 1000,    -- index.json group_sort_order
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (make_id, group_id)
);

drop trigger if exists set_data_model_groups_updated_at on public.data_model_groups;
create trigger set_data_model_groups_updated_at
before update on public.data_model_groups
for each row execute function public.set_updated_at();

create table if not exists public.data_models (
  id text primary key,                         -- index.json models[].id
  make_id text not null references public.data_makes(id) on delete cascade,
  group_id text null,
  label text not null,
  years_from integer null,
  years_to integer null,
  years_label text null,
  torque_file text not null,                   -- current torque.json path
  service_file text null,                      -- usually same folder + service.json
  aliases jsonb not null default '[]'::jsonb,
  sort_order integer not null default 1000,    -- index.json model sort_order
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (make_id, group_id)
    references public.data_model_groups(make_id, group_id)
);

drop trigger if exists set_data_models_updated_at on public.data_models;
create trigger set_data_models_updated_at
before update on public.data_models
for each row execute function public.set_updated_at();

create index if not exists idx_data_models_make_order
on public.data_models(make_id, sort_order, label);

-- =========================
-- Torque data
-- =========================

create table if not exists public.data_torque_items (
  id uuid primary key default gen_random_uuid(),
  model_id text not null references public.data_models(id) on delete cascade,
  item_key text not null,                      -- torque.json items[].id
  system text null,
  group_name text null,
  component_name text not null,
  common_name jsonb not null default '[]'::jsonb,
  tightening_type text null,
  torque_nm_single numeric null,
  torque_steps_raw text null,                  -- current JSON stores this as a compact string
  thread_spec text null,
  threadlock text null,
  threadlock_symbol text null,
  lubrication text null,
  lubrication_symbol text null,
  sealant text null,
  sealant_symbol text null,
  special_tool_numbers jsonb null,
  special_tool_name text null,
  tightening_seq text null,
  extra_notes jsonb null,
  item_number text null,
  sample_questions text null,
  sort_order integer not null default 1000,
  is_active boolean not null default true,
  raw_item jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (model_id, item_key)
);

drop trigger if exists set_data_torque_items_updated_at on public.data_torque_items;
create trigger set_data_torque_items_updated_at
before update on public.data_torque_items
for each row execute function public.set_updated_at();

create index if not exists idx_data_torque_items_model_order
on public.data_torque_items(model_id, sort_order, component_name);

create index if not exists idx_data_torque_items_model_system
on public.data_torque_items(model_id, system);

create table if not exists public.data_torque_steps (
  id uuid primary key default gen_random_uuid(),
  torque_item_id uuid not null references public.data_torque_items(id) on delete cascade,
  step_order integer not null default 1,
  label text not null,                         -- e.g. Step1, M8
  value text not null,                         -- e.g. 2Nm, 45Nm, 45 degrees
  torque_nm numeric null,
  angle_degrees numeric null,
  raw_step jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (torque_item_id, step_order)
);

drop trigger if exists set_data_torque_steps_updated_at on public.data_torque_steps;
create trigger set_data_torque_steps_updated_at
before update on public.data_torque_steps
for each row execute function public.set_updated_at();

create table if not exists public.data_torque_images (
  id uuid primary key default gen_random_uuid(),
  torque_item_id uuid not null references public.data_torque_items(id) on delete cascade,
  image_path text not null,                    -- torque.json ref_images[] filename/path
  sort_order integer not null default 1,
  alt_text text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (torque_item_id, image_path)
);

drop trigger if exists set_data_torque_images_updated_at on public.data_torque_images;
create trigger set_data_torque_images_updated_at
before update on public.data_torque_images
for each row execute function public.set_updated_at();

create table if not exists public.data_torque_notes (
  id uuid primary key default gen_random_uuid(),
  torque_item_id uuid not null references public.data_torque_items(id) on delete cascade,
  note_text text not null,
  sort_order integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists set_data_torque_notes_updated_at on public.data_torque_notes;
create trigger set_data_torque_notes_updated_at
before update on public.data_torque_notes
for each row execute function public.set_updated_at();

-- =========================
-- Service/spec data
-- =========================

create table if not exists public.data_service_topics (
  id uuid primary key default gen_random_uuid(),
  model_id text not null references public.data_models(id) on delete cascade,
  topic_key text not null,                     -- service.json specs[].topic_id
  title text not null,
  category text null,
  aliases jsonb not null default '[]'::jsonb,
  sort_order integer not null default 1000,
  is_active boolean not null default true,
  raw_topic jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (model_id, topic_key)
);

drop trigger if exists set_data_service_topics_updated_at on public.data_service_topics;
create trigger set_data_service_topics_updated_at
before update on public.data_service_topics
for each row execute function public.set_updated_at();

create table if not exists public.data_service_groups (
  id uuid primary key default gen_random_uuid(),
  service_topic_id uuid not null references public.data_service_topics(id) on delete cascade,
  group_order integer not null default 1,
  group_title text null,
  format text not null default 'table',        -- table or kv
  note text null,
  raw_group jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (service_topic_id, group_order)
);

drop trigger if exists set_data_service_groups_updated_at on public.data_service_groups;
create trigger set_data_service_groups_updated_at
before update on public.data_service_groups
for each row execute function public.set_updated_at();

create table if not exists public.data_service_rows (
  id uuid primary key default gen_random_uuid(),
  service_group_id uuid not null references public.data_service_groups(id) on delete cascade,
  row_order integer not null default 1,
  label text null,                             -- kv format label
  value text null,                             -- kv format value
  col_1_label text null,
  col_1_value text null,
  col_2_label text null,
  col_2_value text null,
  col_3_label text null,
  col_3_value text null,
  col_4_label text null,
  col_4_value text null,
  raw_row jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (service_group_id, row_order)
);

drop trigger if exists set_data_service_rows_updated_at on public.data_service_rows;
create trigger set_data_service_rows_updated_at
before update on public.data_service_rows
for each row execute function public.set_updated_at();

-- =========================
-- Lexicon data
-- =========================

create table if not exists public.data_lexicon_entries (
  id uuid primary key default gen_random_uuid(),
  lexicon_name text not null,                  -- part_triggers, spec_triggers, generic_stopwords, etc.
  term text not null,
  word_count integer null,
  source text null,
  sort_order integer not null default 1000,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lexicon_name, term)
);

drop trigger if exists set_data_lexicon_entries_updated_at on public.data_lexicon_entries;
create trigger set_data_lexicon_entries_updated_at
before update on public.data_lexicon_entries
for each row execute function public.set_updated_at();

create index if not exists idx_data_lexicon_entries_name_order
on public.data_lexicon_entries(lexicon_name, sort_order, term);

-- =========================
-- RLS
-- =========================
-- These policies are for future admin/API use. Supabase Table Editor and SQL
-- Editor access is still controlled by your Supabase project permissions.

alter table public.data_makes enable row level security;
alter table public.data_model_groups enable row level security;
alter table public.data_models enable row level security;
alter table public.data_torque_items enable row level security;
alter table public.data_torque_steps enable row level security;
alter table public.data_torque_images enable row level security;
alter table public.data_torque_notes enable row level security;
alter table public.data_service_topics enable row level security;
alter table public.data_service_groups enable row level security;
alter table public.data_service_rows enable row level security;
alter table public.data_lexicon_entries enable row level security;

drop policy if exists "Admins can manage data_makes" on public.data_makes;
create policy "Admins can manage data_makes"
on public.data_makes for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_model_groups" on public.data_model_groups;
create policy "Admins can manage data_model_groups"
on public.data_model_groups for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_models" on public.data_models;
create policy "Admins can manage data_models"
on public.data_models for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_torque_items" on public.data_torque_items;
create policy "Admins can manage data_torque_items"
on public.data_torque_items for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_torque_steps" on public.data_torque_steps;
create policy "Admins can manage data_torque_steps"
on public.data_torque_steps for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_torque_images" on public.data_torque_images;
create policy "Admins can manage data_torque_images"
on public.data_torque_images for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_torque_notes" on public.data_torque_notes;
create policy "Admins can manage data_torque_notes"
on public.data_torque_notes for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_service_topics" on public.data_service_topics;
create policy "Admins can manage data_service_topics"
on public.data_service_topics for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_service_groups" on public.data_service_groups;
create policy "Admins can manage data_service_groups"
on public.data_service_groups for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_service_rows" on public.data_service_rows;
create policy "Admins can manage data_service_rows"
on public.data_service_rows for all
using (public.is_admin())
with check (public.is_admin());

drop policy if exists "Admins can manage data_lexicon_entries" on public.data_lexicon_entries;
create policy "Admins can manage data_lexicon_entries"
on public.data_lexicon_entries for all
using (public.is_admin())
with check (public.is_admin());
