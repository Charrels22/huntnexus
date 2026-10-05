-- HuntNexus Brain — Phase 6.1 RubinOT changelog reconciliation queue.
-- These rows are qualitative change candidates, NOT applied overrides.
-- Exact numeric/state overrides must only be written when the official source
-- exposes an unambiguous value.

create table if not exists rubinot_change_candidates (
  id uuid primary key default gen_random_uuid(),
  patch_version text not null,
  released_on date,
  entity_type text not null,
  entity_key text,
  change_kind text not null,
  summary text not null,
  source_id uuid not null references sources(id),
  source_url text not null,
  observed_at timestamptz not null default now(),
  reconciliation_status text not null default 'pending'
    check (reconciliation_status in ('pending','resolved','not_applicable','needs_exact_value')),
  resolved_override_id uuid references rubinot_overrides(id),
  notes text,
  unique (patch_version,entity_type,entity_key,change_kind,summary)
);

create index if not exists idx_rubinot_change_candidates_pending
  on rubinot_change_candidates(reconciliation_status,patch_version);

insert into rubinot_change_candidates(
  patch_version,released_on,entity_type,entity_key,change_kind,summary,
  source_id,source_url,reconciliation_status,notes
)
select x.patch_version,x.released_on::date,x.entity_type,x.entity_key,x.change_kind,x.summary,
       s.id,'https://rubinot.com.br/changelog',x.status,x.notes
from sources s
cross join (
  values
    ('v13.8','2026-09-29','creature',null,'behavior',
      'Monster chase-distance behavior changed to match global behavior.',
      'needs_exact_value','Qualitative global behavior change; do not convert into numeric distance without an exact official value.'),
    ('v13.8','2026-09-29','creature',null,'spawn_behavior',
      'Monster return-to-spawn behavior was corrected.',
      'pending','Behavioral correction; may affect pathing/session observations but is not a numeric override.'),
    ('v13.8','2026-09-29','boss','magma-bubble','mechanics',
      'Magma Bubble fight mechanics were reworked.',
      'pending','Requires boss-specific reconciliation before any recommendation logic uses old mechanics.'),
    ('v13.7','2026-09-22','boss_group','soul-war','mechanics',
      'Soul War boss fight mechanics were reworked.',
      'pending','Treat old boss guides as version-sensitive.'),
    ('v13.6','2026-09-15','item','biscuit-barrier','item_effects',
      'Biscuit Barrier description was corrected to show its current effects.',
      'needs_exact_value','Compare RubinOT in-game/current official values with Tibia base before creating item overrides.'),
    ('v13.6','2026-09-15','item','phantasmal-axe','attack_property',
      'Phantasmal Axe attack-property description was adjusted.',
      'needs_exact_value','Exact RubinOT attack property must be resolved before applying an override.'),
    ('v13.5','2026-09-10','creature','bloodjaw','spell_frequency',
      'Bloodjaw spell frequency was reduced.',
      'needs_exact_value','Direction is known; exact frequency is not exposed in the changelog summary.'),
    ('v13.4','2026-09-08','creature','spit-nettle','behavior',
      'Spit Nettle behavior was revised.',
      'pending','Qualitative behavior change.'),
    ('v13.4','2026-09-08','hunt','book-world','loot',
      'Book World monster loot received multiple improvements.',
      'needs_exact_value','Summary says four loot changes follow, but collapsed page does not expose exact values.')
) as x(patch_version,released_on,entity_type,entity_key,change_kind,summary,status,notes)
where s.name='RubinOT Changelog'
on conflict do nothing;
