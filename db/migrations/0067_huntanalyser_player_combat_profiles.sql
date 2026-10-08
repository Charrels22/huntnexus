-- HuntNexus — normalize HuntAnalyser member combat stats and equipment.
-- Player names remain represented only by the existing SHA-256 player_name_hash.

create table if not exists public.community_session_profile_state (
  session_id uuid primary key references public.community_sessions(id) on delete cascade,
  source_id uuid not null references public.sources(id),
  detail_snapshot_id uuid references public.raw_snapshots(id) on delete set null,
  parsed_at timestamptz not null default now(),
  status text not null default 'pending',
  stats_rows integer not null default 0,
  equipment_rows integer not null default 0,
  error_text text
);

create table if not exists public.session_player_combat_stats (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.community_sessions(id) on delete cascade,
  player_id uuid not null references public.session_players(id) on delete cascade,
  source_id uuid not null references public.sources(id),
  snapshot_id uuid not null references public.raw_snapshots(id) on delete cascade,
  stat_key text not null,
  stat_name_raw text not null,
  numeric_value numeric,
  unit text not null,
  raw_value text not null,
  occurrence_order integer not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(player_id,snapshot_id,stat_key)
);

create table if not exists public.session_player_equipment (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.community_sessions(id) on delete cascade,
  player_id uuid not null references public.session_players(id) on delete cascade,
  source_id uuid not null references public.sources(id),
  snapshot_id uuid not null references public.raw_snapshots(id) on delete cascade,
  slot_key text not null,
  asset_group text,
  item_key text,
  item_name_raw text not null,
  raw_asset_file text not null,
  occurrence_order integer not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(player_id,snapshot_id,slot_key)
);

create index if not exists idx_session_player_combat_stats_session
  on public.session_player_combat_stats(session_id);
create index if not exists idx_session_player_combat_stats_player
  on public.session_player_combat_stats(player_id);
create index if not exists idx_session_player_combat_stats_key
  on public.session_player_combat_stats(stat_key);
create index if not exists idx_session_player_equipment_session
  on public.session_player_equipment(session_id);
create index if not exists idx_session_player_equipment_player
  on public.session_player_equipment(player_id);
create index if not exists idx_session_player_equipment_item
  on public.session_player_equipment(item_key)
  where item_key is not null;

alter table public.community_session_profile_state enable row level security;
alter table public.session_player_combat_stats enable row level security;
alter table public.session_player_equipment enable row level security;

revoke all on public.community_session_profile_state from public,anon,authenticated;
revoke all on public.session_player_combat_stats from public,anon,authenticated;
revoke all on public.session_player_equipment from public,anon,authenticated;
grant select,insert,update,delete on public.community_session_profile_state to service_role;
grant select,insert,update,delete on public.session_player_combat_stats to service_role;
grant select,insert,update,delete on public.session_player_equipment to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_combat_stat_key(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'extensions'
AS $function$
  select case
    when p_name is null then null
    else replace(
      huntnexus_normalize_label(replace(p_name,'%',' percent ')),
      '-',
      '_'
    )
  end;
$function$
;

revoke all on function public.huntnexus_combat_stat_key(text)
  from public,anon,authenticated;
grant execute on function public.huntnexus_combat_stat_key(text) to service_role;

CREATE OR REPLACE FUNCTION public.huntnexus_parse_huntanalyser_player_profiles(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_session record;
  v_html text;
  v_stats integer;
  v_equipment integer;
  v_sessions integer := 0;
  v_errors integer := 0;
  v_stats_total integer := 0;
  v_equipment_total integer := 0;
begin
  for v_session in
    select
      cs.id as session_id,
      cs.source_id,
      (cs.raw_payload->>'detail_snapshot_id')::uuid as snapshot_id
    from community_sessions cs
    left join community_session_profile_state ps
      on ps.session_id=cs.id
    where cs.raw_payload ? 'detail_snapshot_id'
      and (
        ps.session_id is null
        or ps.detail_snapshot_id is distinct from
           (cs.raw_payload->>'detail_snapshot_id')::uuid
        or ps.status <> 'completed'
      )
    order by cs.external_id::bigint desc
    limit greatest(1,least(coalesce(p_limit,100),1000))
  loop
    begin
      insert into community_session_profile_state(
        session_id,source_id,detail_snapshot_id,parsed_at,status,
        stats_rows,equipment_rows,error_text
      )
      values(
        v_session.session_id,v_session.source_id,v_session.snapshot_id,
        now(),'running',0,0,null
      )
      on conflict(session_id) do update set
        source_id=excluded.source_id,
        detail_snapshot_id=excluded.detail_snapshot_id,
        parsed_at=excluded.parsed_at,
        status='running',
        stats_rows=0,
        equipment_rows=0,
        error_text=null;

      select payload->>'html'
      into v_html
      from raw_snapshots
      where id=v_session.snapshot_id;

      if v_html is null then
        raise exception 'Missing HTML for detail snapshot %',v_session.snapshot_id;
      end if;

      delete from session_player_combat_stats
      where session_id=v_session.session_id;

      delete from session_player_equipment
      where session_id=v_session.session_id;

      with names as (
        select
          ord::int as player_ord,
          encode(
            extensions.digest(lower(trim(m[1])),'sha256'),
            'hex'
          ) as player_hash
        from regexp_matches(
          v_html,
          '<button data-action="tabs#selectTab" data-tabs-target="tab" class="ha-tab">([^<]+)</button>',
          'g'
        ) with ordinality as x(m,ord)
      ),
      panels as (
        select
          (ord-1)::int as player_ord,
          piece as panel_html
        from regexp_split_to_table(
          v_html,
          '<div data-tabs-target="tabpanel" class="tab-content hidden">'
        ) with ordinality as x(piece,ord)
        where ord>1
      ),
      members as (
        select sp.id as player_id,p.panel_html
        from names n
        join panels p using(player_ord)
        join session_players sp
          on sp.session_id=v_session.session_id
         and sp.player_name_hash=n.player_hash
      ),
      stats_all as (
        select
          m.player_id,
          s_ord::int as occurrence_order,
          s[1] as stat_name_raw,
          huntnexus_combat_stat_key(s[1]) as stat_key,
          trim(s[2]) as raw_value
        from members m
        cross join lateral regexp_matches(
          m.panel_html,
          'data-stat="([^"]+)">[[:space:]]*([^<]+)</span>',
          'g'
        ) with ordinality as x(s,s_ord)
      ),
      stats_first as (
        select *
        from (
          select
            s.*,
            row_number() over(
              partition by player_id,stat_key
              order by occurrence_order
            ) as rn
          from stats_all s
        ) q
        where rn=1
      )
      insert into session_player_combat_stats(
        session_id,player_id,source_id,snapshot_id,
        stat_key,stat_name_raw,numeric_value,unit,
        raw_value,occurrence_order,metadata
      )
      select
        v_session.session_id,
        s.player_id,
        v_session.source_id,
        v_session.snapshot_id,
        s.stat_key,
        s.stat_name_raw,
        nullif(
          regexp_replace(
            replace(s.raw_value,',',''),
            '[^0-9.+-]',
            '',
            'g'
          ),
          ''
        )::numeric,
        case
          when s.raw_value like '%\%%' then 'percent'
          when lower(s.raw_value) like '%x' then 'multiplier'
          else 'number'
        end,
        s.raw_value,
        s.occurrence_order,
        jsonb_build_object(
          'source_stage','huntanalyser_member_details',
          'selection_rule','first_data_stat_occurrence_in_member_panel'
        )
      from stats_first s;

      get diagnostics v_stats = row_count;

      with names as (
        select
          ord::int as player_ord,
          encode(
            extensions.digest(lower(trim(m[1])),'sha256'),
            'hex'
          ) as player_hash
        from regexp_matches(
          v_html,
          '<button data-action="tabs#selectTab" data-tabs-target="tab" class="ha-tab">([^<]+)</button>',
          'g'
        ) with ordinality as x(m,ord)
      ),
      panels as (
        select
          (ord-1)::int as player_ord,
          piece as panel_html
        from regexp_split_to_table(
          v_html,
          '<div data-tabs-target="tabpanel" class="tab-content hidden">'
        ) with ordinality as x(piece,ord)
        where ord>1
      ),
      members as (
        select sp.id as player_id,p.panel_html
        from names n
        join panels p using(player_ord)
        join session_players sp
          on sp.session_id=v_session.session_id
         and sp.player_name_hash=n.player_hash
      ),
      equipment_all as (
        select
          m.player_id,
          e_ord::int as occurrence_order,
          e[1] as target,
          e[2] as asset_group,
          e[3] as asset_file,
          replace(
            regexp_replace(
              e[3],
              '-[0-9a-f]{8,}\.(gif|png|webp)$',
              '',
              'i'
            ),
            '_',' '
          ) as item_name_raw
        from members m
        cross join lateral regexp_matches(
          m.panel_html,
          'data-character-item-select-target="([^"]+Slot)"[^>]*src="/assets/([^/]+)/([^"]+)"',
          'g'
        ) with ordinality as x(e,e_ord)
        where e[1] not like 'consumable%'
      ),
      equipment_first as (
        select *
        from (
          select
            e.*,
            row_number() over(
              partition by player_id,target
              order by occurrence_order
            ) as rn
          from equipment_all e
        ) q
        where rn=1
      )
      insert into session_player_equipment(
        session_id,player_id,source_id,snapshot_id,
        slot_key,asset_group,item_key,item_name_raw,
        raw_asset_file,occurrence_order,metadata
      )
      select
        v_session.session_id,
        e.player_id,
        v_session.source_id,
        v_session.snapshot_id,
        case e.target
          when 'amuletSlot' then 'amulet'
          when 'armorSlot' then 'armor'
          when 'bootsSlot' then 'boots'
          when 'extraSlotSlot' then 'extra_slot'
          when 'helmetSlot' then 'helmet'
          when 'leftHandSlot' then 'left_hand'
          when 'legsSlot' then 'legs'
          when 'rightHandSlot' then 'right_hand'
          when 'ringSlot' then 'ring'
          else replace(
            regexp_replace(e.target,'Slot$','','i'),
            '_',''
          )
        end,
        e.asset_group,
        case
          when exists(
            select 1
            from tibia_items i
            where i.slug=huntnexus_normalize_label(e.item_name_raw)
          )
          then huntnexus_normalize_label(e.item_name_raw)
          else null
        end,
        e.item_name_raw,
        e.asset_file,
        e.occurrence_order,
        jsonb_build_object(
          'source_stage','huntanalyser_member_details',
          'selection_rule','first_equipment_slot_occurrence_in_member_panel'
        )
      from equipment_first e;

      get diagnostics v_equipment = row_count;

      update community_session_profile_state
      set parsed_at=now(),
          status='completed',
          stats_rows=v_stats,
          equipment_rows=v_equipment,
          error_text=null
      where session_id=v_session.session_id;

      v_sessions := v_sessions+1;
      v_stats_total := v_stats_total+v_stats;
      v_equipment_total := v_equipment_total+v_equipment;

    exception when others then
      v_errors := v_errors+1;

      insert into community_session_profile_state(
        session_id,source_id,detail_snapshot_id,parsed_at,status,
        stats_rows,equipment_rows,error_text
      )
      values(
        v_session.session_id,v_session.source_id,v_session.snapshot_id,
        now(),'error',0,0,sqlerrm
      )
      on conflict(session_id) do update set
        source_id=excluded.source_id,
        detail_snapshot_id=excluded.detail_snapshot_id,
        parsed_at=excluded.parsed_at,
        status='error',
        stats_rows=0,
        equipment_rows=0,
        error_text=excluded.error_text;
    end;
  end loop;

  return jsonb_build_object(
    'sessions_parsed',v_sessions,
    'sessions_errors',v_errors,
    'stats_rows_written',v_stats_total,
    'equipment_rows_written',v_equipment_total,
    'completed_total',(
      select count(*)
      from community_session_profile_state
      where status='completed'
    ),
    'errors_total',(
      select count(*)
      from community_session_profile_state
      where status='error'
    )
  );
end;
$function$
;

revoke all on function public.huntnexus_parse_huntanalyser_player_profiles(integer)
  from public,anon,authenticated;
grant execute on function public.huntnexus_parse_huntanalyser_player_profiles(integer)
  to service_role;

create or replace view public.vw_session_player_observed_combat_profile
with (security_invoker=true)
as
 WITH stats AS (
         SELECT session_player_combat_stats.player_id,
            jsonb_object_agg(session_player_combat_stats.stat_key, session_player_combat_stats.numeric_value ORDER BY session_player_combat_stats.stat_key) AS stats,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'sword_fighting'::text) AS sword_fighting,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'axe_fighting'::text) AS axe_fighting,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'club_fighting'::text) AS club_fighting,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'distance_fighting'::text) AS distance_fighting,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'fist_fighting'::text) AS fist_fighting,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'magic_level'::text) AS magic_level,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'shielding'::text) AS shielding,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'critical_hit_chance'::text) AS critical_hit_chance,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'critical_extra_damage'::text) AS critical_extra_damage,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'life_leech'::text) AS life_leech,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'mana_leech'::text) AS mana_leech,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'attack_value'::text) AS attack_value,
            max(session_player_combat_stats.numeric_value) FILTER (WHERE session_player_combat_stats.stat_key = 'base_damage'::text) AS base_damage
           FROM session_player_combat_stats
          GROUP BY session_player_combat_stats.player_id
        ), equipment AS (
         SELECT session_player_equipment.player_id,
            max(session_player_equipment.asset_group) FILTER (WHERE session_player_equipment.slot_key = 'left_hand'::text) AS left_hand_asset_group,
            max(session_player_equipment.item_key) FILTER (WHERE session_player_equipment.slot_key = 'left_hand'::text) AS left_hand_item_key,
            max(session_player_equipment.item_name_raw) FILTER (WHERE session_player_equipment.slot_key = 'left_hand'::text) AS left_hand_item_name,
            max(session_player_equipment.item_key) FILTER (WHERE session_player_equipment.slot_key = 'right_hand'::text) AS right_hand_item_key,
            max(session_player_equipment.item_name_raw) FILTER (WHERE session_player_equipment.slot_key = 'right_hand'::text) AS right_hand_item_name,
            jsonb_object_agg(session_player_equipment.slot_key, jsonb_build_object('item_key', session_player_equipment.item_key, 'name', session_player_equipment.item_name_raw, 'asset_group', session_player_equipment.asset_group) ORDER BY session_player_equipment.slot_key) AS equipment
           FROM session_player_equipment
          GROUP BY session_player_equipment.player_id
        )
 SELECT sp.id AS player_id,
    sp.session_id,
    cs.hunt_key,
    cs.server_name,
    cs.session_started_at,
    sp.vocation,
    sp.level,
    sp.damage,
    sp.healing,
    sp.supplies,
        CASE e.left_hand_asset_group
            WHEN 'swords'::text THEN 'sword'::text
            WHEN 'axes'::text THEN 'axe'::text
            WHEN 'clubs'::text THEN 'club'::text
            WHEN 'distances'::text THEN 'distance'::text
            WHEN 'fists'::text THEN 'fist'::text
            WHEN 'rods'::text THEN 'rod'::text
            WHEN 'wands'::text THEN 'wand'::text
            ELSE NULL::text
        END AS observed_weapon_family,
    e.left_hand_item_key AS observed_weapon_item_key,
    e.left_hand_item_name AS observed_weapon_item_name,
    e.right_hand_item_key AS observed_offhand_item_key,
    e.right_hand_item_name AS observed_offhand_item_name,
        CASE e.left_hand_asset_group
            WHEN 'swords'::text THEN s.sword_fighting
            WHEN 'axes'::text THEN s.axe_fighting
            WHEN 'clubs'::text THEN s.club_fighting
            WHEN 'distances'::text THEN s.distance_fighting
            WHEN 'fists'::text THEN s.fist_fighting
            WHEN 'rods'::text THEN s.magic_level
            WHEN 'wands'::text THEN s.magic_level
            ELSE NULL::numeric
        END AS observed_effective_weapon_skill,
    s.shielding AS observed_shielding,
    s.magic_level AS observed_magic_level,
    s.critical_hit_chance,
    s.critical_extra_damage,
    s.life_leech,
    s.mana_leech,
    s.attack_value,
    s.base_damage,
    COALESCE(s.stats, '{}'::jsonb) AS stats,
    COALESCE(e.equipment, '{}'::jsonb) AS equipment
   FROM session_players sp
     JOIN community_sessions cs ON cs.id = sp.session_id
     LEFT JOIN stats s ON s.player_id = sp.id
     LEFT JOIN equipment e ON e.player_id = sp.id;;

revoke all on public.vw_session_player_observed_combat_profile
  from public,anon,authenticated;
grant select on public.vw_session_player_observed_combat_profile to service_role;
