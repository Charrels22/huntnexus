-- FE-43: bounded read-only existing hand package validation, public catalog only.
with contexts(vocation,hunt_key) as (values
 ('EK','cobra-bastion'),('RP','iksupan-last-stand'),('ED','nimmersatts-breeding-ground'),
 ('MS','podzilla'),('EM','grounds-of-undeath')),
packages as materialized (
 select vocation,hunt_key,public.huntnexus_optimizer_hand_packages_universal(hunt_key,vocation,700,2,20) as j from contexts
)
select vocation,hunt_key,j->'summary' as summary,
 jsonb_array_length(j->'packages') as returned_packages,
 not exists(select 1 from jsonb_array_elements(j->'packages') p where p #>> '{validation,status}' is distinct from 'valid') as all_returned_valid,
 not exists(select 1 from jsonb_array_elements(j->'packages') p where p->>'weapon_hands'='Two' and p->'selection' ? 'offhand' and not(vocation='RP' and p->>'offhand_family'='quiver')) as twohanded_offhand_compatible,
 case when vocation='RP' then not exists(select 1 from jsonb_array_elements(j->'packages') p where not(p->'selection' ? 'ammunition') or not(p->'selection' ? 'offhand')) else true end as rp_ammunition_and_offhand_present
from packages;
