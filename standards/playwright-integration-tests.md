---
name: playwright-integration-tests
description: Playwright browser tests for .NET web applications - when a behaviour needs a real browser driving the real app instead of or in addition to unit coverage, and the conventions those tests follow. USE FOR deciding whether a behaviour needs a Playwright test, writing or reviewing browser end-to-end tests for a .NET web front end, testing browser APIs a unit test environment fakes or lacks, or testing multi-tab, multi-session, or SignalR round-trip behaviour. DO NOT USE FOR unit-level test practice, coverage targets, or mocking rules - see testing-standards. DO NOT USE FOR non-web .NET projects.
globs: **/e2e/**,**/playwright.config.*
stack: dotnet
---

# Playwright integration tests (.NET web)

## When a browser test is required

Unit tests (xUnit, Vitest/Karma component specs) cover logic in isolation. Some
behaviour only proves itself against a real browser driving the real application,
and needs a Playwright test instead of, or in addition to, unit coverage:

- Anything using a real browser API that a unit test's jsdom or TestBed
  environment fakes or lacks entirely: Service Worker `push` and
  `notificationclick` handling, WebAuthn ceremonies, `PushManager` subscription,
  real `localStorage`/IndexedDB persistence across a page reload, drag-and-drop
  file input.
- Multi-tab or multi-session behaviour: two real browser contexts standing in for
  two devices or two accounts, exercising a live SignalR round trip — message
  send and receive, typing indicators, read receipts, presence — rather than a
  mocked hub connection.
- An end-to-end flow that is only proved correct when every layer is real
  together — registration through to live messaging between two sessions —
  exercised against the real backend (the repository's Docker Compose stack or
  equivalent), not against service-level mocks.
- Anything you would verify by starting the app and using the feature in a
  browser. If a change is worth checking by hand once, automate that check so it
  cannot silently regress.

## Not a substitute for unit tests

A Playwright test is for behaviour a unit test structurally cannot reach, not a
replacement for fast, focused unit coverage of logic that needs no browser. Do not
move assertions a unit test can make into the e2e suite; each browser test costs
seconds where a unit test costs milliseconds ([[testing-standards]]).

## Conventions

- Tests live where the repository already keeps them
  ([[existing-project-conventions]]); by default an `e2e/` directory beside the
  web project, run with `npx playwright test` from that project's directory.
- A Playwright test lands in the same change as the feature it covers, not
  deferred to a follow-up.
- `@playwright/test` is a dev dependency like any other: the same vulnerability
  audit and update policy applies to it ([[dependency-management]]).
- Deterministic, like every other test: rely on Playwright's auto-waiting and
  web-first assertions, never a fixed sleep, and never depend on the residue of a
  previous test or session ([[testing-standards]]).

## Checklist

- [ ] Every behaviour needing a real browser API, second session, or full stack
      has a Playwright test.
- [ ] Nothing a unit test can assert was pushed into the e2e suite.
- [ ] New Playwright tests ship in the same change as the feature.
- [ ] No fixed sleeps; auto-waiting assertions only.
