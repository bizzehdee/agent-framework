---
name: cpp-undefined-behaviour
description: The C++ language traps that compile cleanly and fail later - dangling references from temporaries and lambda captures, moved-from objects, integer conversion and overflow, casts and type punning, evaluation order, and virtual calls during construction. USE FOR writing or reviewing C++ that captures in a lambda, returns or stores a reference or view, uses std::move, mixes signed and unsigned or differently sized integers, casts between types, reinterprets bytes, or diagnosing behaviour that changes with optimisation level or compiler. DO NOT USE FOR ownership, buffer bounds, and sanitiser setup - see memory-and-resource-safety. DO NOT USE FOR data races and threading - see cpp-concurrency.
globs: **/*.cc,**/*.cpp,**/*.cxx,**/*.h,**/*.hpp
stack: c-cpp
---

# C++ undefined behaviour

[[memory-and-resource-safety]] states the principle: undefined behaviour is a
defect even when the build behaves. These are the forms that pass review most
often.

## References that outlive their target

- A lambda that outlives the scope it was created in captures by value. `[&]`
  and a captured `this` are allowed only when the lambda is called before that
  scope ends. A lambda handed to a thread, a callback registry, a timer, or a
  coroutine outlives it.
- Never return a reference, pointer, or view to a local or a parameter taken by
  value.
- Binding a temporary to a `const&` extends its life only for a direct binding.
  It does not extend through a function call or a member access chain:
  `const auto& x = make().field();` dangles when `field()` returns a reference.
- Do not range-`for` over a member of a temporary (`for (auto& e :
  make().items())`) before C++23. Name the temporary first.
- A coroutine takes its parameters by value. A reference parameter dangles at
  the first suspension.

## Moved-from objects

- After `std::move(x)`, the only valid uses of `x` are assignment and
  destruction, unless the type documents its moved-from state.
- `std::move` on a `const` object silently copies. `std::move` on a returned
  local defeats copy elision. Write neither.
- Forward a forwarding reference with `std::forward` exactly once.

## Integers

- Signed overflow is undefined; unsigned arithmetic wraps. Neither is a bounds
  check. Check before the operation, or use a checked helper.
- Comparing signed with unsigned converts the signed value. Use
  `std::cmp_less` and its siblings, or convert explicitly after a range check.
- A narrowing conversion is written as an explicit cast after a range check.
  Brace initialisation rejects implicit narrowing; prefer it.
- Shifting by a negative count, or by the width of the type or more, is
  undefined.
- Sizes and indices are `std::size_t` or the container's `size_type`. A loop
  counting down with an unsigned index never goes below zero.

## Casts and type punning

- No C-style casts and no functional casts between unrelated types. Use
  `static_cast`, and `dynamic_cast` for a checked downcast.
- `reinterpret_cast` and reading a union member other than the one last
  written are undefined for type punning. Use `std::bit_cast` or `std::memcpy`.
- Access an object only through its own type, `char`, `unsigned char`, or
  `std::byte`.
- Never `memcpy`, `memset`, or `memcmp` a type that is not trivially copyable.
- Every `reinterpret_cast` and `const_cast` carries a comment stating why it is
  defined behaviour here.

## Order and initialisation

- Do not read and modify the same variable in one expression, and do not depend
  on the order in which function arguments are evaluated.
- A virtual call in a constructor or destructor runs the current class's
  version, not the derived one. Do not make one.
- Members initialise in declaration order, whatever the order of the
  initialiser list. Keep the two in the same order, and never initialise a
  member from one declared after it.
- A static in one translation unit must not depend on a static in another
  during start-up. Use a function-local static.
- A non-`void` function returns a value on every path.

## Checklist

- [ ] No lambda that outlives its scope captures by reference or captures `this` unguarded.
- [ ] No reference, pointer, or view returned or stored beyond its target's lifetime.
- [ ] No use of a moved-from object beyond assignment or destruction.
- [ ] No mixed-sign comparison or unchecked narrowing; overflow checked before the operation.
- [ ] No C-style cast; type punning only through `std::bit_cast` or `memcpy`.
- [ ] Every `reinterpret_cast` and `const_cast` carries its justification.
- [ ] No virtual call during construction or destruction; initialiser order matches declaration order.
