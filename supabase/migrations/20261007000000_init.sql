-- Darboğaz: parts catalog, price cache and user builds.

create extension if not exists pg_trgm;

create type part_category as enum
  ('cpu', 'gpu', 'motherboard', 'ram', 'psu', 'pcCase', 'cooler');

-- One row per part. Category-specific specs live in `specs` and mirror the
-- perf_engine Dart models (e.g. socket, gamingScore, vramGb ...).
create table public.parts (
  id            text primary key,
  category      part_category not null,
  brand         text not null,
  model         text not null,
  mpn           text,
  eans          text[] not null default '{}',
  aliases       text[] not null default '{}',
  specs         jsonb not null,
  ref_price_usd numeric(10, 2),
  updated_at    timestamptz not null default now()
);

create index parts_category_idx on public.parts (category);
create index parts_mpn_idx on public.parts (lower(mpn));
create index parts_eans_idx on public.parts using gin (eans);
create index parts_name_trgm_idx
  on public.parts using gin ((brand || ' ' || model) gin_trgm_ops);

-- Cached offers fetched by the price-search Edge Function from official
-- store APIs / affiliate feeds. Never written by clients.
create table public.price_offers (
  id          bigint generated always as identity primary key,
  part_id     text references public.parts (id) on delete cascade,
  query       text not null check (query = lower(query)),
  store       text not null,
  price       numeric(12, 2) not null check (price > 0),
  currency    char(3) not null default 'TRY',
  url         text not null check (url like 'https://%'),
  in_stock    boolean not null default true,
  fetched_at  timestamptz not null default now()
);

create index price_offers_query_idx on public.price_offers (query, fetched_at desc);
create index price_offers_part_idx on public.price_offers (part_id, fetched_at desc);

-- Saved builds (Phase 5: auth).
create table public.builds (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  name        text not null check (char_length(name) between 1 and 80),
  part_ids    jsonb not null,
  is_public   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index builds_user_idx on public.builds (user_id);

-- Row Level Security --------------------------------------------------------

alter table public.parts enable row level security;
alter table public.price_offers enable row level security;
alter table public.builds enable row level security;

create policy "parts are public" on public.parts
  for select using (true);

create policy "offers are public" on public.price_offers
  for select using (true);

create policy "owners read builds" on public.builds
  for select using (auth.uid() = user_id or is_public);

create policy "owners insert builds" on public.builds
  for insert with check (auth.uid() = user_id);

create policy "owners update builds" on public.builds
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "owners delete builds" on public.builds
  for delete using (auth.uid() = user_id);

-- Fuzzy part search used by the app and the Edge Function.
create or replace function public.search_parts(q text, max_rows int default 20)
returns setof public.parts
language sql stable
set search_path = public
as $$
  select *
  from public.parts p
  where lower(p.mpn) = lower(q)
     or q = any (p.eans)
     or (p.brand || ' ' || p.model) % q
     or (p.brand || ' ' || p.model) ilike '%' || q || '%'
  order by (lower(p.mpn) = lower(q)) desc,
           similarity(p.brand || ' ' || p.model, q) desc
  limit least(max_rows, 50);
$$;
