create table if not exists public.search_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  user_id uuid not null references auth.users(id) on delete cascade,
  email text,

  source text not null check (source in ('text', 'voice', 'voice_text', 'vision', 'vision_text')),
  raw_query text,
  normalized_query text,
  analysis_source text not null check (analysis_source in ('route', 'vision', 'local')),

  make_id text,
  make_label text,
  model_id text,
  model_label text,
  dataset_file text,

  route_llm_query text,
  route_part_phrases text[],
  route_llm_query_confidence numeric,
  route_part_phrases_confidence numeric,
  route_overall_confidence numeric,

  vision_query text,
  vision_confidence numeric,
  vision_warnings text[],

  result_type text not null check (result_type in (
    'match',
    'spec_match',
    'multiple_matches',
    'no_match',
    'low_confidence',
    'too_generic',
    'needs_detail',
    'usage_limit_reached',
    'trial_expired',
    'subscription_inactive',
    'guest_limit',
    'usage_confirm_failed',
    'usage_blocked'
  )),
  matched_item_id text,
  matched_item_name text,
  matched_item_common_name text,
  matched_spec_id text,
  matched_spec_title text,
  candidate_count integer,
  best_score numeric,
  score_gap numeric,

  search_consumed boolean not null default false,
  search_count_after integer,
  search_limit integer,
  account_plan text,
  account_status text,

  page_url text,
  browser_info text,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists search_events_user_created_at_idx
on public.search_events (user_id, created_at desc);

create index if not exists search_events_result_type_idx
on public.search_events (result_type, created_at desc);

alter table public.search_events enable row level security;

grant select, insert, update on public.search_events to authenticated;

drop policy if exists "Users can create own search events" on public.search_events;
create policy "Users can create own search events"
on public.search_events
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can view own search events" on public.search_events;
create policy "Users can view own search events"
on public.search_events
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can update own search events" on public.search_events;
create policy "Users can update own search events"
on public.search_events
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
