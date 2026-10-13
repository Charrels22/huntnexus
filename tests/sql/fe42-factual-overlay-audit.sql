-- FE-42: public factual metadata only. Read-only; no private session tables or writes.
with audit as (select public.huntnexus_hunt_catalog_readiness_audit() as j),
entries as (select jsonb_array_elements(j->'entries') as e from audit),
candidates as (
  select c.patch_version,c.entity_type,c.entity_key,c.change_kind,c.reconciliation_status,
    c.source_url,c.observed_at,s.name as source_name,s.tier,s.layer
  from public.rubinot_change_candidates c join public.sources s on s.id=c.source_id
)
select jsonb_build_object(
 'observed_at',now(),
 'summary',(select j->'summary' from audit),
 'invariants',jsonb_build_object(
   'eligible_core_complete',not exists(select 1 from entries where (e->>'planner_eligible')::boolean and not (e->>'source_core_complete')::boolean),
   'hunt_provenance_present',not exists(select 1 from public.tibia_hunting_places h left join public.sources s on s.id=h.source_id where s.id is null or s.url is null or h.source_last_updated is null or h.snapshot_id is null),
   'override_provenance_present',not exists(select 1 from public.rubinot_overrides o left join public.sources s on s.id=o.source_id where s.id is null or s.tier::text<>'A' or s.layer::text<>'rubinot_overlay' or s.url is null or o.patch_version is null or o.observed_at is null),
   'candidate_provenance_present',not exists(select 1 from candidates where source_url is null or observed_at is null or tier::text<>'A' or layer::text<>'rubinot_overlay'),
   'override_intervals_do_not_overlap',not exists(select 1 from public.rubinot_overrides a join public.rubinot_overrides b on a.id<b.id and a.entity_type=b.entity_type and a.entity_key=b.entity_key and a.field=b.field and tstzrange(a.valid_from,a.valid_to,'[)') && tstzrange(b.valid_from,b.valid_to,'[)'))
 ),
 'exceptions',(select jsonb_agg(e) from entries where e->>'readiness_status'<>'source_core_complete'),
 'optional_missing',(select jsonb_object_agg(field,n) from (select field,count(*) n from entries cross join lateral jsonb_array_elements_text(e->'optional_source_fields_missing') field group by field) t),
 'sources',(select jsonb_agg(row_to_json(t)) from (select s.name,s.tier,s.layer,s.url,count(*) hunts,min(h.source_last_updated) oldest_recorded,max(h.source_last_updated) newest_recorded from public.tibia_hunting_places h join public.sources s on s.id=h.source_id group by s.name,s.tier,s.layer,s.url) t),
 'override_versions',(select count(*) from public.rubinot_overrides),
 'active_overrides',(select count(*) from public.rubinot_overrides where valid_from<=now() and (valid_to is null or valid_to>now())),
 'candidates',coalesce((select jsonb_agg(row_to_json(candidates) order by patch_version,entity_type,entity_key) from candidates),'[]'::jsonb)
) as audit;
