# Boss spell evidence and build preview

Boss spell evidence is intentionally conservative.

It can already determine:
- which attack elements fit the canonical boss vulnerability;
- which spells are single-target versus multi-target;
- healing/support options;
- spells explicitly restricted for lever bosses.

It does **not** infer a room rotation.

The boss build preview checks RubinOT reconciliation guards first. If a boss was officially reworked and current RubinOT mechanics are not yet reconciled, `final_build_available=false`.

This is required for Magma Bubble v13.8 and Soul War v13.7.
