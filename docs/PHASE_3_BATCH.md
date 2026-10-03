# Phase 3 batch execution

To minimize Lovable Free-plan database action usage, Phase 3 has a single orchestration function:

```sql
select huntnexus_phase3_batch(100, 25);
```

A single call:

1. ingests up to 100 pending creature details;
2. ingests up to 25 pending hunting-place details;
3. returns completed/error counts;
4. returns normalized row counts;
5. returns remaining creature/hunt counts.

The underlying ingestion remains sequential and rate-limited. The orchestrator does not bypass remote rate limits or access controls.

Use smaller values if the remote source is slow:

```sql
select huntnexus_phase3_batch(50, 10);
```

Do not run overlapping Phase 3 batches.
