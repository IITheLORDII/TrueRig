-- Public-page price collection: per-host request log for the hourly budget,
-- and product images matched by MPN/GTIN. Both are written only by the
-- price-search Edge Function (service role).

create table public.crawl_requests (
  id            bigint generated always as identity primary key,
  host          text not null,
  requested_at  timestamptz not null default now()
);

create index crawl_requests_host_time_idx
  on public.crawl_requests (host, requested_at desc);

alter table public.crawl_requests enable row level security;
-- No policies: invisible to anon/authenticated clients.

-- Image URLs only; files stay on the source site (no re-hosting).
create table public.part_images (
  query       text primary key check (query = lower(query)),
  part_id     text references public.parts (id) on delete set null,
  image_url   text not null check (image_url like 'https://%'),
  source_url  text not null,
  store       text not null,
  fetched_at  timestamptz not null default now()
);

alter table public.part_images enable row level security;

create policy "part images are public" on public.part_images
  for select using (true);

-- Keep the request log small.
create or replace function public.prune_crawl_requests()
returns void
language sql
set search_path = public
as $$
  delete from public.crawl_requests where requested_at < now() - interval '2 days';
$$;
