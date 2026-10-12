-- Abuse protection for the price-search Edge Function.
--
-- api_crawls: one row per cache miss that triggered a store crawl, keyed by a
-- salted SHA-256 of the caller's address (never the address itself). Used for
-- per-client and global hourly caps shared by all function instances.
-- Written only by the Edge Function (service role).

create table public.api_crawls (
  id            bigint generated always as identity primary key,
  client        text not null check (client ~ '^[0-9a-f]{64}$'),
  requested_at  timestamptz not null default now()
);

create index api_crawls_client_time_idx
  on public.api_crawls (client, requested_at desc);
create index api_crawls_time_idx
  on public.api_crawls (requested_at desc);

alter table public.api_crawls enable row level security;
-- No policies: invisible to anon/authenticated clients.
