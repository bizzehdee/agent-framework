---
name: environments-and-packaging
description: Python environment and packaging discipline - every project in its own virtual environment, pyproject.toml as the single source of truth, committed lockfiles for reproducible installs, and no import path hacks. USE FOR setting up or modifying a Python project's environment, adding or updating a dependency, editing pyproject.toml or requirements files, writing install or CI steps, or packaging a distributable. DO NOT USE FOR licence and supply-chain vetting of a new dependency - see dependency-management.
globs: **/pyproject.toml,**/requirements*.txt,**/setup.py,**/setup.cfg,**/Pipfile
stack: python
---

# Environments and packaging (Python)

## Virtual environments

- Every project runs in its own virtual environment. Never install into the system
  or user-global interpreter, and never with elevated privileges.
- Use the environment tool the project already uses — uv, venv, poetry, pipenv,
  conda ([[existing-project-conventions]]). Do not introduce a second one.
- The environment directory is disposable and ignored by git. Anything that cannot
  be recreated with one install command from the committed files is a defect.
- Declare the supported interpreter range in `requires-python`, and test against
  the oldest version declared. Code that needs a newer feature narrows the range in
  the same change.

## One source of truth

- `pyproject.toml` declares the project: metadata, direct dependencies, entry
  points, and tool configuration. New projects do not add `setup.py`, `setup.cfg`,
  or per-tool config files for what `pyproject.toml` can hold.
- Declare only direct dependencies, with the loosest constraint that is actually
  known to be true. Exact pins live in the lockfile, not in `pyproject.toml`.
- Vetting a new dependency — licence, health, supply chain — is
  [[dependency-management]]. This file governs where it is declared.

## Lockfiles and reproducibility

- Commit a lockfile (`uv.lock`, `poetry.lock`, or a compiled `requirements.txt`
  generated from the declared dependencies). Regenerate it with the tool; never
  edit it by hand.
- CI and deployment install from the lockfile, so every environment resolves to
  identical versions. `pip install <name>` against a bare environment is for
  experiments only.
- A dependency change and its lockfile change land in the same commit
  ([[git-and-commits]]).

## Imports and entry points

- Never modify `sys.path` at runtime and never set `PYTHONPATH` to make imports
  resolve. Install the project into its environment (`pip install -e .` or the
  tool's equivalent) so imports work because the package is installed.
- Executables are declared as entry points in `[project.scripts]`, not as loose
  scripts that assume a working directory.
- Relative imports stay within a package. Reaching into a sibling project by path
  means the dependency is undeclared.

## Checklist

- [ ] The project installs into a fresh virtual environment with one command.
- [ ] `requires-python` is declared and honest.
- [ ] Direct dependencies in `pyproject.toml`; exact versions only in the lockfile.
- [ ] The lockfile is committed and current with the declared dependencies.
- [ ] No `sys.path` or `PYTHONPATH` manipulation anywhere.
