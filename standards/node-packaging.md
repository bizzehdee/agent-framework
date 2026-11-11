---
name: node-packaging
description: Node.js package and runtime discipline - one package manager per repository chosen from its lockfile, committed lockfiles, exact installs in CI, declared engines, package.json scripts as the single entry points, and no committed node_modules. USE FOR setting up or modifying a Node.js project's packaging, editing package.json, adding or updating an npm dependency, choosing between npm, pnpm, and yarn, writing install or CI steps for a Node project, or pinning the Node version. DO NOT USE FOR licence and supply-chain vetting of a new dependency - see dependency-management. DO NOT USE FOR browser-versus-server architecture choices - see architecture-principles.
globs: **/package.json,**/.npmrc,**/.nvmrc
stack: node
---

# Node packaging

## One package manager

The lockfile names the package manager: `package-lock.json` is npm,
`pnpm-lock.yaml` is pnpm, `yarn.lock` is yarn. Use the one the repository
already uses ([[existing-project-conventions]]), and never introduce a second —
two lockfiles in one repository is a defect to report.

- Declare it in `package.json`'s `packageManager` field where the repository
  uses Corepack, so every machine resolves the same version.
- Run scripts through that manager (`npm run build`, `pnpm test`), not through
  globally installed tools.

## Lockfiles and installs

- The lockfile is committed. It is the record of what shipped
  ([[dependency-management]]).
- CI and any clean build install from the lockfile exactly: `npm ci`,
  `pnpm install --frozen-lockfile`, or `yarn install --immutable`. A plain
  `install` in CI can silently rewrite the lockfile.
- Never hand-edit a lockfile. Regenerate it with the package manager.
- `node_modules/` is never committed and is in `.gitignore`.

## Runtime version

- Declare the supported Node range in `package.json`'s `engines.node`, and pin
  the development version in `.nvmrc` or the repository's version-manager file
  when one is in use. An undeclared range means "whatever was on the machine",
  which is not reproducible.
- Match the CI Node version to the declared range.

## Scripts and execution

- `package.json` scripts are the entry points: build, test, lint, and start
  live there, so every tool and agent finds them in one place.
- Never run an unpinned remote package (`npx <tool>` without a version) in a
  script, hook, or CI step; pin the version or add it as a dev dependency
  ([[dependency-management]]).
- Keep install scripts (`postinstall` and relatives) out of your own packages
  unless genuinely required, and state why when one is.

## Module system

- Follow the repository's module system (`type` in `package.json`, or its
  established import style). Do not mix ESM and CommonJS in new code without
  approval ([[existing-project-conventions]]).

## Checklist

- [ ] Exactly one package manager, named by its one lockfile.
- [ ] Lockfile committed and regenerated, never edited.
- [ ] CI installs with the exact-install command, not plain install.
- [ ] `engines.node` declares the supported range.
- [ ] No `node_modules/` tracked, no unpinned `npx` in any script.
