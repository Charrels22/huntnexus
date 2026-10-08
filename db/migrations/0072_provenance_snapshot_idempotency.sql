-- HuntNexus — make provenance parsing snapshot-idempotent, including
-- legitimate zero-row provenance results.

alter table public.community_session_profile_state
  add column if not exists provenance_snapshot_id uuid
  references public.raw_snapshots(id) on delete set null;

update public.community_session_profile_state
set provenance_snapshot_id=detail_snapshot_id
where status='completed'
  and provenance_snapshot_id is null;

CREATE OR REPLACE FUNCTION public.huntnexus_parse_huntanalyser_stat_provenance(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO 'public', 'extensions'
AS $function$
with selected_sessions as materialized (
  select
    cs.id as session_id,
    cs.source_id,
    (cs.raw_payload->>'detail_snapshot_id')::uuid as snapshot_id
  from community_sessions cs
  join community_session_profile_state ps on ps.session_id=cs.id
  where ps.status='completed'
    and cs.raw_payload ? 'detail_snapshot_id'
    and ps.provenance_snapshot_id is distinct from
        (cs.raw_payload->>'detail_snapshot_id')::uuid
  order by cs.external_id::bigint desc
  limit greatest(1,least(coalesce(p_limit,100),1000))
),
deleted as (
  delete from session_player_combat_stat_sources src
  using selected_sessions ss
  where src.session_id=ss.session_id
  returning src.id
),
detail as (
  select
    ss.session_id,
    ss.source_id,
    ss.snapshot_id,
    rs.payload->>'html' as html
  from selected_sessions ss
  join raw_snapshots rs on rs.id=ss.snapshot_id
),
names as (
  select
    d.session_id,d.source_id,d.snapshot_id,
    ord::int as player_ord,
    encode(
      extensions.digest(lower(trim(m[1])),'sha256'),
      'hex'
    ) as player_hash
  from detail d
  cross join lateral regexp_matches(
    d.html,
    '<button data-action="tabs#selectTab" data-tabs-target="tab" class="ha-tab">([^<]+)</button>',
    'g'
  ) with ordinality as x(m,ord)
),
panels as (
  select
    d.session_id,d.source_id,d.snapshot_id,
    (ord-1)::int as player_ord,
    piece as panel_html
  from detail d
  cross join lateral regexp_split_to_table(
    d.html,
    '<div data-tabs-target="tabpanel" class="tab-content hidden">'
  ) with ordinality as x(piece,ord)
  where ord>1
),
members as (
  select
    n.session_id,n.source_id,n.snapshot_id,
    sp.id as player_id,
    p.panel_html
  from names n
  join panels p
    on p.session_id=n.session_id
   and p.player_ord=n.player_ord
  join session_players sp
    on sp.session_id=n.session_id
   and sp.player_name_hash=n.player_hash
),
blocks as (
  select
    m.session_id,m.source_id,m.snapshot_id,m.player_id,
    b_ord::int as block_order,
    piece as block_html
  from members m
  cross join lateral regexp_split_to_table(
    m.panel_html,
    '<div class="mb-3 last:mb-0">'
  ) with ordinality as x(piece,b_ord)
  where b_ord>1
),
stat_blocks as (
  select
    b.*,
    sm[1] as stat_name_raw,
    huntnexus_combat_stat_key(sm[1]) as stat_key
  from blocks b
  cross join lateral regexp_match(
    b.block_html,
    'data-stat="([^"]+)">[[:space:]]*([^<]+)</span>'
  ) sm
),
first_blocks as (
  select *
  from (
    select
      sb.*,
      row_number() over(
        partition by player_id,stat_key
        order by block_order
      ) as rn
    from stat_blocks sb
  ) q
  where rn=1
),
provenance as (
  select
    fb.session_id,fb.source_id,fb.snapshot_id,fb.player_id,
    fb.stat_key,
    p_ord::int as source_order,
    trim(pm[1]) as raw_text
  from first_blocks fb
  cross join lateral regexp_matches(
    fb.block_html,
    'data-provenance>[[:space:]]*([^<]+)</div>',
    'g'
  ) with ordinality as x(pm,p_ord)
),
parsed as (
  select
    p.*,
    (regexp_match(
      p.raw_text,
      '^([+-]?[0-9,.]+)(%)?[[:space:]]+from[[:space:]]+(.+)$'
    ))[1] as contribution_raw,
    (regexp_match(
      p.raw_text,
      '^([+-]?[0-9,.]+)(%)?[[:space:]]+from[[:space:]]+(.+)$'
    ))[2] as percent_marker,
    (regexp_match(
      p.raw_text,
      '^([+-]?[0-9,.]+)(%)?[[:space:]]+from[[:space:]]+(.+)$'
    ))[3] as source_label
  from provenance p
),
inserted as (
  insert into session_player_combat_stat_sources(
    session_id,player_id,source_id,snapshot_id,
    combat_stat_id,stat_key,source_order,
    contribution_value,unit,source_label,raw_text,metadata
  )
  select
    p.session_id,
    p.player_id,
    p.source_id,
    p.snapshot_id,
    cs.id,
    p.stat_key,
    p.source_order,
    nullif(replace(p.contribution_raw,',',''),'')::numeric,
    case
      when p.contribution_raw is null then null
      when p.percent_marker='%' then 'percent'
      else 'number'
    end,
    nullif(trim(p.source_label),''),
    p.raw_text,
    jsonb_build_object(
      'source_stage','huntanalyser_member_details',
      'selection_rule','provenance_from_first_stat_block'
    )
  from parsed p
  join session_player_combat_stats cs
    on cs.player_id=p.player_id
   and cs.snapshot_id=p.snapshot_id
   and cs.stat_key=p.stat_key
  returning session_id
),
counts as (
  select session_id,count(*)::int as provenance_rows
  from inserted
  group by session_id
),
updated as (
  update community_session_profile_state ps
  set provenance_rows=coalesce(c.provenance_rows,0),
      provenance_snapshot_id=ss.snapshot_id,
      parsed_at=now()
  from selected_sessions ss
  left join counts c on c.session_id=ss.session_id
  where ps.session_id=ss.session_id
  returning ps.session_id
)
select jsonb_build_object(
  'sessions_selected',(select count(*) from selected_sessions),
  'sessions_updated',(select count(*) from updated),
  'provenance_rows_written',(select count(*) from inserted)
);
$function$
;

revoke all on function public.huntnexus_parse_huntanalyser_stat_provenance(integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_parse_huntanalyser_stat_provenance(integer)
  to service_role;
