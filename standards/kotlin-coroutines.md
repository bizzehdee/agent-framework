---
name: kotlin-coroutines
description: Kotlin coroutine and Flow discipline - structured concurrency with no GlobalScope, injected dispatchers and main-safe suspend functions, cooperative cancellation that is never swallowed, exception handling across launch and async, cold flows versus StateFlow and SharedFlow, and deterministic coroutine tests. USE FOR writing or reviewing Kotlin that declares a suspend function, launches a coroutine, uses a CoroutineScope, dispatcher, Job, Deferred, Flow, StateFlow, SharedFlow, Channel, or Mutex, bridges a callback API, or diagnosing a leaked, hung, or cancelled coroutine. DO NOT USE FOR non-coroutine Kotlin - see kotlin-language. DO NOT USE FOR deciding whether to parallelise for speed - see performance-discipline.
globs: **/*.kt
stack: kotlin
---

# Kotlin coroutines

## Structured concurrency

- Every coroutine is launched in a scope tied to the lifetime of what owns
  it. Never `GlobalScope`, and never a `CoroutineScope(...)` created inline
  and discarded.
- A class that creates a scope cancels it when it is done. Prefer taking a
  scope as a constructor parameter.
- A suspend function finishes its work before it returns. To run things in
  parallel inside one, use `coroutineScope { }` and `async` or `launch`
  within it; never launch into an outer scope from a suspend function.
- Use `supervisorScope` or a `SupervisorJob` only where one child's failure
  must not cancel its siblings, and then handle each child's failure.
- Never pass a `Job` as a context argument to `launch` or `withContext`. It
  breaks the parent-child link.

## Dispatchers

- A suspend function is main-safe: callable from the main thread without
  blocking it. It moves blocking or CPU work itself with `withContext`.
- Inject dispatchers. Never hardcode `Dispatchers.IO` or
  `Dispatchers.Default` in a class under test; take a `CoroutineDispatcher`
  or the project's dispatcher provider ([[testing-standards]]).
- `Dispatchers.IO` is for blocking I/O, `Dispatchers.Default` for CPU work.
  Never block a `Default` or main thread.
- No `runBlocking` in production code except at a true entry point such as
  `main`. Never inside a coroutine or on a UI thread.
- Never call `Thread.sleep` in a coroutine. Use `delay`.

## Cancellation

- Cancellation is cooperative. A loop doing CPU work calls `ensureActive()`
  or `yield()`.
- Never swallow `CancellationException`. A `catch (e: Exception)` or
  `runCatching` around a suspending call catches it: rethrow it, or catch the
  specific exception type instead.
- Clean up in `finally`. Suspending cleanup that must finish runs in
  `withContext(NonCancellable)`.
- Apply `withTimeout` or `withTimeoutOrNull` to a call that depends on
  something remote.

## Exceptions

- An exception in `launch` propagates to the parent and cancels the scope. An
  exception in `async` is thrown at `await`. Call `await` on every `Deferred`.
- Handle an expected failure with `try`/`catch` inside the coroutine. A
  `CoroutineExceptionHandler` is a last resort for logging at the root, and
  does nothing on a child ([[error-handling]]).

## Flow

- A `Flow` is cold: nothing runs until it is collected, and each collector
  runs it again. Return a `Flow` from a plain function, not a suspend one.
- Change the upstream context with `flowOn`. Never call `withContext` inside
  a `flow { }` builder to emit.
- State that has a current value is a `StateFlow`; one-off events are a
  `SharedFlow` or a `Channel`. Expose the read-only type and keep the mutable
  one private.
- Update a `MutableStateFlow` with `update { }`, which is atomic. Reading
  `value` and then assigning it is a race.
- Convert a cold flow with `stateIn` or `shareIn` in a scope that outlives
  the collectors, with a stated `SharingStarted` policy.
- Handle upstream errors with `catch`, placed after the operators it should
  cover. Do not wrap `collect` in `try`/`catch` for upstream failures.
- Bridge a callback API with `callbackFlow` and unregister in `awaitClose`,
  or with `suspendCancellableCoroutine` and `invokeOnCancellation`.

## Shared state

- Mutable state touched by several coroutines is confined to one dispatcher,
  held in a `StateFlow` or atomic, or guarded by a `Mutex`. Never
  `synchronized` around a suspending call.

## Testing

- Test with `runTest` and a `TestDispatcher`, injected. Never `runBlocking`
  with real delays, and never `delay` to wait for a result.
- A test that leaves a coroutine running fails. Cancel collectors, or collect
  in the test's background scope.

## Checklist

- [ ] No `GlobalScope`; every scope is cancelled by its owner.
- [ ] Suspend functions are main-safe and launch nothing that outlives them.
- [ ] Dispatchers are injected, not hardcoded.
- [ ] No `runBlocking` or `Thread.sleep` in a coroutine.
- [ ] `CancellationException` is never swallowed by a broad catch.
- [ ] Every `Deferred` is awaited; expected failures caught inside the coroutine.
- [ ] Mutable flows are private and exposed read-only; `StateFlow` updated with `update`.
- [ ] Callback bridges unregister on cancellation.
- [ ] Tests use `runTest` with an injected test dispatcher.
