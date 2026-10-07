-- HuntNexus Brain — Phase 22 ingestion performance indexes.

create index if not exists idx_tibia_entities_creature_external_id
  on tibia_entities (((attributes->>'id')::int))
  where entity_type='creature'
    and nullif(attributes->>'id','') is not null;

create index if not exists idx_tibia_entities_creature_lower_name
  on tibia_entities (lower(name))
  where entity_type='creature';

create index if not exists idx_tibia_hunting_places_external_id
  on tibia_hunting_places(external_id)
  where external_id is not null;

create index if not exists idx_tibia_items_external_id
  on tibia_items(external_id)
  where external_id is not null;

create index if not exists idx_async_detail_jobs_request
  on huntnexus_async_detail_jobs(kind,status,request_id);
