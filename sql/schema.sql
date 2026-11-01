-- Core tables. The same statements run on SQLite and on Postgres (Supabase).
-- The Git files are the source. tools/kb.py and tools/export_supabase.py fill these tables.

create table if not exists sources (
  id text primary key,
  kind text not null,
  publisher text not null,
  title text not null,
  edition text,
  location text,
  trust text not null,
  added text not null,
  note text
);

create table if not exists concepts (
  id text primary key,
  label_en text not null,
  label_de text not null,
  synonyms_en text,
  synonyms_de text,
  broader text,
  part_of text,
  definition_en text,
  definition_de text
);

create table if not exists atoms (
  id text primary key,
  kind text not null,
  domain text not null,
  statement_en text not null,
  statement_de text not null,
  formula text,
  stage text not null,
  status text not null,
  evidence text not null,
  proposed_by text,
  decided_by text,
  added text not null,
  checked text,
  record text not null
);

create table if not exists library_entries (
  id text primary key,
  library text not null,
  maker text not null,
  series text not null,
  name text not null,
  status text not null,
  sharing text not null,
  record text not null
);

create table if not exists media (
  id text primary key,
  kind text not null,
  source text not null,
  locator text not null,
  caption_en text not null,
  caption_de text,
  record text not null
);

create table if not exists setups (
  id text primary key,
  level text not null,
  parent text,
  label text,
  status text not null
);

create table if not exists setup_values (
  setup_id text not null,
  key text not null,
  value text,
  status text not null,
  evidence text not null,
  note text,
  primary key (setup_id, key)
);

create table if not exists catalog_sections (
  id text primary key,
  source text not null,
  level integer not null,
  path text not null,
  printed_from text,
  printed_to text,
  pdf_from integer not null,
  pdf_to integer not null
);

create table if not exists edges (
  src text not null,
  rel text not null,
  dst text not null,
  primary key (src, rel, dst)
);
