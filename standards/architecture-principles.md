---
name: architecture-principles
description: Architectural defaults for new code and new features - vertical slice architecture over layered service-heavy designs, self-contained features, minimal cross-feature dependencies, composition over inheritance, and no speculative patterns. USE FOR designing a new feature, choosing where code belongs, deciding project or folder structure, evaluating a proposed pattern, or reviewing coupling between features. DO NOT USE FOR an existing repo whose architecture is already established - see existing-project-conventions, which takes precedence.
globs: 
alwaysApply: false
---

# Architecture principles

These are defaults for greenfield work and for new features in a codebase that
has no established convention. In an existing codebase,
[[existing-project-conventions]] takes precedence.

## Vertical slices over layers

- Prefer vertical slice architecture over layered, service-heavy architectures.
- A slice owns everything one feature needs: its entry point, its validation, its
  data access, and its response shape.
- Organise folders by feature, not by technical role. Prefer `Orders/CreateOrder/`
  over `Services/`, `Repositories/`, and `Controllers/`.
- Do not create a layer that only forwards a call to the next layer.
- Do not create a service class whose only purpose is to hold one method called
  from one place. Put the logic in the slice.

## Self-containment

- Keep features self-contained where practical.
- A change to one feature should not require editing another feature's files.
- Shared code is allowed, but it must be genuinely shared infrastructure, not a
  dumping ground. A `Common` or `Shared` namespace that grows every sprint is a
  sign features are not self-contained.

## Cross-feature dependencies

- Minimise dependencies between features.
- A feature must not call another feature's internals.
- If feature A needs behaviour from feature B, prefer, in this order:
  1. Duplicating the small piece of logic A needs.
  2. Extracting the piece into shared infrastructure both depend on.
  3. Communicating through an event or a published contract.
- Do not introduce a bidirectional dependency between two features. If you find
  one, report it.

## Composition over inheritance

- Favour composition over inheritance.
- Use inheritance only for a genuine substitutable specialisation, where every
  derived type satisfies the base type's contract.
- Do not use inheritance to share code. Inject a collaborator instead.
- Do not create a base class with a single derived type.
- Prefer an interface plus an injected implementation over an abstract base class
  with protected helpers.

## No speculative patterns

- Avoid introducing a pattern that is not solving a current problem.
- Before adding a mediator, an event bus, a repository over an already-abstracted
  data access layer, a plugin system, or a configuration-driven indirection, state
  the current problem it solves.
- If the answer is "it makes future changes easier", that is not a current
  problem. Do not add it. See the no-premature-abstraction rule in
  [[code-quality]].
- Architectural changes require user approval before implementation.

## Review checklist

- [ ] New code is organised by feature.
- [ ] No layer exists solely to forward calls.
- [ ] No feature reaches into another feature's internals.
- [ ] Every inheritance relationship is a substitutable specialisation.
- [ ] Every pattern introduced has a stated current problem.
