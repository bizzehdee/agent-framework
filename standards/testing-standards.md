---
name: testing-standards
description: Test coverage targets, definition-of-done rules, and test design standards including behaviour-over-implementation testing, integration-test preference, mocking limits, and mandatory regression tests for bugs. USE FOR writing, reviewing, or planning tests. USE FOR deciding whether a task is complete. USE FOR judging whether existing test coverage is adequate. USE FOR deciding what to test after fixing a bug. DO NOT USE FOR choosing a test framework in an existing repo - follow the repo's framework per existing-project-conventions.
globs: **/*test*,**/*Test*,**/*spec*,**/*Spec*,**/tests/**,**/test/**
alwaysApply: false
---

# Testing standards

## Coverage target

- Aim for **90% branch coverage**.
- Exclude from the target:
  - EF Core migrations.
  - Generated code.
  - Composition-root wiring, such as `Program.cs` and `Startup.cs`, and the
    equivalent boilerplate in other languages and frameworks.
- Coverage is a floor to detect untested branches, not a goal in itself. Do not
  add assertion-free tests to raise the number.
- If the target cannot be met, state the uncovered branches and why.

## Definition of done

- Tests must pass before a task is considered done.
- You must not mark a task checkbox complete until its tests are passing.
- You must not report a task complete on the basis that tests "should" pass. Run
  them and report the actual result.
- If tests fail and you cannot fix them, say so, include the failure output, and
  leave the task open.

## What to test

- Test behaviour, not implementation details. A test must assert an observable
  outcome, such as a return value, a persisted state change, or an emitted event.
- A test must not assert that a specific private method was called, unless the
  call itself is the contract.
- A refactor that preserves behaviour must not require test changes. If it does,
  the tests were coupled to implementation.

## Test type preference

Prefer, in this order:

1. Integration tests for business workflows, exercising real collaborators.
2. Unit tests for logic with many branches or edge cases.
3. End-to-end tests only for critical paths, because they are slow and brittle.

## Mocking

- Avoid excessive mocking.
- Mock only what you cannot control: network calls, wall-clock time, randomness,
  the filesystem where relevant, and third-party services.
- Do not mock the type under test.
- Do not mock a type you own when a real instance is cheap to construct.
- A test whose setup is mostly mock configuration is testing the mocks. Rewrite it
  as an integration test.

## Regression tests

- Every new bug must be accompanied by a regression test.
- Write the test first, confirm it fails for the reported reason, then fix the
  defect, then confirm the test passes.
- The test must fail if the specific defect is reintroduced. A broad test that
  passes with the bug present is not a regression test.

## Determinism

Tests must be deterministic and repeatable.

- No dependence on wall-clock time, current date, or timezone. Inject a time
  source.
- No dependence on random values without a fixed seed.
- No dependence on test execution order.
- No dependence on shared mutable state between tests.
- No dependence on network availability.
- A test that fails intermittently must be fixed or removed, not retried.

## Checklist before reporting a test task complete

- [ ] The full test command was run and its output observed.
- [ ] All tests pass.
- [ ] Each new test asserts an observable outcome.
- [ ] Each fixed bug has a test that fails without the fix.
