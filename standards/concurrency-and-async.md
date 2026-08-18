---
name: concurrency-and-async
description: .NET asynchrony and concurrency - default to async for anything that waits, never block on async code, thread CancellationToken through, bound parallelism, and keep shared state safe. USE FOR writing or reviewing async and await code in .NET, adding a method that performs I/O, threading a CancellationToken, parallelising work, diagnosing a deadlock or a thread-safety bug, or choosing between Task and ValueTask. DO NOT USE FOR general throughput tuning - see performance-discipline.
globs: **/*.cs,**/*.fs,**/*.vb
stack: dotnet
---

# Concurrency and async (.NET)

## Default to async

If an operation waits on anything outside the CPU, it is async. Err on the side of
async.

- Every method performing I/O — network, database, file, queue, process — must be
  async and suffixed `Async`, returning `Task` or `Task<T>`. There is no size
  threshold below which sync I/O is acceptable.
- Async goes all the way down. A sync method calling an async one is where
  deadlocks and thread-pool starvation come from.
- Add an async method alongside an existing sync API; do not change a signature
  callers depend on ([[existing-project-conventions]]).
- Async frees a thread while waiting. It is not a speed optimisation — do not claim
  a gain you have not measured ([[performance-discipline]]).

## Never block on async

Prohibited: `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`, `Task.WaitAll` on
async work, and `async void` except for a genuine event handler. Each blocks a
thread and can deadlock where a synchronisation context exists. If you need one,
the caller should be async instead. Use `async Task Main` rather than blocking at
the entry point.

## Cancellation

- Accept a `CancellationToken` on every async method that can wait, pass it to
  every call that accepts one, and place it last. Default it only at a public
  boundary.
- Honour it. Accepting a token and ignoring it is worse than not accepting one,
  because it advertises support that does not exist.
- Call `token.ThrowIfCancellationRequested()` between iterations of a long loop.
- Cancellation is expected, not a failure. Do not catch `OperationCanceledException`
  and report it as an error ([[error-handling]]).

## Parallelism

- Run concurrent work with `await Task.WhenAll(...)`. Never start a task and forget
  it; an unobserved exception is a silent failure.
- Bound the concurrency. Unbounded fan-out exhausts connections or the thread pool.
  Use `Parallel.ForEachAsync` with `MaxDegreeOfParallelism`, or a `SemaphoreSlim`.
- `Task.Run` offloads CPU-bound work only. Never use it to make a sync API look
  async, and never inside a server request handler to fake async I/O.
- Prefer `IAsyncEnumerable<T>` with `await foreach` over materialising a whole
  sequence ([[performance-discipline]]).

## Shared state

- Never `await` inside a `lock`. Use `SemaphoreSlim.WaitAsync` for async mutual
  exclusion.
- Prefer immutability. A value that cannot change needs no protection.
- Use `Interlocked` for counters and the concurrent collections for shared
  collections. Do not hand-roll locking where a concurrent type exists.
- A static mutable field is shared across every request. Treat it as a defect
  unless immutable or explicitly synchronised.

## Libraries and time

- In library code, use `ConfigureAwait(false)`, unless the project's convention or
  analyser configuration says otherwise. Application and ASP.NET Core code does not
  need it.
- Never use `Thread.Sleep` in async code. Never use a real `Task.Delay` duration in
  a test — inject `TimeProvider` and control it ([[testing-standards]]).

## Checklist

- [ ] Every I/O method is async and named `Async`.
- [ ] No `.Result`, `.Wait()`, `.GetAwaiter().GetResult()`, or `async void`.
- [ ] A `CancellationToken` is accepted, passed down, and honoured.
- [ ] Concurrency is bounded.
- [ ] No `await` inside a `lock`.
- [ ] Shared mutable state is immutable, concurrent, or synchronised.
