-- SAM. billing fields for Stripe integration.
-- Run this before deploying the Stripe API endpoints.

alter table public.entitlements
  add column if not exists stripe_customer_id text,
  add column if not exists stripe_subscription_id text,
  add column if not exists stripe_price_id text,
  add column if not exists current_period_start timestamptz,
  add column if not exists current_period_end timestamptz,
  add column if not exists cancel_at_period_end boolean not null default false,
  add column if not exists canceled_at timestamptz,
  add column if not exists billing_updated_at timestamptz;

create index if not exists idx_entitlements_stripe_customer_id
on public.entitlements(stripe_customer_id);

create index if not exists idx_entitlements_stripe_subscription_id
on public.entitlements(stripe_subscription_id);
