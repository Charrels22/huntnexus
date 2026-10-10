# HuntNexus Owned Equipment Contract v1

## Product rule

The player's **Set Main is the baseline**.

The HuntNexus must not silently replace Main Set pieces with catalog items.

Alternative equipment is split into two explicit pools:

1. **Backpack (owned)** — items the player says they already own and can bring to a hunt.
2. **External suggestions** — contextual candidates from the HuntNexus catalog that are not registered as owned.

## Profile

The Profile stores:

- Main Set: at most one item per loadout selection slot.
- Backpack: any number of owned alternative items.

Current Main Set slots:

- head
- neck
- ring
- weapon
- body
- offhand
- legs
- feet
- ammunition (RP when applicable)

The Backpack is an owned alternative pool, not the Tibia container slot itself.

## Search

Items are searched from `vw_loadout_item_catalog_universal`.

Search:
- checks current vocation and level;
- returns blocked reasons;
- allows blocked items to be recorded in Backpack ownership;
- blocks an ineligible item from becoming the current Main Set through the UI.

No ownership is inferred from the public item catalog.

## Hunt review

`huntnexus_player_inventory_hunt_review()` evaluates the registered inventory against a hunt.

It returns:

- Main Set baseline;
- Backpack alternatives;
- contextual Pareto frontier candidates;
- ownership classification: `main`, `backpack`, or `external`.

Rules:

- `main_set_is_baseline=true`
- `automatic_main_replacement=false`
- Backpack substitution is advisory.
- External candidates are advisory only.
- A Pareto frontier candidate is **not** called a unique winner.
- No cross-metric scalar score is invented.
- Full-set compatibility is not recomputed by the item-level inventory review; universal set validation remains a separate layer.

## UI behavior

Profile:
- visual Main Set grid using canonical Tibia item sprites;
- separate Backpack list;
- catalog search to add/replace items.

Hunt Detail / Setup:
- show Main Set first;
- show owned Backpack alternatives separately;
- highlight Backpack items that reach the contextual item frontier;
- list external frontier candidates separately;
- keep the universal catalog frontier visible as a different layer.

## Weapon Proficiency UI

Weapon trees are collapsed by default.

When opened, perks are displayed as visual selectable nodes.

Current data limitation:
- source order is known;
- declared proficiency level count is known;
- exact node-to-level assignment and branch topology are not known for all weapons.

Therefore HuntNexus does **not** draw invented edges or auto-activate predecessor perks.

Saved selections remain exact:
`item_key -> [perk_order]`.


## Owned build options

`huntnexus_player_owned_build_options()` produces up to three owned-only build options for a hunt.

Policy:

1. Option 1 is always the registered Main Set.
2. Options 2 and 3 may replace up to two Main Set slots with Backpack items.
3. A Backpack item must first reach the contextual item Pareto frontier for that hunt/slot.
4. A complete variant must pass universal loadout compatibility.
5. If the Main Set and a variant have exactly comparable set vectors and the Main Set Pareto-dominates the variant, that variant is discarded.
6. If a Backpack variant exactly dominates the Main Set, it is preferred among owned alternatives.
7. After dominance, fewer replacements are preferred to keep the suggested variation close to the player's actual Main Set.
8. External/non-owned catalog items are never inserted into these owned options.

This is not a scalar ranking and does not claim a unique best set.
