---
name: java-language
description: Java language discipline - using only the project's Java version, immutable value types and records, null handling and Optional, equals and hashCode, generics without raw types, exceptions and try-with-resources, streams in moderation, and narrow visibility. USE FOR writing or reviewing Java code that declares a class, record, enum, or interface, handles null or Optional, defines equals, hashCode, or compareTo, uses generics, collections, or streams, throws or catches an exception, or opens a resource. DO NOT USE FOR threads, executors, and shared state - see java-concurrency. DO NOT USE FOR Gradle and Maven - see jvm-build-and-dependencies. DO NOT USE FOR error-handling policy beyond the language - see error-handling.
globs: **/*.java
stack: java
---

# Java language

## Language version

- Before your first change, read the Java version the build declares
  ([[jvm-build-and-dependencies]]). Use only features of that version: records
  need 16, sealed types and pattern matching for `instanceof` need 17, pattern
  matching for `switch` and virtual threads need 21.
- Use the newest construct the version allows where it replaces boilerplate.
  Do not add Lombok, or any annotation processor, to a project that has none
  ([[dependency-management]]).

## Types and immutability

- A class is immutable unless it has a reason to change: `final` fields, no
  setters, defensive copies of mutable inputs (`List.copyOf`), and no mutable
  field returned directly.
- A type that only carries data is a `record`. A closed set of alternatives is
  a `sealed` interface with records, handled by an exhaustive `switch` with no
  `default`, so a new case fails to compile.
- A fixed set of constants is an `enum`, never `int` or `String` constants.
- A class is `final` unless designed for inheritance. Prefer composition.
- Declare the narrowest visibility that works: `private` first, then
  package-private. `public` is a commitment.
- Program to interfaces for collections (`List`, `Map`), and return
  unmodifiable ones.

## Null

- No public method returns `null` for a collection, array, or `Optional`.
  Return the empty value.
- `Optional` is a return type for "may be absent". Never a field, a
  parameter, or a collection element, and never call `get()` without a
  presence check; use `orElseThrow`, `map`, or `ifPresent`.
- Validate parameters at a public boundary with `Objects.requireNonNull`, and
  use the nullness annotations the repository already uses
  ([[existing-project-conventions]]).

## Equality

- Override `equals` and `hashCode` together, from the same fields, or neither.
  A record does both.
- Compare objects with `equals`, never `==`. That includes `String` and boxed
  numbers: `==` on `Integer` works for small values and fails for large ones.
- `compareTo` is consistent with `equals`. Build comparators with
  `Comparator.comparing`, never by subtracting.
- Never use `float` or `double` for money. Use `BigDecimal`, constructed from
  a `String`, or integer minor units.

## Generics

- No raw types. No unchecked cast without a comment proving it safe, and
  `@SuppressWarnings` on the smallest scope that needs it.
- Use bounded wildcards for parameters: `? extends T` for a source,
  `? super T` for a sink.

## Exceptions and resources

- Every `AutoCloseable` is opened in a try-with-resources statement. That
  includes streams from `Files.lines` and `Files.list`.
- Catch the most specific type that the code can handle. Never catch
  `Throwable`, `Error`, or bare `Exception` except at a top-level boundary,
  and never leave a catch block empty ([[error-handling]]).
- Wrap with the cause: `new XException("context", e)`. Never drop it.
- Catching `InterruptedException` restores the flag with
  `Thread.currentThread().interrupt()` or rethrows.
- No `return` or `throw` in a `finally` block. No exceptions for ordinary
  control flow.
- Unchecked exceptions for programming errors, checked ones only where the
  caller can recover, following the repository's existing practice.

## Streams and strings

- A stream pipeline has no side effects in `map`, `filter`, or `peek`. Use a
  loop where one is clearer, and where the body must throw or mutate.
- Never reuse a stream, and never use `parallelStream` without a measurement
  ([[performance-discipline]]).
- Pass a `Charset` to every conversion between bytes and text, and a `Locale`
  to `toLowerCase`, `toUpperCase`, and `String.format` where the result is not
  for display. The platform default differs between machines.
- Use `java.time`, never `Date` or `Calendar`, and inject a `Clock` where code
  reads the current time ([[testing-standards]]).

## Checklist

- [ ] Every language feature used exists in the project's Java version.
- [ ] Data carriers are records or immutable classes; no mutable field exposed.
- [ ] No `null` returned for a collection or `Optional`; no `Optional` field or parameter.
- [ ] `equals` and `hashCode` overridden together; no `==` on objects.
- [ ] No raw types or unexplained unchecked casts.
- [ ] Every closeable resource is in try-with-resources.
- [ ] No empty catch, no swallowed cause, no swallowed interrupt.
- [ ] Charset and locale stated wherever the platform default would apply.
