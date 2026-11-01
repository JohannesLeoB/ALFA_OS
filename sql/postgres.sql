-- Additions for Postgres (Supabase). tools/export_supabase.py joins this file with sql/schema.sql
-- into build/supabase_schema.sql. All tables live in the schema kb.
-- Git stays the source. Supabase is a read mirror for agents and apps. Raw catalogue text is never stored here.

create extension if not exists vector with schema extensions;

alter table kb.atoms alter column record type jsonb using record::jsonb;
alter table kb.library_entries alter column record type jsonb using record::jsonb;
alter table kb.media alter column record type jsonb using record::jsonb;
alter table kb.setup_values alter column value type jsonb using value::jsonb;

alter table kb.atoms add column if not exists search tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(statement_en, '')), 'A') ||
    setweight(to_tsvector('german', coalesce(statement_de, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(formula, '')), 'B')
  ) stored;
alter table kb.concepts add column if not exists search tsvector
  generated always as (
    setweight(to_tsvector('english', coalesce(label_en, '') || ' ' || coalesce(synonyms_en, '')), 'A') ||
    setweight(to_tsvector('german', coalesce(label_de, '') || ' ' || coalesce(synonyms_de, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(definition_en, '')), 'C')
  ) stored;
alter table kb.catalog_sections add column if not exists search tsvector
  generated always as (to_tsvector('german', path) || to_tsvector('simple', path)) stored;

create index if not exists atoms_search on kb.atoms using gin (search);
create index if not exists concepts_search on kb.concepts using gin (search);
create index if not exists catalog_sections_search on kb.catalog_sections using gin (search);
create index if not exists edges_dst on kb.edges (dst, rel);
create index if not exists catalog_sections_source on kb.catalog_sections (source, pdf_from);

alter table kb.atoms add column if not exists embedding extensions.vector(1024);
alter table kb.concepts add column if not exists embedding extensions.vector(1024);

-- One row per atom with its concepts, sources and links, for agents.
create or replace view kb.atom_cards with (security_invoker = true) as
select a.id, a.kind, a.domain, a.stage, a.status, a.evidence,
       a.statement_en, a.statement_de, a.formula,
       a.record -> 'concepts' as concepts,
       a.record -> 'sources' as sources,
       coalesce(a.record -> 'links', '[]'::jsonb) as links,
       a.record ->> 'note' as note
from kb.atoms a;

-- Search in German and English over atoms, concepts and catalogue sections.
create or replace function kb.search(query text, max_rows integer default 20)
returns table (id text, kind text, title text, detail text, rank real)
language sql stable
set search_path = ''
as $$
  with q as (
    select websearch_to_tsquery('english', query) as en,
           websearch_to_tsquery('german', query) as de,
           websearch_to_tsquery('simple', query) as si
  )
  select * from (
    select a.id, 'atom', a.statement_en, a.statement_de,
           ts_rank(a.search, q.en) + ts_rank(a.search, q.de) + ts_rank(a.search, q.si) + 0.5
    from kb.atoms a, q where a.search @@ q.en or a.search @@ q.de or a.search @@ q.si
    union all
    select c.id, 'concept', c.label_en, c.label_de,
           ts_rank(c.search, q.en) + ts_rank(c.search, q.de) + 0.3
    from kb.concepts c, q where c.search @@ q.en or c.search @@ q.de or c.search @@ q.si
    union all
    select s.id, 'catalog', s.path, s.source || ' printed ' || coalesce(s.printed_from, '') || ' pdf ' || s.pdf_from,
           ts_rank(s.search, q.de) + ts_rank(s.search, q.si)
    from kb.catalog_sections s, q where s.search @@ q.de or s.search @@ q.si
  ) hits
  order by 5 desc
  limit max_rows;
$$;

-- Resolved values of a setup and all its parents. A lower layer overrides a higher layer.
create or replace function kb.setup_resolved(setup text)
returns table (key text, value jsonb, status text, evidence text, layer text)
language sql stable
set search_path = ''
as $$
  with recursive chain(id, parent, depth) as (
    select s.id, s.parent, 0 from kb.setups s where s.id = setup
    union all
    select p.id, p.parent, c.depth + 1 from kb.setups p join chain c on p.id = c.parent
  )
  select distinct on (v.key) v.key, v.value, v.status, v.evidence, v.setup_id
  from kb.setup_values v join chain c on c.id = v.setup_id
  order by v.key, c.depth;
$$;

-- Edges are derived from the records. The seed calls this function after it loads the tables.
create or replace function kb.rebuild_edges()
returns integer
language plpgsql
set search_path = ''
as $$
declare total integer;
begin
  delete from kb.edges;
  insert into kb.edges (src, rel, dst)
  select id, 'broader', broader from kb.concepts where broader is not null
  union select id, 'part_of', part_of from kb.concepts where part_of is not null
  union select a.id, 'about', c from kb.atoms a, jsonb_array_elements_text(a.record -> 'concepts') c
  union select a.id, 'cites', s ->> 'id' from kb.atoms a, jsonb_array_elements(a.record -> 'sources') s
  union select a.id, l ->> 'rel', l ->> 'to' from kb.atoms a, jsonb_array_elements(coalesce(a.record -> 'links', '[]')) l
  union select e.id, 'cites', s ->> 'id' from kb.library_entries e, jsonb_array_elements(e.record -> 'sources') s
  union select m.id, 'cites', m.source from kb.media m
  union select m.id, 'shows', c from kb.media m, jsonb_array_elements_text(m.record -> 'concepts') c
  union select s.id, 'cites', s.source from kb.catalog_sections s
  union select s.id, 'about', c from kb.catalog_sections s, unnest(string_to_array(s.concepts, ' | ')) c
    where s.concepts is not null;
  select count(*) into total from kb.edges;
  return total;
end;
$$;
revoke execute on function kb.rebuild_edges() from public, anon, authenticated;

-- Readers: signed-in users read everything except library entries that are setup_only.
-- Writers: only the service role (tools/export_supabase.py), which bypasses row level security.
do $$
declare t text;
begin
  foreach t in array array['sources', 'concepts', 'atoms', 'library_entries', 'media', 'setups',
                           'setup_values', 'catalog_sections', 'edges'] loop
    execute format('alter table kb.%I enable row level security', t);
    if t = 'library_entries' then
      execute format('create policy read_%s on kb.%I for select to authenticated using (sharing = %L)', t, t, 'open');
    else
      execute format('create policy read_%s on kb.%I for select to authenticated using (true)', t, t);
    end if;
  end loop;
end $$;

grant usage on schema kb to authenticated;
grant select on all tables in schema kb to authenticated;
revoke execute on function kb.search(text, integer), kb.setup_resolved(text) from public, anon;
grant execute on function kb.search(text, integer), kb.setup_resolved(text) to authenticated;
revoke all on schema kb from anon;
