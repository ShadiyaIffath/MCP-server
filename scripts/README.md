# 3-sided diff end-to-end scenario

Emulates: a colleague pushed schema changes upstream, and you've already made
local drift on your `dev` DB. `create_diff_development` should then produce
both **After-pull** (colleague's pull) and **Before-pull** (your local drift)
categories, and `update_development` should route them through the correct
artifacts.

Change ID prefixes come from `DiffChangeReference`:

- `B/<id>` — before-pull. Routes the deploy through the `snapshot_target`
  artifact (snapshot → dev leg).
- `A/<id>` — after-pull. Routes the deploy through the `source_target`
  artifact (schemaModel → dev leg).

## Current state

If you're reading this because Claude just set the scenario up for you:
- `dev` DB is at the schema-model baseline **plus** the local drift
  (`Customer.LoyaltyPoints` added, `Newsletter.Title` widened to `nvarchar(200)`).
  `Newsletter` is intentionally FK-free so 5a can deploy it in isolation
  without Flyway pulling related tables in as dependencies.
- Schema-model files on disk are at the **pre-pull** state (no `NickName`,
  no `CustomerPreference`, `OldFeature` still present) — so the snapshot you're
  about to take is correct.
- `Customers.OldFeature` exists in both schema-model and dev at the pre-pull
  baseline. The pull removes it from schema-model — that's the `Delete new`
  category (pull-leg delete, drift leg untouched), and the decisive object
  for the 5d wildcard test.
- `Customers.SunsetFeature` exists in the pre-pull schema-model baseline and
  is created + immediately dropped in `00_setup_dev.sql` (so dev doesn't have
  it at reset). The pull also removes it from schema-model. Snapshot has it,
  post-pull schema-model doesn't, dev doesn't → both legs agree it's gone →
  `Add missing` category. Covers the MISSING branch. Nothing needs reconciling,
  but `ThreeSidedDiffResult.missing()` still exposes a `beforePullId`, so
  applying `B/<SunsetFeature>` would restore the object on dev from the
  snapshot — useful if you decide the mutual removal was wrong.
- The post-pull schema-model files are staged under `scripts/pull/`; the
  pull also deletes `Customers.OldFeature.sql` from `schema-model/Tables/`.

## Walkthrough

### 1. Start the MCP server and load the project

Whatever your usual MCP invocation is. Then:

```
load_project { path: "C:/Users/shadiya.iffath/Documents/FlywayDesktopSamples/MCP" }
```
Save the returned `workspaceId`.

### 2. Take the before-pull snapshot

```
create_before_pull_snapshot { workspaceId }
```
Save the returned `beforeSnapshotId`. The snapshot freezes schema-model as it
is *right now* (pre-pull).

### 3. Simulate the pull — **do not skip**

Outside the MCP server:

```
python scripts/apply_pull_edits.py
```

This copies `scripts/pull/Customers.Customer.sql` and
`scripts/pull/Customers.CustomerPreference.sql` into `schema-model/Tables/`,
switching schema-model into the post-pull state.

If you skip this step, the "snapshot → schemaModel" leg of the 3-sided diff is
empty and every drift entry is classified as `A/*` instead of `B/*` — which
is exactly the failure mode that looks like the tool isn't working.

Verify before continuing:

```
grep NickName schema-model/Tables/Customers.Customer.sql
ls schema-model/Tables/Customers.CustomerPreference.sql
```
Both should succeed.

### 4. Create the 3-sided diff

```
create_diff_development { workspaceId, beforeSnapshotId: <from step 2> }
```

Expected response — `pullDifferences` populated with **5** entries,
`differences` empty:

| Object | Classification | Reason | ids on the entry |
|---|---|---|---|
| `Customers.CustomerPreference` | `Add new` | new table only in the pull | `afterPullId` only |
| `Customers.OldFeature` | `Delete new` | pull removed it from schema-model, drift leg untouched | `afterPullId` only |
| `Customers.SunsetFeature` | `Add missing` | both drift and pull removed it — no reconciliation needed, but the snapshot leg is still applicable if you want to restore it | `beforePullId` only |
| `Customers.Customer` | `Edit conflict` | pull added `NickName`, drift added `LoyaltyPoints` — both legs touched the table | both `afterPullId` and `beforePullId` |
| `Customers.Newsletter` | `Edit existing` | pull left it alone, drift widened `Title` | both `afterPullId` and `beforePullId` |

The `Customer` and `LoyaltyPoints` drift do **not** produce a separate `B/*`
row. `ThreeSidedDiffConverter` correlates one result per object, so a table
that appears in both the pull leg and the drift leg collapses into a single
`Edit conflict` entry.

Sanity check: `<workspace tmp>/diff_development/<artifactId>/` contains
`source_target`, `snapshot_target`, and `snapshot_source` files. That's what
makes `countDifferenceSources` return `THREE_SOURCES`.

### 5. Apply — exercise every branch

Pick change IDs from step 4. The response now includes an `objects` array
where each entry has an `origin` field:

- `Current schema` — the object was directly selected on the after-pull leg.
- `Current schema (required by selection)` — pulled in as a dependency on the
  after-pull leg.
- `Old schema` — directly selected on the before-pull leg.
- `Old schema (required by selection)` — pulled in as a dependency on the
  before-pull leg.

**5a. Before-pull only** — snapshot_target artifact only:
```
update_development { changes: ["B/<Newsletter beforePullId>"] }
```
Expect one prepare/deploy pair. `objects` should reference `Customers.Newsletter`
with origin `Old schema`, and nothing else — no dependencies pulled in because
`Newsletter` has no FKs.

**5b. After-pull only** — source_target artifact only:
```
update_development { changes: ["A/<CustomerPreference afterPullId>"] }
```
Verify `Customers.CustomerPreference` now exists in `dev`. Because
`CustomerPreference` FKs to `Customer`, expect `Customer` to appear in
`objects` with origin `Current schema (required by selection)` — see the
finding below.

**5c. Mixed** — before-pull deploys first, then after-pull:
```
update_development { changes: ["A/<Customer afterPullId>", "B/<Newsletter beforePullId>"] }
```
Two `Prepare completed for update_development` log lines. The first
references `snapshot_target` (before-pull leg runs first so that any
new-object changes on the after-pull leg can see the updated definitions of
existing objects), the second references `source_target`.

**Conflict picking** — the `Customer` entry carries both an `afterPullId` and
a `beforePullId`. Try each in isolation:
- `["B/<Customer beforePullId>"]` → snapshot→dev leg only. The snapshot
  doesn't have `NickName` either, so this diff only sees `LoyaltyPoints`.
  Deploy drops `LoyaltyPoints` from dev.
- `["A/<Customer afterPullId>"]` → schemaModel→dev leg only. This diff sees
  `NickName` missing on dev **and** `LoyaltyPoints` extra on dev, so the
  generated script may try to add `NickName` and drop `LoyaltyPoints`
  together. Worth eyeballing whether that's the intended behavior for a
  conflict — if not, it's a product finding.

**5d. Wildcard on a 3-sided diff**:
```
update_development { changes: ["*"] }
```
By design, `*` on a 3-sided diff intentionally runs only the after-pull leg
(the `source_target` artifact) — the same behaviour as a normal two-sided
apply. Drift-only differences and before-pull conflict resolutions are **not**
included. Verify on dev:
- `Customers.OldFeature` is **dropped** from dev (pull-leg delete applied).
- `Newsletter.Title` reverts to `nvarchar(100)` (drift silently reverted by
  the after-pull leg).
- `Customer` gets `NickName` added and `LoyaltyPoints` dropped (conflict
  resolved to the pull side).
- `CustomerPreference` created.

If you want the drift preserved, select the `B/*` ids explicitly rather than
using the wildcard.

**5e. Error cases**:
- `changes: ["<raw id, no prefix>"]` → `FlywayException`, no prepare runs.
- `changes: ["*", "A/<id>"]` → `FlywayException` from
  `validateAndConvertSelectedIds`.

## Reset (to re-run)

```
sqlcmd -S "127.0.0.1" -U sa -P "flywayPWD000" -d dev -i scripts/99_reset.sql
python scripts/apply_pull_edits.py --revert
sqlcmd -S "127.0.0.1" -U sa -P "flywayPWD000" -d dev -i scripts/00_setup_dev.sql
```

That returns you to step 2.

## File layout

- `scripts/00_setup_dev.sql` — rebuilds `dev` to baseline + drift.
- `scripts/99_reset.sql` — drops every `Customers.*` table.
- `scripts/apply_pull_edits.py` — flips schema-model between pre-pull and
  post-pull (`--revert` for the latter).
- `scripts/pull/*.sql` — staged post-pull schema-model files.
- `scripts/baseline/*.sql` — pre-pull baseline copies of files that the pull
  deletes, so `--revert` can restore them.

## Findings / open questions

- **FK-parent drag on pure column edits.** Original scenario put the drift on
  `Address.Phone` (widen `nvarchar(20)` → `nvarchar(30)`). Deploying
  `B/<Address>` in isolation pulled `Customers.Customer` in as a dependency,
  even though the change is a plain `ALTER COLUMN` that doesn't touch the FK
  column or require a table rebuild. That's why the drift now targets
  `Newsletter` (FK-free) instead — otherwise 5a can't be run as a
  single-object scope test. Worth checking whether the dependency resolver
  should scope down for non-structural column edits, or whether this is
  intentional (e.g. SQL Server requiring FK metadata refresh for certain
  ALTER COLUMNs). The `origin` field now surfaces dragged objects as
  `... (required by selection)`, so this is at least visible to the caller.

- **`CustomerPreference` FK drag on 5b — confirmed.**
  `A/<CustomerPreference>` in isolation deployed `CustomerPreference` **and**
  dragged `Customer` in via FK dependency. Because `Customer` is a conflict
  object, the drag silently resolved the conflict to the pull side (added
  `NickName`, dropped `LoyaltyPoints` drift). Since the introduction of
  `ChangeOrigin`, the response now marks the dragged `Customer` with origin
  `Current schema (required by selection)`, which at least lets the caller
  detect that something they didn't select was touched — but there's still no
  in-tool warning that the dragged object was a conflict object with a
  pending before-pull decision.

- **Isolated select on an FK-free object works cleanly.** Control case:
  `A/<Newsletter>` alone deployed only `Newsletter`. `Customer` was
  untouched, `CustomerPreference` not created. This confirms the drag is FK-
  driven (not artifact-wide scope), and per-change selection works when the
  chosen object has no FK relationships.

- **Root cause in code.** `PrepareFromArtifactStrategy` filters differences by
  the exact selected change-ids (no expansion in the Java layer), but hands the
  native comparison engine a `GenerateScriptsSettings` with
  `includeDependencies = true` (from `RedgateCompareConfigurationExtension`,
  `OracleComparisonRequestFactory.getIncludeDependencies`). The engine then
  expands the deploy to include FK-related objects from the same artifact leg.
  Nothing in the MCP layer notices when a dragged object is a conflict object.

- **Response field naming: `pullDifferences` is misleading.** The list contains
  `Add new` (from pull), `Edit conflict` (both sides), **and** `Edit existing`
  (drift-only, pull didn't touch). Agents consistently summarise the list as
  "pull-side changes" and describe drift-only entries as if the pull caused
  them. `Edit existing` for `Newsletter` in this scenario is a concrete example:
  the pull didn't touch Newsletter at all, but the entry lives inside a field
  called `pullDifferences`. Suggested rename before ship: `classifiedDifferences`
  or `threeSidedDifferences`. Also worth updating the `differences` field
  description to explicitly say it's the two-sided (no snapshot) case.

- **`Edit existing` classification label is directionally confusing.**
  "Existing" reads as "the pull left it as-is" — but semantically it means
  "drift-only difference". Consider `Local drift` or `Drift only` instead.

- **Wildcard on 3-sided diff runs only the after-pull leg — by design.**
  `*` intentionally falls through to the two-sided path and runs the entire
  `source_target` artifact. That includes drift-only edits (`Newsletter`
  reverts), conflict resolutions to the pull side (`Customer`), and pull-side
  deletions (`OldFeature`). This is documented behaviour per the PR, but it
  is not surfaced to the caller: there's no warning that drift is being
  discarded or that conflicts are being auto-resolved to the pull side.
  Callers who want to preserve drift must select the `B/*` ids explicitly.
  Worth considering a summary field in the response describing which side
  won for conflicts under `*`.
