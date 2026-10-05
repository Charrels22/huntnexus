-- HuntNexus Brain — Phase 5 equipment effect normalization.
-- Derived only from already-ingested Tier B item details. No remote requests.

create table if not exists item_effects (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references tibia_items(id) on delete cascade,
  effect_type text not null,
  effect_key text not null,
  numeric_value numeric,
  unit text,
  context jsonb not null default '{}'::jsonb,
  raw_value text not null,
  source_field text not null,
  source_id uuid not null references sources(id),
  snapshot_id uuid references raw_snapshots(id),
  observed_at timestamptz not null default now(),
  unique (item_id, effect_type, effect_key, source_field, raw_value)
);

create index if not exists idx_item_effects_item on item_effects(item_id);
create index if not exists idx_item_effects_type_key on item_effects(effect_type,effect_key);

create table if not exists item_effect_parse_issues (
  item_id uuid not null references tibia_items(id) on delete cascade,
  source_field text not null,
  raw_token text not null,
  reason text not null,
  observed_at timestamptz not null default now(),
  primary key (item_id, source_field, raw_token)
);

create or replace function huntnexus_rebuild_item_effects()
returns jsonb
language plpgsql
as $$
declare
  v_source uuid;
  v_inserted int := 0;
  v_issues int := 0;
begin
  select id into strict v_source
  from sources
  where name='ByteWizards TibiaData';

  delete from item_effects
  where item_id in (select item_id from item_detail_state where status='completed');

  delete from item_effect_parse_issues
  where item_id in (select item_id from item_detail_state where status='completed');

  -- Elemental/physical protection. Prefer resistPercent when present; it is
  -- source-equivalent to resist on overlapping records and avoids duplicates.
  with values_by_item as (
    select
      i.id as item_id,
      i.snapshot_id,
      coalesce(
        max(a.attribute_value) filter (where a.attribute_key='resistPercent'),
        max(a.attribute_value) filter (where a.attribute_key='resist')
      ) as raw_resist,
      case
        when max(a.attribute_value) filter (where a.attribute_key='resistPercent') is not null
          then 'resistPercent'
        else 'resist'
      end as source_field
    from tibia_items i
    join item_detail_state s on s.item_id=i.id and s.status='completed'
    left join item_attribute_entries a
      on a.item_id=i.id and a.attribute_key in ('resist','resistPercent')
    group by i.id,i.snapshot_id
  ),
  tokens as (
    select item_id,snapshot_id,source_field,trim(tok) as token
    from values_by_item,
         lateral regexp_split_to_table(coalesce(raw_resist,''), '\s*,\s*') tok
    where nullif(trim(tok),'') is not null
  ),
  parsed as (
    select
      item_id,snapshot_id,source_field,token,
      regexp_match(
        lower(token),
        '^([a-z ]+)[[:space:]]+([+-]?[0-9.]+)%$'
      ) as m
    from tokens
  )
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    item_id,
    'protection',
    replace(trim(m[1]),' ','_'),
    m[2]::numeric,
    'percent',
    '{}'::jsonb,
    token,
    source_field,
    v_source,
    snapshot_id,
    now()
  from parsed
  where m is not null
    and trim(m[1]) in (
      'physical','earth','fire','energy','ice','death','holy','life drain','mana drain'
    );

  get diagnostics v_inserted = row_count;

  -- Simple numeric attrib tokens: skills, magic schools, speed and shielding.
  with tokens as (
    select
      i.id as item_id,
      i.snapshot_id,
      trim(tok) as token
    from tibia_items i
    join item_detail_state s on s.item_id=i.id and s.status='completed',
         lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
    where nullif(trim(tok),'') is not null
  ),
  parsed as (
    select
      item_id,snapshot_id,token,
      regexp_match(
        lower(token),
        '^(magic level|distance fighting|fist fighting|sword fighting|axe fighting|club fighting|shielding|speed|fire magic level|energy magic level|earth magic level|ice magic level|holy magic level|death magic level|healing magic level)[[:space:]]+([+-]?[0-9.]+)$'
      ) as m
    from tokens
  )
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    item_id,
    case
      when m[1]='speed' then 'movement'
      when m[1] like '%magic level' or m[1]='magic level' then 'magic_skill'
      else 'skill'
    end,
    replace(m[1],' ','_'),
    m[2]::numeric,
    case when m[1]='speed' then 'speed_points' else 'levels' end,
    '{}'::jsonb,
    token,
    'attrib',
    v_source,
    snapshot_id,
    now()
  from parsed
  where m is not null;

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Life leech.
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    i.id,'leech','life_leech',
    ((regexp_match(lower(tok),'^life leech[[:space:]]+([+-]?[0-9.]+)%$'))[1])::numeric,
    'percent','{}'::jsonb,trim(tok),'attrib',v_source,i.snapshot_id,now()
  from tibia_items i
  join item_detail_state s on s.item_id=i.id and s.status='completed',
       lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
  where lower(trim(tok)) ~ '^life leech[[:space:]]+[+-]?[0-9.]+%$';

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Cleave.
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    i.id,'offense','cleave',
    ((regexp_match(lower(tok),'^cleave[[:space:]]+([0-9.]+)%$'))[1])::numeric,
    'percent','{}'::jsonb,trim(tok),'attrib',v_source,i.snapshot_id,now()
  from tibia_items i
  join item_detail_state s on s.item_id=i.id and s.status='completed',
       lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
  where lower(trim(tok)) ~ '^cleave[[:space:]]+[0-9.]+%$';

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Damage reflection.
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    i.id,'defense','damage_reflection',
    ((regexp_match(lower(tok),'^([0-9.]+)[[:space:]]+damage reflection$'))[1])::numeric,
    'damage','{}'::jsonb,trim(tok),'attrib',v_source,i.snapshot_id,now()
  from tibia_items i
  join item_detail_state s on s.item_id=i.id and s.status='completed',
       lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
  where lower(trim(tok)) ~ '^[0-9.]+[[:space:]]+damage reflection$';

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Perfect shot: bonus with required range kept in context.
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    i.id,'offense','perfect_shot',
    ((regexp_match(lower(tok),'^perfect shot[[:space:]]+([+-]?[0-9.]+)[[:space:]]+at range[[:space:]]+([0-9.]+)$'))[1])::numeric,
    'damage',
    jsonb_build_object(
      'range',
      ((regexp_match(lower(tok),'^perfect shot[[:space:]]+([+-]?[0-9.]+)[[:space:]]+at range[[:space:]]+([0-9.]+)$'))[2])::numeric
    ),
    trim(tok),'attrib',v_source,i.snapshot_id,now()
  from tibia_items i
  join item_detail_state s on s.item_id=i.id and s.status='completed',
       lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
  where lower(trim(tok)) ~ '^perfect shot[[:space:]]+[+-]?[0-9.]+[[:space:]]+at range[[:space:]]+[0-9.]+$';

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Magic shield capacity: one raw token creates flat + percent effects.
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    i.id,'defense','magic_shield_capacity_flat',
    ((regexp_match(lower(tok),'^magic shield capacity[[:space:]]+([+-]?[0-9.]+)[[:space:]]+and[[:space:]]+([0-9.]+)%$'))[1])::numeric,
    'capacity','{}'::jsonb,trim(tok),'attrib',v_source,i.snapshot_id,now()
  from tibia_items i
  join item_detail_state s on s.item_id=i.id and s.status='completed',
       lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
  where lower(trim(tok)) ~ '^magic shield capacity[[:space:]]+[+-]?[0-9.]+[[:space:]]+and[[:space:]]+[0-9.]+%$';

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    i.id,'defense','magic_shield_capacity_percent',
    ((regexp_match(lower(tok),'^magic shield capacity[[:space:]]+([+-]?[0-9.]+)[[:space:]]+and[[:space:]]+([0-9.]+)%$'))[2])::numeric,
    'percent','{}'::jsonb,trim(tok),'attrib',v_source,i.snapshot_id,now()
  from tibia_items i
  join item_detail_state s on s.item_id=i.id and s.status='completed',
       lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
  where lower(trim(tok)) ~ '^magic shield capacity[[:space:]]+[+-]?[0-9.]+[[:space:]]+and[[:space:]]+[0-9.]+%$';

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Boolean/special attrib effects.
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    i.id,'special',
    replace(lower(trim(tok)),' ','_'),
    1,'boolean','{}'::jsonb,trim(tok),'attrib',v_source,i.snapshot_id,now()
  from tibia_items i
  join item_detail_state s on s.item_id=i.id and s.status='completed',
       lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
  where lower(trim(tok)) in ('faster regeneration','magic shield','invisibility','hard drinking');

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Structured additional attributes with direct numeric semantics.
  insert into item_effects(
    item_id,effect_type,effect_key,numeric_value,unit,context,
    raw_value,source_field,source_id,snapshot_id,observed_at
  )
  select
    a.item_id,
    case
      when a.attribute_key in ('criticalHitChance','criticalExtraDamage','attackModifier','hitModifier')
        then 'offense'
      else 'special'
    end,
    case a.attribute_key
      when 'criticalHitChance' then 'critical_hit_chance'
      when 'criticalExtraDamage' then 'critical_extra_damage'
      when 'attackModifier' then 'attack_modifier'
      when 'hitModifier' then 'hit_modifier'
      when 'charges' then 'charges'
      when 'duration' then 'duration'
      else lower(a.attribute_key)
    end,
    case
      when a.attribute_key in ('criticalHitChance','criticalExtraDamage')
        then nullif(regexp_replace(a.attribute_value,'[^0-9.+-]','','g'),'')::numeric
      when a.attribute_key in ('attackModifier','hitModifier','charges')
        then nullif(regexp_replace(a.attribute_value,'[^0-9.+-]','','g'),'')::numeric
      else null
    end,
    case
      when a.attribute_key in ('criticalHitChance','criticalExtraDamage') then 'percent'
      when a.attribute_key in ('attackModifier','hitModifier') then 'points'
      when a.attribute_key='charges' then 'charges'
      else 'text'
    end,
    '{}'::jsonb,
    a.attribute_value,
    a.attribute_key,
    v_source,
    i.snapshot_id,
    now()
  from item_attribute_entries a
  join tibia_items i on i.id=a.item_id
  join item_detail_state s on s.item_id=i.id and s.status='completed'
  where a.attribute_key in (
    'criticalHitChance','criticalExtraDamage','attackModifier','hitModifier','charges','duration'
  );

  get diagnostics v_issues = row_count;
  v_inserted := v_inserted + v_issues;

  -- Record attrib tokens that did not match any normalized effect.
  with tokens as (
    select i.id as item_id,trim(tok) as token
    from tibia_items i
    join item_detail_state s on s.item_id=i.id and s.status='completed',
         lateral regexp_split_to_table(coalesce(i.attrib,''), '\s*,\s*') tok
    where nullif(trim(tok),'') is not null
  )
  insert into item_effect_parse_issues(item_id,source_field,raw_token,reason,observed_at)
  select t.item_id,'attrib',t.token,'unrecognized attrib token',now()
  from tokens t
  where not exists (
    select 1
    from item_effects e
    where e.item_id=t.item_id
      and e.source_field='attrib'
      and lower(e.raw_value)=lower(t.token)
  )
  on conflict do nothing;

  return jsonb_build_object(
    'effects',(select count(*) from item_effects),
    'items_with_effects',(select count(distinct item_id) from item_effects),
    'parse_issues',(select count(*) from item_effect_parse_issues),
    'issue_items',(select count(distinct item_id) from item_effect_parse_issues),
    'by_type',(
      select coalesce(jsonb_object_agg(effect_type,n),'{}'::jsonb)
      from (
        select effect_type,count(*)::int as n
        from item_effects
        group by effect_type
        order by effect_type
      ) x
    )
  );
end;
$$;

revoke all on function huntnexus_rebuild_item_effects()
  from public, anon, authenticated;
grant execute on function huntnexus_rebuild_item_effects()
  to service_role;
