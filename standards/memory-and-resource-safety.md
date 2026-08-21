---
name: memory-and-resource-safety
description: C and C++ ownership and lifetime discipline - RAII for every resource, smart pointers over naked new and delete, bounded buffer and string handling, no reliance on undefined behaviour, warnings as errors, and sanitisers on the test build. USE FOR writing or reviewing C or C++ code that allocates, owns a resource, or handles a buffer or string, choosing a pointer or ownership type, fixing a leak, crash, use-after-free, or data race, or configuring compiler warnings and sanitisers. DO NOT USE FOR allocation performance tuning - see performance-discipline.
globs: **/*.c,**/*.cc,**/*.cpp,**/*.cxx,**/*.h,**/*.hpp
stack: c-cpp
---

# Memory and resource safety (C/C++)

## Ownership

- Every resource — memory, file handle, socket, lock, mapping — has exactly one
  owner, and in C++ that owner is an object whose destructor releases it (RAII).
  If a function can return early, RAII is the only release path that survives it.
- No naked `new`/`delete` or `malloc`/`free` in application code. Allocation goes
  through `std::make_unique`, `std::make_shared`, or a container.
- `std::unique_ptr` is the default owning type. `std::shared_ptr` only when
  ownership is genuinely shared, stated in a comment at the declaration — it is
  not a way to avoid thinking about lifetime.
- Raw pointers and references are non-owning observers. A function taking one must
  not store it beyond the call, and never frees it.
- In C, name the owner in the comment at the allocation site, release on every
  exit path with a single `goto cleanup` chain, and set the pointer to null after
  freeing so a double free becomes a no-op.

## Bounds and lifetimes

- Prefer containers, `std::array`, `std::span`, and `std::string_view` over raw
  arrays and pointer-plus-length pairs. A buffer never travels without its size.
- `std::string_view` and `std::span` do not own. Never return one referring to a
  local, and never store one beyond the lifetime of what it views.
- Mutating a container invalidates iterators, references, and views into it. Do
  not hold any of them across an insert or erase.
- Banned string functions: `gets`, `strcpy`, `strcat`, `sprintf`, and `scanf`
  with an unbounded `%s`. Use the bounded forms and check their results. An
  out-of-bounds write is a security defect, not a crash ([[secure-engineering]]).

## Undefined behaviour

- Undefined behaviour is a defect even when the current build behaves: signed
  overflow, out-of-range shifts, null dereference, data races, use after free,
  reading uninitialised memory. The optimiser is entitled to assume none of it
  happens.
- Initialise at the point of declaration. A variable that cannot yet have a value
  is being declared too early.
- Casting away `const` or aliasing through an unrelated pointer type is UB, not a
  workaround.

## Compiler and sanitisers

- Build with warnings on and treated as errors — `-Wall -Wextra -Werror` or the
  project's equivalent ([[existing-project-conventions]]). Fix a warning; never
  suppress it without a comment saying why the code is right and the compiler is
  wrong.
- Tests run under AddressSanitizer and UndefinedBehaviorSanitizer in at least one
  CI configuration, and under ThreadSanitizer where the code is concurrent. A
  sanitiser report is a failing build ([[testing-standards]]).
- A leak, crash, or corruption is diagnosed under the sanitisers first, not by
  adding prints ([[elimination-debugging]]).

## Checklist

- [ ] Every resource has one owner and is released by RAII or on every exit path.
- [ ] No naked `new`/`delete`; `unique_ptr` unless sharing is stated.
- [ ] No buffer travels without its size; no banned string functions.
- [ ] No view or iterator outlives or spans a mutation of what it refers to.
- [ ] Warnings are errors; no unexplained suppressions.
- [ ] ASan and UBSan run in CI and pass.
