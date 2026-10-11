import assert from "node:assert/strict";
import { proficiencyIconFiles, tibiaWikiFile } from "../web/app/src/lib/proficiency-icons.ts";

const endpoint = process.env.HUNTNEXUS_ENDPOINT ??
  "https://huntnexus.charr3ls22.workers.dev/api/huntnexus";
const families = [
  ["EK", "sword"], ["EK", "axe"], ["EK", "club"],
  ["RP", "bow"], ["RP", "crossbow"],
  ["ED", "rod"], ["MS", "wand"], ["EM", "fist"],
];
const output = [];
for (const [vocation, weapon_family] of families) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      action: "player_profile_proficiency_catalog",
      vocation, weapon_family, level: 700,
    }),
    signal: AbortSignal.timeout(25000),
  });
  const result = await response.json().catch(() => ({}));
  assert.ok(response.ok, vocation + "/" + weapon_family + ": HTTP " + response.status);
  const trees = result?.data?.trees?.filter((tree) => tree.eligible) ?? [];
  assert.ok(trees.length >= 1, vocation + "/" + weapon_family + ": no eligible trees");
  const candidates = trees.flatMap((tree) => (tree.perks ?? []).map((perk) => ({
    ...perk, weapon_key: tree.item_key,
  })));
  assert.ok(candidates.length >= 1, vocation + "/" + weapon_family + ": no perks");
  const mapped = candidates.filter((perk) => proficiencyIconFiles(perk).length);
  const unmapped = candidates.filter((perk) => proficiencyIconFiles(perk).length === 0);
  for (const perk of mapped) {
    for (const file of proficiencyIconFiles(perk)) {
      assert.match(file, /^Proficiency [A-Za-z0-9 .'-]+\.gif$/,
        vocation + ": icon filename must be an explicitly mapped source candidate");
      assert.ok(tibiaWikiFile(file).startsWith("https://www.tibiawiki.com.br/wiki/Special:Redirect/file/"),
        vocation + ": sprite origin unexpectedly changed");
    }
  }
  output.push({
    vocation, weapon_family,
    eligible_tree_count: trees.length,
    total_perks: candidates.length,
    mapped_perks: mapped.length,
    unmapped_perks: unmapped.length,
    mapping_coverage_percent: Number((mapped.length / candidates.length * 100).toFixed(1)),
    unmapped_effects: [...new Set(unmapped.map((perk) => perk.effect_key))].sort(),
  });
}
const total = output.reduce((a, x) => ({
  trees: a.trees + x.eligible_tree_count,
  perks: a.perks + x.total_perks,
  mapped: a.mapped + x.mapped_perks,
  unmapped: a.unmapped + x.unmapped_perks,
}), { trees: 0, perks: 0, mapped: 0, unmapped: 0 });
assert.ok(total.trees >= 30, "Cross-vocation catalog unexpectedly lost eligible weapon trees");
assert.equal(total.perks, total.mapped + total.unmapped);
console.log(JSON.stringify({
  status: "ok", stage: "real_proficiency_catalog_mapping_coverage_v1",
  source: "deployed_HuntNexus_catalog_plus_versioned_local_icon_mapper",
  scope: "all_eligible_trees_at_level_700",
  visual_file_loaded_verified_separately: true,
  every_sprite_verified_in_game: false,
  total, coverage_percent: Number((100 * total.mapped / total.perks).toFixed(1)),
  results: output,
}, null, 2));
