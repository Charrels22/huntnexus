// Canonical TibiaWiki sprite candidates. Filename mapping is distinct from
// successful HTTP retrieval and from RubinOT-specific asset verification.
// Unmapped effects deliberately return []; the UI shows a numeric fallback.
// The newly added file candidates below were verified as loadable 32x32
// spell icons / 16x16 augment icons in headless Chromium on 2026-10-11.
// They remain canonical Tier B references, not RubinOT client confirmation.

export function tibiaWikiFile(filename: string) {
  return `https://www.tibiawiki.com.br/wiki/Special:Redirect/file/${encodeURIComponent(filename).replace(/%20/g, "_")}`;
}

export function proficiencyIconFiles(perk: {effect_key:string;description_raw?:string | null;spell_key?:string | null}) {
  const effectKey = perk.effect_key;
  const exact: Record<string,string[]> = {
    attack: ["Proficiency Type Attack.gif"],
    defense: ["Proficiency Type Defence.gif"],
    defense_modifier: ["Proficiency Type Defence.gif"],
    auto_attack_critical_chance: ["Proficiency Type Auto Atk Critical Chance.gif"],
    auto_attack_critical_extra_damage: ["Proficiency Type Auto Atk Critical Dmg.gif"],
    critical_extra_damage_4: ["Proficiency Type Critical Dmg.gif"],
    critical_extra_damage_8: ["Proficiency Type Critical Dmg.gif"],
    critical_extra_damage_10: ["Proficiency Type Critical Dmg.gif"],
    life_leech: ["Proficiency Type Life Leech.gif"],
    mana_leech: ["Proficiency Type Mana Leech.gif"],
    life_on_hit: ["Proficiency Type Life On Hit.gif"],
    life_on_kill: ["Proficiency Type Life On Kill.gif"],
    mana_on_hit: ["Proficiency Type Mana On Hit.gif"],
    bestiary_damage_reptile: ["Proficiency Type Bestiary Dmg Reptile.gif"],
    bestiary_human_damage: ["Proficiency Type Bestiary Dmg Human.gif"],
    bestiary_damage_inkborn: ["Proficiency Type Bestiary Dmg Inkborn.gif"],
    bestiary_damage_magical: ["Proficiency Type Bestiary Dmg Magical.gif"],
    perfect_shot_damage: ["Proficiency Type Perfect Shot Damage.gif"],
    magic_level_spell_extra_healing_percent: ["Proficiency Type Perc Spell Heal Magic.gif"],
    magic_level_auto_attack_extra_damage_percent: ["Proficiency Type Perc Auto Atk Magic.gif"],
    heal_friend_healing: ["Proficiency Spell Heal Friend.gif","Proficiency Augment Healing.gif"],
    auto_attack_critical_extra_damage_percent: ["Proficiency Type Auto Atk Critical Dmg.gif"],
    earth_magic_level_bonus: ["Proficiency Type Magic Boost Earth.gif"],
    ice_magic_level_bonus: ["Proficiency Type Magic Boost Ice.gif"],
    holy_magic_level_bonus: ["Proficiency Type Magic Boost Holy.gif"],
    healing_magic_level_bonus: ["Proficiency Type Magic Boost Healing.gif"],
    earth_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Earth.gif"],
    ice_spells_runes_critical_chance: ["Proficiency Type Element Critical Chance Ice.gif"],
    ice_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Ice.gif"],
    holy_spell_rune_critical_chance: ["Proficiency Type Element Critical Chance Holy.gif"],
    critical_extra_damage: ["Proficiency Type Critical Dmg.gif"],
    critical_chance: ["Proficiency Type Critical Chance.gif"],
    magic_level_bonus: ["Proficiency Type Skill Magic.gif"],
    mana_on_kill: ["Proficiency Type Mana On Kill.gif"],
    death_magic_level_bonus: ["Proficiency Type Magic Boost Death.gif"],
    energy_magic_level_bonus: ["Proficiency Type Magic Boost Energy.gif"],
    fire_magic_level_bonus: ["Proficiency Type Magic Boost Fire.gif"],
    death_spells_runes_critical_chance: ["Proficiency Type Element Critical Chance Death.gif"],
    death_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Death.gif"],
    energy_spells_runes_critical_chance: ["Proficiency Type Element Critical Chance Energy.gif"],
    energy_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Energy.gif"],
    fire_spells_runes_critical_chance: ["Proficiency Type Element Critical Chance Fire.gif"],
    fire_spells_runes_critical_extra_damage: ["Proficiency Type Element Critical Dmg Fire.gif"],
    offensive_rune_critical_chance: ["Proficiency Type Rune Critical Chance.gif"],
    offensive_rune_critical_extra_damage: ["Proficiency Type Rune Critical Dmg.gif"],
    magic_level_spell_extra_damage_percent: ["Proficiency Type Perc Spell Dmg Magic.gif"],
    bestiary_demon_damage: ["Proficiency Type Bestiary Dmg Demon.gif"],
    bestiary_inkborn_damage: ["Proficiency Type Bestiary Dmg Inkborn.gif"],
    bestiary_magical_damage: ["Proficiency Type Bestiary Dmg Magical.gif"],
    powerful_foe_damage: ["Proficiency Type Powerful Foe Bonus.gif"],
    great_death_beam_critical_chance: ["Proficiency Spell Great Death Beam.gif","Proficiency Augment Critical Chance.gif"],
    great_death_beam_critical_extra_damage: ["Proficiency Spell Great Death Beam.gif","Proficiency Augment Critical Dmg.gif"],
    great_fire_wave_critical_extra_damage: ["Proficiency Spell Great Fire Wave.gif","Proficiency Augment Critical Dmg.gif"],
    energy_wave_base_damage: ["Proficiency Spell Energy Wave.gif","Proficiency Augment Damage.gif"],
    hells_core_base_damage: ["Proficiency Spell Hells Core.gif","Proficiency Augment Damage.gif"],
    hells_core_critical_extra_damage: ["Proficiency Spell Hells Core.gif","Proficiency Augment Critical Dmg.gif"],
    rage_of_the_skies_critical_extra_damage: ["Proficiency Spell Rage of the Skies.gif","Proficiency Augment Critical Dmg.gif"],
    rage_of_the_skies_mana_leech: ["Proficiency Spell Rage of the Skies.gif","Proficiency Augment Mana Leech.gif"],
  };
  if (exact[effectKey]) return exact[effectKey];

  // The generic base_damage effect has different spell contexts. Only the
  // source-backed Soulshredder Executioner's Throw perk uses this spell sprite.
  // Do not apply this icon to unrelated generic damage bonuses.
  if (effectKey === "base_damage" && perk.spell_key === "executioners-throw") {
    return ["Proficiency Spell Executioner's Throw.gif", "Proficiency Augment Damage.gif"];
  }

  const spellAugments: Record<string, string> = {
    base_damage: "Proficiency Augment Damage.gif",
    critical_chance: "Proficiency Augment Critical Chance.gif",
    critical_extra_damage: "Proficiency Augment Critical Dmg.gif",
    life_leech: "Proficiency Augment Life Leech.gif",
    mana_leech: "Proficiency Augment Mana Leech.gif",
  };
  const spells: Record<string, string> = {
    fierce_berserk: "Fierce Berserk",
    divine_caldera: "Divine Caldera",
    chained_penance: "Chained Penance",
    sweeping_takedown: "Sweeping Takedown",
    thousand_fist_blows: "Thousand Fist Blows",
    eternal_winter: "Eternal Winter",
    ice_burst: "Ice Burst",
    strong_ice_wave: "Strong Ice Wave",
    terra_wave: "Terra Wave",
    devastating_knockout: "Devastating Knockout",
  };
  for (const [spellKey, spellLabel] of Object.entries(spells)) {
    if (!effectKey.startsWith(spellKey + "_")) continue;
    const suffix = effectKey.slice(spellKey.length + 1).replace(/_[0-9]+$/, "");
    const augment = spellAugments[suffix];
    if (augment) return [`Proficiency Spell ${spellLabel}.gif`, augment];
  }

  const description = (perk.description_raw || "").toLowerCase();
  const skill: Record<string, string> = {
    sword: "Sword", axe: "Axe", club: "Club", distance: "Distance",
    fist: "Fist", magic: "Magic",
  };
  if (effectKey === "skill_bonus" || effectKey === "skill_spell_extra_damage_percent" ||
      effectKey === "skill_auto_attack_extra_damage_percent") {
    const family = Object.entries(skill).find(([key]) =>
      description.includes(key === "magic" ? "magic level" : key === "distance" ? "distance fighting" : key + " fighting")
    )?.[1];
    if (family) {
      if (effectKey === "skill_bonus") return [`Proficiency Type Skill ${family}.gif`];
      if (effectKey === "skill_spell_extra_damage_percent") return [`Proficiency Type Perc Spell Dmg ${family}.gif`];
      return [`Proficiency Type Perc Auto Atk ${family}.gif`];
    }
  }
  return [];
}

