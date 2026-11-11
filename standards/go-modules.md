---
name: go-modules
description: Go module and toolchain discipline - go.mod and go.sum as the single dependency record, tidy after every dependency change, a declared go version, gofmt as non-negotiable formatting, and the repository's vendoring policy respected. USE FOR setting up or modifying a Go module, editing go.mod or go.sum, adding or updating a Go dependency, writing install or CI steps for a Go project, vendoring decisions, or formatting and linting Go code. DO NOT USE FOR licence and supply-chain vetting of a new dependency - see dependency-management.
globs: **/go.mod,**/go.sum
stack: go
---

# Go modules

## The module record

- `go.mod` declares the module path, the `go` directive, and every direct
  dependency; `go.sum` holds the checksums. Both are committed
  ([[dependency-management]]).
- Run `go mod tidy` in the same change that adds, updates, or removes a
  dependency, so the record never drifts from the imports.
- Never hand-edit `go.sum`. `go.mod` is edited only through `go get`,
  `go mod edit`, or an explicit, reviewed change.
- One module per repository unless the repository already uses a multi-module
  layout ([[existing-project-conventions]]). Do not add a nested module to
  solve an import problem.

## Toolchain

- The `go` directive states the minimum language version; raise it
  deliberately, in its own change, never as a side effect.
- CI builds with a Go version that satisfies the directive. Where the
  repository pins a `toolchain` directive, match it.
- No `GOPATH`-era workarounds: no `vendor/` symlinks, no `replace` directives
  pointing at local paths left in a committed change unless the repository
  documents why.

## Vendoring

- Follow the repository's existing policy: a repository with a `vendor/`
  directory keeps it current (`go mod vendor` in the same change that alters
  dependencies); a repository without one does not gain one uninvited.

## Formatting and checks

- `gofmt` (or `goimports` where the repository uses it) is not optional; code
  that is not formatted is not done.
- Run `go vet` as part of the test step. Where the repository configures a
  linter such as `golangci-lint`, its findings follow the repository's
  convention ([[existing-project-conventions]]).

## Checklist

- [ ] `go.mod` and `go.sum` committed and tidy after every dependency change.
- [ ] No hand-edit to `go.sum`, no stray local `replace` directive.
- [ ] The `go` directive matches what CI builds with.
- [ ] `vendor/`, where present, regenerated in the same change.
- [ ] All code gofmt-formatted and `go vet` clean.
