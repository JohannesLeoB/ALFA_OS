-- Additions for Postgres (Supabase). Run sql/schema.sql first, then this file.
-- Full text search in German and English, and a vector column for semantic search later.

create extension if not exists vector;

alter table atoms add column if not exists search tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(statement_en, '')), 'A') ||
    setweight(to_tsvector('german', coalesce(statement_de, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(formula, '')), 'B')
  ) stored;
create index if not exists atoms_search on atoms using gin (search);

alter table concepts add column if not exists search tsvector
  generated always as (
    to_tsvector('english', coalesce(label_en, '') || ' ' || coalesce(synonyms_en, '') || ' ' || coalesce(definition_en, '')) ||
    to_tsvector('german', coalesce(label_de, '') || ' ' || coalesce(synonyms_de, ''))
  ) stored;
create index if not exists concepts_search on concepts using gin (search);

alter table atoms add column if not exists embedding vector(1024);
alter table concepts add column if not exists embedding vector(1024);

create index if not exists edges_dst on edges (dst);

-- Row level security: readers see everything; only the service role writes.
alter table sources enable row level security;
alter table concepts enable row level security;
alter table atoms enable row level security;
alter table library_entries enable row level security;
alter table media enable row level security;
alter table setups enable row level security;
alter table setup_values enable row level security;
alter table edges enable row level security;

create policy read_sources on sources for select to authenticated using (true);
create policy read_concepts on concepts for select to authenticated using (true);
create policy read_atoms on atoms for select to authenticated using (true);
create policy read_library on library_entries for select to authenticated using (sharing = 'open');
create policy read_media on media for select to authenticated using (true);
create policy read_setups on setups for select to authenticated using (true);
create policy read_setup_values on setup_values for select to authenticated using (true);
create policy read_edges on edges for select to authenticated using (true);
