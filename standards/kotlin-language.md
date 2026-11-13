---
name: kotlin-language
description: Kotlin language discipline - null safety without the not-null assertion, val and read-only collections by default, data and sealed types with exhaustive when, restrained scope functions and extensions, explicit public API types, Java interop and platform types, and idiomatic error handling. USE FOR writing or reviewing Kotlin code that declares a class, data class, sealed type, object, or extension, handles a nullable value, uses lateinit, a scope function, a collection, or when, calls Java code from Kotlin, or exposes a public API. DO NOT USE FOR coroutines and Flow - see kotlin-coroutines. DO NOT USE FOR Gradle - see jvm-build-and-dependencies. DO NOT USE FOR error-handling policy beyond the language - see error-handling.
globs: **/*.kt,**/*.kts
stack: kotlin
---

# Kotlin language

## Language version

- Before your first change, read the Kotlin version from the build
  ([[jvm-build-and-dependencies]]) and use only features of that version.
  Never enable an experimental language feature or opt in to an experimental
  API without approval; an opt-in is a dependency on something that can
  change.
- Write Kotlin, not Java in Kotlin syntax: no getters and setters where a
  property works, no utility class where a top-level function works, no
  builder where default and named arguments work.

## Null safety

- No `!!`. It turns a compile-time guarantee into a crash. Use `?.`, `?:`,
  `requireNotNull` or `checkNotNull` with a message, or restructure so the
  value is not nullable.
- A type is non-null unless absence is a real state. Do not make a type
  nullable to avoid initialising it.
- `lateinit` is for a value a framework injects or a lifecycle sets before
  use. It is never a substitute for a constructor parameter, and never for a
  value that can be absent.
- A value from Java has a platform type. Give it an explicit Kotlin type at
  the boundary, nullable unless the Java side is annotated or documented as
  non-null.
- Smart casts do not apply to a mutable property. Copy it to a local `val`
  and test that.

## Immutability

- `val` unless the value must change. A `var` in a class is state someone has
  to reason about.
- Expose `List`, `Set`, and `Map`, never the mutable types. Keep a private
  `MutableList` and expose it as `List`, or expose a copy.
- A `data class` has only `val` properties in its primary constructor. A
  mutable data class used as a map key or in a set corrupts the collection.

## Types

- A type that carries data is a `data class`. A closed set of alternatives is
  a `sealed interface` or `sealed class`; a fixed set of constants is an
  `enum class`.
- A `when` over a sealed type or enum is exhaustive with no `else`, so a new
  case fails to compile.
- Wrap a primitive that has a meaning (`UserId`, `Metres`) in a
  `@JvmInline value class` where confusing two of them would be a defect.
- Use `object` for a true singleton with no state to inject. A dependency is
  passed in, not reached through an `object` ([[architecture-principles]]).
- Classes are final by default. Open one only when it is designed for
  inheritance.

## Functions

- Declare the return type of every public and protected function and
  property. An inferred public type changes when the body does.
- Use named arguments when a call passes several values of the same type, or
  a boolean literal.
- A scope function has to earn its place: `let` for a nullable chain, `apply`
  to configure an object, `also` for a side effect. Never nest them, and
  never use one where a plain statement reads the same.
- An extension function adds behaviour that needs only the public API of its
  receiver. Do not extend `Any`, `String`, or another broad type with
  domain logic, and keep an extension next to the code that uses it.
- Use expression bodies for one-expression functions, and string templates
  rather than concatenation.

## Errors

- `require` for arguments, `check` for state, `error` for the unreachable.
  Each takes a message.
- Kotlin has no checked exceptions. Document what a public function throws
  with `@throws`, and annotate with `@Throws` where Java calls it.
- Never catch `Throwable` or bare `Exception` to continue. A broad catch also
  catches coroutine cancellation ([[error-handling]]).
- `runCatching` is for converting a failure at a boundary, not for ignoring
  one. Never discard its result.
- Use `use` for every `Closeable`.

## Checklist

- [ ] No `!!`; no nullable type or `lateinit` used to avoid initialisation.
- [ ] Platform types from Java given explicit Kotlin types at the boundary.
- [ ] `val` and read-only collection types by default; no mutable collection exposed.
- [ ] Data classes hold only `val` properties.
- [ ] `when` over sealed types and enums is exhaustive with no `else`.
- [ ] Public functions and properties declare their types.
- [ ] No nested scope functions.
- [ ] No broad catch that swallows a failure; every `Closeable` is in `use`.
