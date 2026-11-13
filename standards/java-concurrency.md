---
name: java-concurrency
description: Java concurrency discipline - executors instead of raw threads, bounded pools that are shut down, safe publication and guarded shared state, concurrent collections and atomics used correctly, CompletableFuture without blocking or lost errors, interruption, and virtual threads. USE FOR writing or reviewing Java that starts a thread, uses an ExecutorService, CompletableFuture, virtual thread, lock, synchronized block, volatile field, atomic, or concurrent collection, shares mutable state between threads, or diagnosing a race, deadlock, hang, or thread leak. DO NOT USE FOR single-threaded language rules - see java-language. DO NOT USE FOR deciding whether to parallelise for speed - see performance-discipline.
globs: **/*.java
stack: java
---

# Java concurrency

## Shared state

- Every field reachable from two threads is immutable, confined to one
  thread, guarded by one stated lock, or an atomic or concurrent type. State
  which, in a comment at the declaration or with the repository's
  `@GuardedBy` annotation.
- Prefer immutable objects passed between threads. A `final` field of an
  immutable type needs no synchronisation.
- `volatile` gives visibility, not atomicity. `count++` on a volatile field is
  a race; use `AtomicInteger` or `LongAdder`.
- A check followed by an act is a race even on a concurrent collection. Use
  the atomic method: `computeIfAbsent`, `putIfAbsent`, `merge`,
  `compareAndSet`.
- Never publish `this` from a constructor: no listener registration and no
  thread start there.
- `SimpleDateFormat`, `HashMap`, `ArrayList`, and most classes are not
  thread-safe. Check before sharing an instance.

## Locks

- Hold a lock for the shared access only. Never across I/O, a callback, or a
  call into code you do not control.
- Take several locks in one documented order everywhere.
- A `Lock` is released in `finally`, immediately after the `lock()` call.
- Lock on a private final object, never on `this`, a class literal, a
  `String`, or a boxed value that other code can reach.
- `wait` and `Condition.await` run in a loop that rechecks the condition.
  Prefer a `BlockingQueue`, `CountDownLatch`, or `Semaphore` to hand-written
  wait and notify.

## Executors and threads

- Run tasks on an `ExecutorService`, not `new Thread`. Where the project has
  an injected or shared executor, use it.
- A pool for platform threads is bounded in threads and in queue length. An
  unbounded queue hides overload until memory runs out.
- Whoever creates an executor shuts it down: `shutdown`, then
  `awaitTermination`, then `shutdownNow`, or try-with-resources where the
  version allows. A leaked pool keeps the JVM alive.
- Name threads through a `ThreadFactory`, so a thread dump is readable
  ([[observability-standards]]).
- An exception thrown in a task submitted with `submit` is stored in the
  `Future` and lost unless someone calls `get`. Read every future, or handle
  the error inside the task ([[error-handling]]).
- Give every blocking wait a timeout.

## Interruption

- Interruption is the cancellation signal. A long-running task checks
  `Thread.interrupted()` and stops.
- Never swallow `InterruptedException`. Rethrow it, or restore the flag with
  `Thread.currentThread().interrupt()` and return.

## CompletableFuture

- Never block inside a stage: no `join`, `get`, or blocking I/O in
  `thenApply` and its siblings. Compose with `thenCompose` and `thenCombine`.
- Pass an executor to the `Async` variants that do real work. The default
  common pool is shared with the whole process and sized for CPU work.
- Every chain ends with error handling: `exceptionally`, `handle`, or
  `whenComplete`. A failed future nobody reads fails silently.
- Apply a timeout (`orTimeout`, `completeOnTimeout`) to any future that
  depends on something remote.

## Virtual threads

- Use virtual threads, where the Java version has them and the project uses
  them, for blocking I/O work: one per task, never pooled.
- Do not use them for CPU-bound work, and limit concurrency to a downstream
  resource with a `Semaphore`, not with pool size.
- Keep `ThreadLocal` use small and short-lived under virtual threads.

## Testing

- Never synchronise a test with `Thread.sleep`. Wait on the event with a
  latch, a future, or a polling assertion with a timeout
  ([[testing-standards]]).

## Checklist

- [ ] Every shared field is immutable, confined, guarded by a stated lock, or atomic.
- [ ] No check-then-act on shared state; compound updates use an atomic method.
- [ ] No lock held across I/O or foreign code; lock order documented.
- [ ] Every executor is bounded and shut down by its creator.
- [ ] Every future is read or handles its own error; every blocking wait has a timeout.
- [ ] `InterruptedException` is never swallowed.
- [ ] No blocking call inside a `CompletableFuture` stage.
- [ ] No `Thread.sleep` used to synchronise a test.
