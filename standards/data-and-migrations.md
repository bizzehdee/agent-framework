---
name: data-and-migrations
description: EF Core data access and schema migration practice - reversible reviewed migrations, expand and contract for zero downtime, explicit tracking and projection choices, and no destructive change without approval. USE FOR adding or editing an EF Core migration, changing a database schema, backfilling data, writing a query or a DbContext method, or reviewing SaveChanges and transaction boundaries. DO NOT USE FOR query performance triage on its own - see performance-discipline.
globs: **/Migrations/**,**/*DbContext.cs,**/*Configuration.cs,**/*Entity.cs
stack: dotnet
---

# Data and migrations (.NET, EF Core)

## Migrations

- Implement `Down`. Do not leave it throwing. If a change genuinely cannot be
  reversed, say so and get approval.
- One migration per logical schema change.
- Never edit a migration applied anywhere beyond your own machine. Add a new one.
- Read the generated migration before accepting it. EF Core silently generates
  drop-and-recreate, and renders a column rename as delete-plus-add, both of which
  lose data.
- Obtain explicit approval before any migration that drops a column or table,
  narrows a type, or otherwise destroys data, and state exactly what is lost. This
  is a data-loss decision ([[secure-engineering]]).
- Migrations are excluded from the coverage target ([[testing-standards]]).

## Zero-downtime schema change

Old and new application versions run simultaneously during a deploy, so the schema
must satisfy both. Expand and contract:

1. **Expand** — add the column as nullable, or add the table. Deploy.
2. **Backfill** — populate in bounded batches, as a separate step.
3. **Switch** — deploy the code using the new shape.
4. **Contract** — make it required, drop the old column. Deploy.

- Never combine a schema change and a backfill in one migration: the backfill holds
  a transaction open over a table lock.
- Backfill in batches with a delay between them. A single `UPDATE` over a large
  table blocks writers.
- Adding a column with a non-null default rewrites the table on some providers.
  Check the provider before assuming it is cheap.
- Create indexes concurrently where the provider supports it.

## Applying

- Never call `Database.Migrate()` at application startup in production: concurrent
  instances race, and a failure takes down the process. Apply migrations as a
  deliberate deployment step.
- `EnsureCreated` bypasses migrations. Never use it alongside them.
- Never apply to production without a backup and a tested rollback.

## Querying

- Read-only queries use `AsNoTracking()`. Tracking a read you never mutate costs
  memory and time for nothing.
- Project with `Select`. Do not load an entity graph to read two fields.
- Disable lazy loading, or be explicit with `Include`. Lazy loading is the usual
  cause of N+1 ([[performance-discipline]]).
- Paginate on the query with `Skip`/`Take`, never on the materialised result.
- Know where translation stops. Client-side evaluation of what looked like a
  server-side filter loads the table; check the generated SQL when a query is not
  obviously translatable.
- Never concatenate SQL. Use parameters ([[secure-engineering]]).

## Tracking and transactions

- One unit of work per request or handler. Call `SaveChangesAsync` once, at the
  end, with the `CancellationToken` — never inside a loop.
- A `DbContext` is not thread-safe. Never share one across concurrent operations
  ([[concurrency-and-async]]). Register it scoped, never singleton.
- Wrap multiple `SaveChanges` calls that must succeed together in an explicit
  transaction.
- Enable connection resiliency for transient faults. Anything the execution
  strategy may retry must be idempotent ([[error-handling]]).

## Testing

- Test against the real engine, in a container or disposable instance. The
  in-memory provider does not enforce constraints, relations, or transactions, so it
  passes code the real provider rejects.
- Each test starts from a known state and cleans up ([[testing-standards]]).
- A migration that backfills or transforms data needs a test asserting the
  resulting rows.

## Checklist

- [ ] `Down` implemented and correct.
- [ ] Generated migration read, not assumed.
- [ ] Any data loss approved explicitly.
- [ ] Schema change and backfill separate.
- [ ] Read-only queries use `AsNoTracking` and project.
- [ ] `SaveChangesAsync` called once, with a token.
- [ ] Tests run against the real engine.
