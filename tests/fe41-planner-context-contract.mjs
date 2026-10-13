import assert from "node:assert/strict";
import { parsePlannerContext } from "../web/app/src/lib/planner-context.ts";
for (const vocation of ["EK", "RP", "ED", "MS", "EM"]) {
  assert.deepEqual(parsePlannerContext({ vocation, level: "500", party: "4", setObjective: "sustain", huntObjective: "profit", client_id: "SYNTHETIC-never-carried" }), { vocation, level: 500, party: 4, setObjective: "sustain", huntObjective: "profit" });
}
assert.deepEqual(parsePlannerContext({ vocation: "invalid", level: -1, party: 0, setObjective: "invalid", huntObjective: "invalid" }), {});
assert.deepEqual(parsePlannerContext({ level: Infinity, party: 1.5 }), {});
assert.deepEqual(parsePlannerContext({ level: 5001 }), {});
assert.deepEqual(parsePlannerContext({ level: "", party: "" }), {});
console.log("PASS FE-41: validated public context, five vocations, invalid values and private IDs excluded");
