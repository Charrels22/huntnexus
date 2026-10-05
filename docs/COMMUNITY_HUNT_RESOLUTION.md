# Community hunt-name reconciliation

Community titles are not automatically treated as canonical hunting-place names.

Examples of safe automatic matches:
- `Energy Library` → canonical `Energy Library`;
- `Fire Library` → canonical `Fire Library`.

Examples that remain unresolved until explicitly mapped:
- `cobra bastion 4 man`;
- `feru way chill`;
- `Iks Last Stand (Entrance)`;
- custom descriptions embedded in titles.

Resolution order:
1. source-specific explicit aliases;
2. strict normalized exact-name match;
3. unresolved.

There is intentionally no fuzzy matching in automatic ingestion.
