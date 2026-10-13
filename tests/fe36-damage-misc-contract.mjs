// FE-36 parser acceptance using public feature terminology and SYNTHETIC
// extracts, not raw player/RubinOT clipboard exports or community evidence.
// Source for observable fields, optional sections and top-five sources:
// https://www.tibia.com/news/?id=5867&subtopic=newsarchive
// https://www.tibiaqa.com/21950/how-does-the-damage-input-analyser-work
import assert from "node:assert/strict";
import {detectAnalyzerType,parseSessionImport,sessionImportWarningLabel}
  from "../web/app/src/lib/session-parser.ts";

const hunt="Session: 00:30h\nXP Gain: 120,000\nDamage: 800,000";
const cases=[];
const parse=(input="",misc="")=>parseSessionImport({hunt,input,misc});

const totalOnly="Received Damage Total: 12,000\nMax-DPS: 345";
assert.equal(detectAnalyzerType(totalOnly),"input");
const pTotal=parse(totalOnly);
assert.equal(pTotal.damage.incoming_total_damage,12000);
assert.equal(pTotal.damage.incoming_max_dps,345);
assert.equal(pTotal.damage.incoming_by_element.length,0);
assert.equal(pTotal.damage.incoming_by_source.length,0);
assert.equal(pTotal.availability.damage,true);
assert.equal(pTotal.hunt_analyse.total_damage,800000,
 "Incoming Total is not outgoing Hunt Analyzer Damage");
assert.ok(pTotal.validation.warnings.includes("input_breakdown_not_observed"));
assert.ok(!pTotal.validation.warnings.includes("input_block_present_but_no_damage_rows_recognized"));
cases.push("source_disabled_sections_total_kept_separately");

const inputWithBreakdown=[
 "Total: 1,164,196","Max-DPS: 2,276","Damage Types:",
 "Fire: 344,853 (29.6%)","Physical: 323,887 (27.8%)",
 "Life Drain: 278,477 (23.9%)","Holy: 114,403 (9.8%)",
 "Energy: 102,576 (8.8%)","Damage Sources:",
 "gazer spectre: 846,907 (72.7%)",
 "thanatursus: 316,431 (27.2%)","(other): 858 (0.1%)",
].join("\n");
assert.equal(detectAnalyzerType(inputWithBreakdown),"input");
const pFull=parse(inputWithBreakdown);
assert.equal(pFull.damage.incoming_total_damage,1164196);
assert.equal(pFull.damage.incoming_max_dps,2276);
assert.equal(pFull.damage.incoming_by_element.length,5);
assert.equal(pFull.damage.incoming_by_source.length,3);
assert.equal(pFull.damage.incoming_by_element[2].element,"life_drain");
assert.equal(pFull.damage.incoming_by_element[0].share_percent,29.6);
assert.equal(pFull.damage.incoming_by_source[2].damage,858);
assert.equal(pFull.validation.input_unrecognized_element_labels,0);
assert.equal(pFull.validation.input_unrecognized_numeric_rows,0);
cases.push("published_fields_numeric_transcription_not_original_clipboard");

const mislabelled=parse(
 "Total: 1,000\nDamage Types:\ngazer spectre: 300 (30%)\n" +
 "Fire: 700 (70%)\nDamage Sources:\ngazer spectre: 1,000"
);
assert.deepEqual(mislabelled.damage.incoming_by_element.map(x=>x.element),["fire"]);
assert.equal(mislabelled.damage.incoming_by_source.length,1);
assert.equal(mislabelled.validation.input_unrecognized_element_labels,1);
assert.ok(mislabelled.validation.warnings.includes("input_element_labels_unrecognized"));
assert.ok(!JSON.stringify(mislabelled.damage.incoming_by_element).includes("gazer"));
cases.push("unknown_labels_never_fabricated_as_elements");

const invalid=parse("Total: 12kk\nMax-DPS: -5\nDamage Types:\nFire: -500 (50%)\nIce: 100 (190%)");
assert.equal(invalid.damage.incoming_total_damage,null);
assert.equal(invalid.damage.incoming_max_dps,null);
assert.equal(invalid.damage.incoming_by_element.length,1);
assert.equal(invalid.damage.incoming_by_element[0].element,"ice");
assert.equal(invalid.damage.incoming_by_element[0].share_percent,null);
assert.ok(invalid.validation.warnings.includes("input_numeric_rows_unrecognized"));
assert.ok(invalid.validation.warnings.includes("input_percentage_invalid"));
cases.push("invalid_damage_amounts_and_percentage_not_guessed");

const misc="Session: 00:30h\nCritical Hit: 393\nMana Gain: 1,234\nLife Gain: 2,345\nUnobserved Stat: N/A";
const m=parse("",misc);
assert.equal(detectAnalyzerType(misc),"misc");
assert.equal(m.misc.combat_stats.length,5);
assert.equal(m.misc.combat_stats.find(x=>x.stat_key==="critical_hit").numeric_value,393);
assert.equal(m.misc.combat_stats.find(x=>x.stat_key==="mana_gain").numeric_value,1234);
assert.equal(m.misc.combat_stats.find(x=>x.stat_key==="life_gain").numeric_value,2345);
assert.equal(m.misc.combat_stats.find(x=>x.stat_key==="unobserved_stat").numeric_value,null);
assert.equal(m.misc.combat_stats.find(x=>x.stat_key==="unobserved_stat").raw_value,"N/A");
assert.equal(m.damage.charm_damage_status,"not_observed");
cases.push("misc_combat_stats_preserve_numeric_and_raw_values");

const empty=parse("","Miscellaneous\nCombat Stats");
assert.equal(empty.misc.combat_stats.length,0);
assert.ok(empty.validation.warnings.includes("misc_block_present_but_no_combat_stats_recognized"));
assert.equal(empty.availability.misc,false);
cases.push("unrecognized_misc_marked_instead_of_silent_success");

const absent=parse();
assert.equal(absent.damage.incoming_total_damage,null);
assert.equal(absent.damage.incoming_by_source.length,0);
assert.equal(absent.misc.combat_stats.length,0);
assert.equal(absent.validation.input_unrecognized_element_labels,0);
assert.equal(absent.validation.input_unrecognized_numeric_rows,0);
assert.ok(!absent.validation.warnings.includes("input_breakdown_not_observed"));
assert.ok(sessionImportWarningLabel("input_breakdown_not_observed").includes("ocultos"));
cases.push("missing_blocks_are_unobserved_not_zero");

console.log(JSON.stringify({
 status:"ok",stage:"fe36_damage_input_misc_contract",
 sourced_feature_names:true,original_raw_rubinot_exports_used:false,
 cases,read_only:true,community_evidence_written:false,
},null,2));
