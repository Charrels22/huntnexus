-- HuntNexus Brain — Phase 8 public HuntAnalyser smoke ingestion.
-- Public list pages only. Maximum 5 pages (100 sessions) per call.
-- No login, private data or access-control bypass.

alter table sources add column if not exists terms_review_status text default 'pending';

alter table community_sessions add column if not exists hunt_name_raw text;
alter table community_sessions add column if not exists session_started_at_raw text;
alter table community_sessions add column if not exists author_raw text;
alter table community_sessions add column if not exists description_raw text;
alter table community_sessions add column if not exists hunt_resolution_status text default 'unresolved';

create unique index if not exists uq_community_session_source_external
  on community_sessions(source_id,external_id);

insert into sources(
  name,tier,layer,url,status,collection_method,last_access_status,last_checked_at,terms_review_status
)
values (
  'HuntAnalyser Public Hunts',
  'C',
  'community_observations',
  'https://www.hunt-analyser.com/hunt_sessions?hunt_sessions_by=is_public',
  'review',
  'public HTML list pages',
  'HTTP 200 from Supabase; public hunt list exposes 20 sessions per page',
  now(),
  'pending'
)
on conflict (name) do update set
  tier=excluded.tier,
  layer=excluded.layer,
  url=excluded.url,
  status=excluded.status,
  collection_method=excluded.collection_method,
  last_access_status=excluded.last_access_status,
  last_checked_at=excluded.last_checked_at,
  terms_review_status=excluded.terms_review_status;

create or replace function huntnexus_ingest_huntanalyser_public_pages(p_pages int default 1)
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_page int;
  v_url text;
  v_resp record;
  v_html text;
  v_hash text;
  v_snapshot uuid;
  v_part text;
  v_clean text;
  v_m text[];
  v_external text;
  v_hunt text;
  v_started_raw text;
  v_duration_raw text;
  v_party_raw text;
  v_author text;
  v_description text;
  v_xp_gain numeric;
  v_balance numeric;
  v_xph numeric;
  v_raw_xph numeric;
  v_duration_seconds int;
  v_party_size int;
  v_session_id uuid;
  v_inserted int := 0;
  v_updated int := 0;
  v_players int := 0;
  v_errors int := 0;
  v_pages_done int := 0;
  v_player text[];
begin
  select id into strict v_source
  from sources
  where name='HuntAnalyser Public Hunts';

  for v_page in 1..greatest(1,least(coalesce(p_pages,1),5))
  loop
    begin
      v_url := format(
        'https://www.hunt-analyser.com/hunt_sessions?direction=&hunt_sessions_by=is_public&page=%s&sort=',
        v_page
      );

      select * into v_resp from extensions.http_get(v_url);
      if v_resp.status <> 200 then
        raise exception 'HTTP % on %',v_resp.status,v_url;
      end if;

      v_html := v_resp.content;
      v_hash := encode(extensions.digest(v_html,'sha256'),'hex');

      insert into raw_snapshots(source_id,fetched_at,locator,content_hash,payload)
      values (
        v_source,now(),v_url,v_hash,
        jsonb_build_object(
          'kind','huntanalyser_public_list',
          'page',v_page,
          'html',v_html
        )
      )
      on conflict (source_id,content_hash) do nothing;

      select id into v_snapshot
      from raw_snapshots
      where source_id=v_source and content_hash=v_hash
      limit 1;

      -- Each public card starts with a stable detail URL.
      for v_part in
        select x
        from regexp_split_to_table(
          v_html,
          'data-row-click-url-value="/hunt_sessions/'
        ) with ordinality as p(x,n)
        where n > 1
      loop
        begin
          v_clean := regexp_replace(v_part,E'[\n\r\t]+',' ','g');
          v_clean := regexp_replace(v_clean,'[ ]+',' ','g');

          v_m := regexp_match(v_clean,'^([0-9]+)"');
          if v_m is null then
            continue;
          end if;
          v_external := v_m[1];

          v_m := regexp_match(v_clean,'<h3[^>]*>[[:space:]]*([^<]+)[[:space:]]*</h3>');
          v_hunt := case when v_m is null then null else trim(v_m[1]) end;

          v_m := regexp_match(v_clean,'<p class="truncate">[[:space:]]*([^<]+)[[:space:]]*</p>');
          v_started_raw := case when v_m is null then null else trim(v_m[1]) end;

          v_m := regexp_match(v_clean,'fa-clock"></i>[[:space:]]*<span>([^<]+)</span>');
          v_duration_raw := case when v_m is null then null else trim(v_m[1]) end;

          if v_duration_raw ~ '^[0-9]{2}:[0-9]{2}h$' then
            v_duration_seconds :=
              split_part(v_duration_raw,':',1)::int * 3600 +
              replace(split_part(v_duration_raw,':',2),'h','')::int * 60;
          else
            v_duration_seconds := null;
          end if;

          v_m := regexp_match(v_clean,'<span class="ha-tag[^>]*>[[:space:]]*([^<]+)[[:space:]]*</span>');
          v_party_raw := case when v_m is null then null else trim(v_m[1]) end;
          v_party_size := case
            when lower(v_party_raw)='solo' then 1
            when lower(v_party_raw)='duo' then 2
            when lower(v_party_raw) ~ '^x[0-9]+$' then substring(lower(v_party_raw) from 2)::int
            else null
          end;

          v_m := regexp_match(v_clean,'XP Gain:</div>[[:space:]]*<div class="text-right">([0-9,.-]+)</div>');
          v_xp_gain := case when v_m is null then null else replace(v_m[1],',','')::numeric end;

          v_m := regexp_match(v_clean,'Balance:</div>.*?<span class="ha-text-[^"]+">[[:space:]]*([-0-9,]+)[[:space:]]*</span>');
          v_balance := case when v_m is null then null else replace(v_m[1],',','')::numeric end;

          v_m := regexp_match(v_clean,'XP/h:</div>[[:space:]]*<div class="text-right">([0-9,.-]+)</div>');
          v_xph := case when v_m is null then null else replace(v_m[1],',','')::numeric end;

          v_m := regexp_match(v_clean,'Raw XP/h:</div>[[:space:]]*<div class="text-right">([0-9,.-]+)</div>');
          v_raw_xph := case when v_m is null then null else replace(v_m[1],',','')::numeric end;

          v_m := regexp_match(v_clean,'whitespace-nowrap">by ([^<]+)</span>');
          v_author := case when v_m is null then null else trim(v_m[1]) end;

          v_m := regexp_match(
            v_clean,
            '<span class="min-w-0[^"]*"[^>]*title="([^"]*)">'
          );
          v_description := case when v_m is null then null else v_m[1] end;

          select id into v_session_id
          from community_sessions
          where source_id=v_source and external_id=v_external
          limit 1;

          if v_session_id is null then
            insert into community_sessions(
              source_id,snapshot_id,external_id,source_url,
              hunt_name_raw,hunt_resolution_status,
              session_started_at_raw,observed_at,duration_seconds,party_size,
              xp_gain,xp_per_hour,raw_xp_per_hour,balance_value,
              author_raw,description_raw,raw_payload
            )
            values (
              v_source,v_snapshot,v_external,
              'https://www.hunt-analyser.com/hunt_sessions/'||v_external,
              v_hunt,'unresolved',
              v_started_raw,now(),v_duration_seconds,v_party_size,
              v_xp_gain,v_xph,v_raw_xph,v_balance,
              v_author,v_description,
              jsonb_build_object(
                'stage','public_list',
                'page',v_page,
                'party_label',v_party_raw
              )
            )
            returning id into v_session_id;
            v_inserted := v_inserted + 1;
          else
            update community_sessions
            set snapshot_id=v_snapshot,
                source_url='https://www.hunt-analyser.com/hunt_sessions/'||v_external,
                hunt_name_raw=v_hunt,
                session_started_at_raw=v_started_raw,
                observed_at=now(),
                duration_seconds=v_duration_seconds,
                party_size=v_party_size,
                xp_gain=v_xp_gain,
                xp_per_hour=v_xph,
                raw_xp_per_hour=v_raw_xph,
                balance_value=v_balance,
                author_raw=v_author,
                description_raw=v_description,
                raw_payload=coalesce(raw_payload,'{}'::jsonb) ||
                  jsonb_build_object('stage','public_list','page',v_page,'party_label',v_party_raw)
            where id=v_session_id;
            v_updated := v_updated + 1;
          end if;

          delete from session_players
          where session_id=v_session_id
            and metadata->>'source_stage'='public_list';

          for v_player in
            select m
            from regexp_matches(
              v_clean,
              '<span class="font-semibold">(EK|RP|ED|MS|EM)</span>[[:space:]]*<span class="font-mono[^>]*>([0-9]+)</span>',
              'g'
            ) m
          loop
            insert into session_players(session_id,vocation,level,metadata)
            values (
              v_session_id,
              v_player[1],
              v_player[2]::int,
              jsonb_build_object('source_stage','public_list')
            );
            v_players := v_players + 1;
          end loop;

        exception when others then
          v_errors := v_errors + 1;
        end;
      end loop;

      v_pages_done := v_pages_done + 1;
      perform pg_sleep(0.75);

    exception when others then
      v_errors := v_errors + 1;
      exit;
    end;
  end loop;

  return jsonb_build_object(
    'pages_completed',v_pages_done,
    'sessions_inserted',v_inserted,
    'sessions_updated',v_updated,
    'player_rows_written',v_players,
    'errors',v_errors,
    'source_status','review',
    'terms_review_status',(
      select terms_review_status from sources where id=v_source
    ),
    'note','Public list-page smoke ingestion only. Detail pages and scale-up require separate validation.'
  );
end;
$$;

revoke all on function huntnexus_ingest_huntanalyser_public_pages(integer)
  from public,anon,authenticated;
grant execute on function huntnexus_ingest_huntanalyser_public_pages(integer)
  to service_role;
