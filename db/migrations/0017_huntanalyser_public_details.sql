-- HuntNexus Brain — Phase 8.2 HuntAnalyser public detail smoke.
-- Public detail pages only. Max 10 sessions/call; use 5 for smoke validation.

alter table session_players add column if not exists player_name_hash text;
alter table session_creatures add column if not exists monster_name_raw text;
alter table session_creatures add column if not exists resolution_status text default 'unresolved';

create table if not exists community_session_detail_state (
  session_id uuid primary key references community_sessions(id) on delete cascade,
  source_id uuid not null references sources(id),
  detail_snapshot_id uuid references raw_snapshots(id),
  fetched_at timestamptz,
  status text not null default 'pending',
  error_text text
);

create index if not exists idx_community_detail_status
  on community_session_detail_state(status);

create or replace function huntnexus_resolve_creature_exact(p_name text)
returns text
language sql
stable
as $$
  with normalized as (
    select huntnexus_normalize_label(p_name) as k
  ),
  direct as (
    select e.entity_key
    from tibia_entities e, normalized n
    where e.entity_type='creature'
      and huntnexus_normalize_label(e.name)=n.k
    limit 1
  ),
  aliased as (
    select a.canonical_key as entity_key
    from entity_aliases a, normalized n
    where a.entity_type='creature'
      and a.alias_key=n.k
    limit 1
  )
  select coalesce((select entity_key from direct),(select entity_key from aliased));
$$;

create or replace function huntnexus_ingest_huntanalyser_public_details(p_limit int default 5)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_session record;
  v_resp record;
  v_html text;
  v_compact text;
  v_hash text;
  v_snapshot uuid;
  v_party_html text;
  v_monster_html text;
  v_member text[];
  v_kill text[];
  v_name text;
  v_player_hash text;
  v_monster_name text;
  v_monster_key text;
  v_completed int := 0;
  v_errors int := 0;
  v_players int := 0;
  v_kills int := 0;
begin
  select id into strict v_source
  from sources
  where name='HuntAnalyser Public Hunts';

  for v_session in
    select cs.id,cs.external_id,cs.source_url
    from community_sessions cs
    left join community_session_detail_state ds on ds.session_id=cs.id
    where cs.source_id=v_source
      and coalesce(ds.status,'pending') <> 'completed'
    order by cs.external_id::bigint desc
    limit greatest(1,least(coalesce(p_limit,5),10))
  loop
    begin
      insert into community_session_detail_state(session_id,source_id,fetched_at,status,error_text)
      values(v_session.id,v_source,now(),'running',null)
      on conflict(session_id) do update set
        source_id=excluded.source_id,
        fetched_at=excluded.fetched_at,
        status='running',
        error_text=null;

      select * into v_resp
      from extensions.http_get(v_session.source_url);

      if v_resp.status <> 200 then
        raise exception 'HTTP % on %',v_resp.status,v_session.source_url;
      end if;

      v_html := v_resp.content;
      v_compact := regexp_replace(v_html,E'[\n\r\t]+',' ','g');
      v_compact := regexp_replace(v_compact,'[ ]+',' ','g');
      v_hash := encode(extensions.digest(v_html,'sha256'),'hex');

      insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
      values(
        v_source,now(),v_session.source_url,v_hash,
        jsonb_build_object(
          'kind','huntanalyser_public_detail',
          'external_id',v_session.external_id,
          'html',v_html
        )
      )
      on conflict(source_id,content_hash) do nothing;

      select id into v_snapshot
      from raw_snapshots
      where source_id=v_source and content_hash=v_hash
      limit 1;

      -- Isolate Party Members table to avoid parsing payment rows.
      v_party_html := substring(
        v_compact
        from 'Party Members</h3>(.*?)(?:<!-- Payment Distribution Table -->|Members Details)'
      );

      if v_party_html is not null then
        delete from session_players where session_id=v_session.id;

        for v_member in
          select m
          from regexp_matches(
            v_party_html,
            '<td class="py-2">([^<]+)[[:space:]]+\((EK|ED|RP|MS|EM)[[:space:]]+([0-9]+)\)</td>[[:space:]]*<td class="py-2">[[:space:]]*([0-9,.-]+)[[:space:]]*<span[^>]*>[^<]*</span>[[:space:]]*</td>[[:space:]]*<td class="py-2 hidden md:table-cell">([0-9,.-]+)</td>[[:space:]]*<td class="py-2 hidden md:table-cell ha-text-danger">[[:space:]]*<i[^>]*></i>[[:space:]]*([-0-9,]+)[[:space:]]*</td>[[:space:]]*<td class="py-2 ha-text-[^"]+">[[:space:]]*<i[^>]*></i>[[:space:]]*([-0-9,]+)[[:space:]]*</td>',
            'g'
          ) m
        loop
          v_name := trim(v_member[1]);
          v_player_hash := encode(extensions.digest(lower(v_name),'sha256'),'hex');

          insert into session_players(
            session_id,vocation,level,damage,healing,supplies,metadata,player_name_hash
          )
          values(
            v_session.id,
            v_member[2],
            v_member[3]::int,
            replace(v_member[4],',','')::numeric,
            replace(v_member[5],',','')::numeric,
            nullif(replace(v_member[6],',',''),'-')::numeric,
            jsonb_build_object(
              'source_stage','public_detail',
              'member_balance',nullif(replace(v_member[7],',',''),'-')::numeric
            ),
            v_player_hash
          );
          v_players := v_players+1;
        end loop;
      end if;

      -- Isolate Monster Killed table.
      v_monster_html := substring(
        v_compact
        from 'Monster Killed</h2>(.*?)(?:</table>)'
      );

      if v_monster_html is not null then
        delete from session_creatures where session_id=v_session.id;

        for v_kill in
          select m
          from regexp_matches(
            v_monster_html,
            '<img alt="([^"]+)"[^>]*>[^<]*</td>[[:space:]]*<td class="py-2">([0-9,]+)</td>',
            'g'
          ) m
        loop
          v_monster_name := trim(v_kill[1]);
          v_monster_key := huntnexus_resolve_creature_exact(v_monster_name);

          insert into session_creatures(
            session_id,monster_key,kills,monster_name_raw,resolution_status
          )
          values(
            v_session.id,
            v_monster_key,
            replace(v_kill[2],',','')::int,
            v_monster_name,
            case when v_monster_key is null then 'unresolved' else 'resolved_exact' end
          );
          v_kills := v_kills+1;
        end loop;
      end if;

      update community_sessions
      set total_damage=(
            select sum(damage) from session_players where session_id=v_session.id
          ),
          total_healing=(
            select sum(healing) from session_players where session_id=v_session.id
          ),
          raw_payload=coalesce(raw_payload,'{}'::jsonb) ||
            jsonb_build_object(
              'detail_ingested',true,
              'detail_snapshot_id',v_snapshot
            )
      where id=v_session.id;

      update community_session_detail_state
      set detail_snapshot_id=v_snapshot,
          fetched_at=now(),
          status='completed',
          error_text=null
      where session_id=v_session.id;

      v_completed := v_completed+1;

    exception when others then
      v_errors := v_errors+1;
      insert into community_session_detail_state(session_id,source_id,fetched_at,status,error_text)
      values(v_session.id,v_source,now(),'error',sqlerrm)
      on conflict(session_id) do update set
        source_id=excluded.source_id,
        fetched_at=excluded.fetched_at,
        status='error',
        error_text=excluded.error_text;
    end;

    perform pg_sleep(0.75);
  end loop;

  return jsonb_build_object(
    'details_completed',v_completed,
    'details_errors',v_errors,
    'player_rows_written',v_players,
    'creature_rows_written',v_kills,
    'completed_total',(
      select count(*) from community_session_detail_state where source_id=v_source and status='completed'
    ),
    'remaining_from_current_smoke',(
      select count(*)
      from community_sessions cs
      left join community_session_detail_state ds on ds.session_id=cs.id
      where cs.source_id=v_source and coalesce(ds.status,'pending')<>'completed'
    )
  );
end;
$$;

revoke all on function huntnexus_ingest_huntanalyser_public_details(integer)
  from public,anon,authenticated;
revoke all on function huntnexus_resolve_creature_exact(text)
  from public,anon,authenticated;

grant execute on function huntnexus_ingest_huntanalyser_public_details(integer)
  to service_role;
grant execute on function huntnexus_resolve_creature_exact(text)
  to service_role;
