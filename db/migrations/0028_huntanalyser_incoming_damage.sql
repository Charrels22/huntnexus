-- HuntNexus Brain — Phase 11 observed incoming-damage evidence.
-- Parses existing public HuntAnalyser detail snapshots; performs no new remote requests.

create table if not exists session_incoming_damage (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references community_sessions(id) on delete cascade,
  player_id uuid references session_players(id) on delete cascade,
  player_name_hash text not null,
  element text not null,
  damage numeric not null,
  share_percent numeric,
  total_input_damage numeric,
  max_dps numeric,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null default now(),
  unique(session_id,player_name_hash,element)
);

create table if not exists session_incoming_damage_sources (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references community_sessions(id) on delete cascade,
  player_id uuid references session_players(id) on delete cascade,
  player_name_hash text not null,
  monster_key text,
  monster_name_raw text not null,
  damage numeric not null,
  share_percent numeric,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null default now(),
  unique(session_id,player_name_hash,monster_name_raw)
);

create table if not exists community_session_damage_state (
  session_id uuid primary key references community_sessions(id) on delete cascade,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  parsed_subjects int not null default 0,
  parsed_elements int not null default 0,
  parsed_monster_sources int not null default 0,
  status text not null default 'pending',
  error_text text,
  parsed_at timestamptz
);

create index if not exists idx_session_incoming_damage_hunt
  on session_incoming_damage(session_id,element);

create or replace function huntnexus_parse_huntanalyser_incoming_damage(p_limit int default 25)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_rec record;
  v_html text;
  v_player record;
  v_player_hash text;
  v_player_id uuid;
  v_panel text;
  v_total numeric;
  v_max_dps numeric;
  v_types text;
  v_monsters text;
  v_m text[];
  v_monster_key text;
  v_sessions int := 0;
  v_subjects int := 0;
  v_elements int := 0;
  v_monster_sources int := 0;
  v_errors int := 0;
  v_session_subjects int;
  v_session_elements int;
  v_session_monsters int;
begin
  select id into strict v_source
  from sources
  where name='HuntAnalyser Public Hunts';

  for v_rec in
    select
      cs.id as session_id,
      ds.detail_snapshot_id as snapshot_id,
      rs.payload->>'html' as html
    from community_sessions cs
    join community_session_detail_state ds
      on ds.session_id=cs.id and ds.status='completed'
    join raw_snapshots rs on rs.id=ds.detail_snapshot_id
    left join community_session_damage_state st on st.session_id=cs.id
    where cs.source_id=v_source
      and coalesce(st.status,'pending')<>'completed'
    order by cs.external_id::bigint desc
    limit greatest(1,least(coalesce(p_limit,25),100))
  loop
    begin
      v_html := regexp_replace(regexp_replace(v_rec.html,E'[\n\r\t]+',' ','g'),'[ ]+',' ','g');
      v_session_subjects := 0;
      v_session_elements := 0;
      v_session_monsters := 0;

      delete from session_incoming_damage where session_id=v_rec.session_id;
      delete from session_incoming_damage_sources where session_id=v_rec.session_id;

      for v_player in
        with buttons as (
          select ordinality::int as ord,trim(m[1]) as player_name
          from regexp_matches(
            v_html,
            'data-tabs-target="tab" class="ha-tab">([^<]+)</button>',
            'g'
          ) with ordinality as x(m,ordinality)
        ),
        panels as (
          select (ordinality-1)::int as ord,part as panel
          from regexp_split_to_table(
            v_html,
            '<div data-tabs-target="tabpanel" class="tab-content hidden">'
          ) with ordinality as x(part,ordinality)
          where ordinality>1
        )
        select b.player_name,p.panel
        from buttons b
        join panels p using(ord)
        where strpos(p.panel,'Input Damage Summary')>0
      loop
        v_player_hash := encode(extensions.digest(lower(trim(v_player.player_name)),'sha256'),'hex');

        select id into v_player_id
        from session_players
        where session_id=v_rec.session_id
          and player_name_hash=v_player_hash
        limit 1;

        v_panel := v_player.panel;

        v_m := regexp_match(
          v_panel,
          'Input Damage Summary.*?Total</p>[[:space:]]*<p class="text-brand-ink font-semibold">([0-9,]+)</p>'
        );
        v_total := case when v_m is null then null else replace(v_m[1],',','')::numeric end;

        v_m := regexp_match(
          v_panel,
          'Max-DPS</p>[[:space:]]*<p class="text-brand-ink font-semibold">([0-9,]+)</p>'
        );
        v_max_dps := case when v_m is null then null else replace(v_m[1],',','')::numeric end;

        v_types := substring(
          v_panel
          from 'Types</h3>(.*?)(?:</table>)'
        );

        if v_types is not null then
          for v_m in
            select m
            from regexp_matches(
              v_types,
              '<img alt="([^"]+)"[^>]*>[^<]*</td>[[:space:]]*<td class="py-2">([0-9,]+)[[:space:]]*\(([0-9.]+)%\)</td>',
              'g'
            ) m
          loop
            insert into session_incoming_damage(
              session_id,player_id,player_name_hash,element,damage,share_percent,
              total_input_damage,max_dps,source_id,snapshot_id,observed_at
            )
            values(
              v_rec.session_id,v_player_id,v_player_hash,
              replace(lower(trim(v_m[1])),' ','_'),
              replace(v_m[2],',','')::numeric,
              v_m[3]::numeric,
              v_total,v_max_dps,v_source,v_rec.snapshot_id,now()
            )
            on conflict(session_id,player_name_hash,element) do update set
              player_id=excluded.player_id,
              damage=excluded.damage,
              share_percent=excluded.share_percent,
              total_input_damage=excluded.total_input_damage,
              max_dps=excluded.max_dps,
              source_id=excluded.source_id,
              snapshot_id=excluded.snapshot_id,
              observed_at=excluded.observed_at;

            v_elements := v_elements+1;
            v_session_elements := v_session_elements+1;
          end loop;
        end if;

        v_monsters := substring(
          v_panel
          from 'Monsters</h3>(.*?)(?:</table>)'
        );

        if v_monsters is not null then
          for v_m in
            select m
            from regexp_matches(
              v_monsters,
              '<img alt="([^"]+)"[^>]*>[^<]*</td>[[:space:]]*<td class="py-2">([0-9,]+)[[:space:]]*\(([0-9.]+)%\)</td>',
              'g'
            ) m
          loop
            v_monster_key := huntnexus_resolve_creature_exact(trim(v_m[1]));

            insert into session_incoming_damage_sources(
              session_id,player_id,player_name_hash,monster_key,monster_name_raw,
              damage,share_percent,source_id,snapshot_id,observed_at
            )
            values(
              v_rec.session_id,v_player_id,v_player_hash,v_monster_key,trim(v_m[1]),
              replace(v_m[2],',','')::numeric,v_m[3]::numeric,
              v_source,v_rec.snapshot_id,now()
            )
            on conflict(session_id,player_name_hash,monster_name_raw) do update set
              player_id=excluded.player_id,
              monster_key=excluded.monster_key,
              damage=excluded.damage,
              share_percent=excluded.share_percent,
              source_id=excluded.source_id,
              snapshot_id=excluded.snapshot_id,
              observed_at=excluded.observed_at;

            v_monster_sources := v_monster_sources+1;
            v_session_monsters := v_session_monsters+1;
          end loop;
        end if;

        v_subjects := v_subjects+1;
        v_session_subjects := v_session_subjects+1;
      end loop;

      insert into community_session_damage_state(
        session_id,source_id,snapshot_id,parsed_subjects,parsed_elements,
        parsed_monster_sources,status,error_text,parsed_at
      )
      values(
        v_rec.session_id,v_source,v_rec.snapshot_id,v_session_subjects,
        v_session_elements,v_session_monsters,'completed',null,now()
      )
      on conflict(session_id) do update set
        source_id=excluded.source_id,
        snapshot_id=excluded.snapshot_id,
        parsed_subjects=excluded.parsed_subjects,
        parsed_elements=excluded.parsed_elements,
        parsed_monster_sources=excluded.parsed_monster_sources,
        status='completed',
        error_text=null,
        parsed_at=now();

      v_sessions := v_sessions+1;

    exception when others then
      v_errors := v_errors+1;
      insert into community_session_damage_state(
        session_id,source_id,snapshot_id,status,error_text,parsed_at
      )
      values(v_rec.session_id,v_source,v_rec.snapshot_id,'error',sqlerrm,now())
      on conflict(session_id) do update set
        status='error',
        error_text=excluded.error_text,
        parsed_at=now();
    end;
  end loop;

  return jsonb_build_object(
    'sessions_processed',v_sessions,
    'subjects_with_input_damage',v_subjects,
    'element_rows',v_elements,
    'monster_source_rows',v_monster_sources,
    'errors',v_errors,
    'remaining',(
      select count(*)
      from community_sessions cs
      join community_session_detail_state ds
        on ds.session_id=cs.id and ds.status='completed'
      left join community_session_damage_state st on st.session_id=cs.id
      where cs.source_id=v_source
        and coalesce(st.status,'pending')<>'completed'
    )
  );
end;
$$;

revoke all on function huntnexus_parse_huntanalyser_incoming_damage(integer)
  from public,anon,authenticated;
grant execute on function huntnexus_parse_huntanalyser_incoming_damage(integer)
  to service_role;
