-- SAM. access period policy.
-- current_period_end keeps Stripe's original billing period end.
-- access_until is SAM.'s actual access cutoff.

alter table public.entitlements
  add column if not exists access_until timestamptz;

create index if not exists idx_entitlements_access_until
on public.entitlements(access_until);

-- Backfill existing paid rows using SAM.'s calendar-day access policy.
-- Example: if Stripe period end is Jun 2 in America/New_York,
-- access_until becomes Jun 3 00:00:00 America/New_York.
update public.entitlements
set access_until = coalesce(
  access_until,
  (((current_period_end at time zone 'America/New_York')::date + 1)::timestamp at time zone 'America/New_York'),
  current_period_end,
  trial_ends_at
)
where plan = 'paid';
