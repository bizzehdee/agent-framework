---
name: rust-cargo
description: Rust Cargo discipline - Cargo.toml as the manifest of record, a committed Cargo.lock for binaries, pinned edition and rust-version, rustfmt and clippy as part of done, feature flags kept additive, and unsafe code justified and isolated. USE FOR setting up or modifying a Rust crate or workspace, editing Cargo.toml or Cargo.lock, adding or updating a Rust dependency, writing install or CI steps for a Rust project, defining feature flags, or reviewing unsafe blocks. DO NOT USE FOR licence and supply-chain vetting of a new dependency - see dependency-management.
globs: **/Cargo.toml,**/Cargo.lock
stack: rust
---

# Rust and Cargo

## The manifest and lockfile

- `Cargo.toml` is the manifest of record. Declare the `edition`, and
  `rust-version` when the crate has a meaningful minimum.
- Commit `Cargo.lock` for binaries, applications, and workspaces that produce
  them. For a library, follow the repository's existing choice
  ([[existing-project-conventions]]); absent one, commit it — reproducible CI
  outweighs the notional flexibility.
- Never hand-edit `Cargo.lock`. Change dependencies through `cargo add`,
  `cargo update`, or an explicit, reviewed `Cargo.toml` edit
  ([[dependency-management]]).
- In a workspace, declare shared dependency versions once, in
  `[workspace.dependencies]`, where the toolchain supports it.

## Toolchain

- Where the repository pins a toolchain (`rust-toolchain.toml`), match it; CI
  uses the same pin. Raise the edition or `rust-version` deliberately, in its
  own change.

## Formatting and checks

- `cargo fmt` is not optional; code that is not formatted is not done.
- `cargo clippy` runs with the test step, and new code introduces no new
  warnings. Silence a lint only with a targeted `#[allow]` carrying the reason
  as a non-obvious why ([[code-quality]]), never crate-wide.

## Features

- Feature flags are additive: enabling a feature must never break or remove
  behaviour another feature or the default set provides.
- Keep the default feature set minimal and deliberate. Document what each
  feature gates in `Cargo.toml` comments or the crate docs.

## Unsafe code

- Every `unsafe` block states the invariant that makes it sound, as a comment,
  and is as small as the invariant allows.
- Prefer a safe abstraction from the standard library or an existing
  dependency over new `unsafe`. New `unsafe` in a codebase without any is an
  architectural change: ask first ([[architecture-principles]]).

## Checklist

- [ ] `edition` declared; `rust-version` declared where a minimum matters.
- [ ] `Cargo.lock` committed for anything that builds a binary, never edited by hand.
- [ ] `cargo fmt` and `cargo clippy` clean on the change.
- [ ] Features remain additive, defaults minimal.
- [ ] Every `unsafe` block states its invariant and was approved where new.
