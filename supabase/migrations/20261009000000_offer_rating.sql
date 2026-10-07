-- Store / product rating read from public schema.org aggregateRating.
alter table public.price_offers
  add column rating numeric(2, 1) check (rating is null or (rating >= 0 and rating <= 5)),
  add column review_count integer check (review_count is null or review_count >= 0);
