---
name: cpp-headers-and-interfaces
description: C++ header hygiene and class interface design - self-contained headers that include what they use, the one definition rule, the rule of zero or five, explicit constructors, const-correctness, noexcept moves, virtual destructors, and parameter passing. USE FOR creating or editing a C++ header, declaring a class, struct, or public function, adding a constructor, destructor, copy or move operation, or virtual function, choosing how a parameter or return value is passed, or fixing a multiple-definition, incomplete-type, or include-order error. DO NOT USE FOR who owns a resource and which smart pointer to use - see memory-and-resource-safety. DO NOT USE FOR module boundaries and layering - see architecture-principles.
globs: **/*.h,**/*.hpp,**/*.hxx,**/*.ixx,**/*.cppm
stack: c-cpp
---

# C++ headers and interfaces

## Headers

- A header compiles on its own. It includes every header whose names it uses
  and relies on no transitive include. A source file includes its own header
  first, which proves it.
- One include guard per header, in the form the repository already uses:
  `#pragma once` or a named guard ([[existing-project-conventions]]).
- Forward-declare a type that the header uses only by pointer or reference.
  Include its header when the header needs its size or members.
- No `using namespace` and no namespace-scope `using` declaration in a header.
- No macro where a `constexpr` value, `inline` function, or template does the
  job. A macro a header must define carries the project prefix.
- Nothing in a header is defined in an anonymous namespace or as a non-`inline`
  namespace-scope variable or function: every includer gets its own copy, or
  the link fails.

## One definition rule

- An entity has one definition across the program. Functions and variables
  defined in a header are `inline`, `constexpr`, or templates.
- The same class or inline function must be token-identical in every
  translation unit. A definition that changes with a macro set differently in
  two files is undefined behaviour with no diagnostic.

## Special member functions

- Rule of zero: a class that owns nothing directly declares no destructor,
  copy, or move operations. Its members manage themselves
  ([[memory-and-resource-safety]]).
- Rule of five: a class that declares any of the destructor, copy constructor,
  copy assignment, move constructor, or move assignment declares all five,
  each defined, defaulted, or deleted.
- Move operations are `noexcept`. A container copies instead of moving when
  they are not.
- A class with a virtual function has a virtual destructor, or a protected
  non-virtual one. Deleting a derived object through a base pointer without it
  is undefined.
- A polymorphic base class deletes or protects its copy and move operations,
  so it cannot be sliced.

## Interfaces

- A constructor callable with one argument is `explicit`, and so is a
  conversion operator, unless implicit conversion is the purpose and a comment
  says so.
- A member function that does not modify the object is `const`. A parameter
  passed by reference that is not modified is `const&`.
- An overriding function says `override` and omits `virtual`. A class not
  designed for inheritance is `final` or documents that it is not a base.
- Pass cheap types by value, read-only inputs by `const&` or a view, and a
  value the function will keep by value followed by `std::move`. Return by
  value. Use an out-parameter only where the repository already does.
- A function whose result must not be ignored carries the `nodiscard`
  attribute: error codes,
  status results, and anything that returns ownership ([[error-handling]]).
- Use `enum class`. Use `nullptr`, never `0` or `NULL`.
- Follow the repository's policy on exceptions. Where exceptions are disabled,
  never write `throw` or `try`, and report failure through the return type.

## Checklist

- [ ] Every header compiles on its own and includes what it uses.
- [ ] No `using namespace` in a header; no non-`inline` definitions in a header.
- [ ] Each class follows the rule of zero or declares all five special members.
- [ ] Move operations are `noexcept`; polymorphic bases have a virtual or protected destructor.
- [ ] Single-argument constructors and conversion operators are `explicit`.
- [ ] Non-mutating members and unmodified reference parameters are `const`.
- [ ] Overrides say `override`; must-use results carry the `nodiscard` attribute.
