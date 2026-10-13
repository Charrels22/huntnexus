import assert from "node:assert/strict";
import { imbuementPotency, observedDamageShare, observedProfileCount } from "../web/app/src/lib/imbuement-evidence.ts";
for (const value of [null, undefined, "", NaN, Infinity, -1, true, {}]) {
  assert.equal(imbuementPotency(value, "percent"), "Não informado");
  assert.equal(observedDamageShare(value), "Não informado");
}
assert.equal(imbuementPotency(0, "percent"), "0%");
assert.equal(imbuementPotency("15", "percent"), "15%");
assert.equal(imbuementPotency(15, undefined), "15 · unidade não informada");
assert.equal(observedDamageShare(.339324), "33,9%");
assert.equal(observedDamageShare(.681796), "68,2%");
assert.equal(observedDamageShare(2), "Não informado");
assert.equal(observedProfileCount(0), "0");
assert.equal(observedProfileCount(1.5), "Não informado");
console.log("PASS FE-43: absent vs zero, unit and distinct damage denominators");
