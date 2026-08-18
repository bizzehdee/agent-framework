---
name: existing-project-conventions
description: Precedence rules for working inside an existing repository - follow established architecture, patterns, naming, and tooling over global preferences, and obtain approval before introducing any new framework, pattern, or architectural style. USE FOR any change to a repository you did not create, before choosing a library, before adding a project or folder, before applying a personal or default convention, and when a default guideline conflicts with what the repository already does. DO NOT USE FOR greenfield work with no existing code.
globs: 
alwaysApply: false
---

# Existing project conventions

## Precedence

Existing project structure takes precedence over global preferences, including
every default in this framework.

Order of authority, highest first:

1. An explicit instruction from the user in this conversation.
2. The repository's own documented conventions, such as `CONTRIBUTING.md`, a style
   guide, an `.editorconfig`, or a linter configuration.
3. The patterns actually used in the surrounding code.
4. The defaults in this framework, including [[architecture-principles]].

## Rules

- When working in an existing repository, follow the established architecture and
  conventions unless the user explicitly requests a change.
- Do not introduce a new framework, library, pattern, or architectural style
  without user approval.
- Do not migrate existing code to a preferred style as a side effect of an
  unrelated change.
- Match the surrounding code's naming, formatting, error-handling approach, comment
  density, and test structure.
- Prefer modifying existing code over rewriting working code.

## Before you write code in an unfamiliar repository

Establish these facts first, and state what you found:

1. The build and test commands.
2. The test framework and where tests live.
3. How the code is organised: by feature, by layer, or otherwise.
4. The dependency-injection or wiring approach, if any.
5. The error-handling and validation convention at boundaries.
6. The logging approach.
7. Whether a formatter or linter configuration exists, and its rules.

If a fact cannot be established from the code, ask rather than assume.

## When a default conflicts with the repository

Do not silently apply either one. Instead:

1. Name the framework default.
2. Name what the repository does.
3. Follow the repository.
4. Note the conflict once in your response, so the user can decide whether to
   change the convention.

The exception is security. If the repository's convention is insecure, raise it
rather than following it. See [[secure-engineering]], which is non-negotiable.
