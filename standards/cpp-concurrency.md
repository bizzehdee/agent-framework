---
name: cpp-concurrency
description: C++ threading discipline - every shared mutable variable guarded or atomic, RAII locks in a fixed order, joined threads with a stop path, condition variables waited with a predicate, atomics at the default ordering unless justified, and ThreadSanitizer on the tests. USE FOR writing or reviewing C++ that starts a thread, task, or thread pool, uses a mutex, atomic, condition variable, future, or coroutine, shares state between threads, or diagnosing a data race, deadlock, hang, or intermittent failure. DO NOT USE FOR lifetime of objects that are not shared between threads - see memory-and-resource-safety. DO NOT USE FOR choosing whether to parallelise for speed - see performance-discipline.
globs: **/*.cc,**/*.cpp,**/*.cxx,**/*.h,**/*.hpp
stack: c-cpp
---

# C++ concurrency

## Shared state

- A data race is undefined behaviour: two threads touching the same variable,
  at least one writing, with no synchronisation. It is not a stale read. Every
  variable reachable from two threads is immutable after publication, guarded
  by a named mutex, or `std::atomic`.
- State which mutex guards which data, in a comment at the declaration or with
  the compiler's thread-safety annotations where the repository uses them.
- Prefer not sharing. Give each thread its own data and pass results by value
  or through a queue.
- A `const` member function of a type used from several threads is safe to
  call concurrently. `mutable` members in such a type are guarded or atomic.
- A function-local static initialises thread-safely. Its later use is not
  protected by that.

## Locks

- Lock only through RAII: `std::scoped_lock`, `std::unique_lock`,
  `std::shared_lock`. Never call `lock()` and `unlock()` directly.
- Take several mutexes in one `std::scoped_lock`, or in one documented order
  everywhere. Two orders is a deadlock waiting for the right timing.
- Never hold a lock while calling code you do not control: a callback, a
  virtual function, a user-supplied functor, or blocking I/O.
- Keep the critical section to the shared access itself. Compute outside it.
- Wait on a condition variable with a predicate, always. The predicate reads
  state guarded by the same mutex, and that state is changed under the mutex
  before the notify.

## Threads and tasks

- Use `std::jthread` where the standard in use has it. A `std::thread` is
  joined on every path, including the exceptional one. Never `detach`.
- Every thread has a stop path: a `std::stop_token` or an equivalent flag,
  checked in its loop and woken out of any wait. Shutdown joins it.
- An exception must not escape a thread function; it terminates the process.
  Catch at the top of the function and report it ([[error-handling]]).
- Whatever a thread or task references outlives it. Capture by value or
  transfer ownership in.
- The future returned by `std::async` blocks in its destructor. Keep it and
  read it; never discard it.

## Atomics

- An atomic makes one operation atomic, not a sequence. A check followed by an
  act on an atomic is still a race; use compare-exchange or a mutex.
- Use the default `memory_order_seq_cst`. Any weaker ordering carries a comment
  proving it correct, and exists because a measurement required it
  ([[performance-discipline]]).
- Do not write a lock-free structure where a mutex or an existing library type
  will do.

## Testing

- Tests for concurrent code run under ThreadSanitizer in CI
  ([[memory-and-resource-safety]]). A report is a failing build.
- Never fix a race or make a test pass with a sleep. Synchronise on the event
  ([[testing-standards]]).

## Checklist

- [ ] Every variable shared between threads is immutable, mutex-guarded, or atomic, and the guard is stated.
- [ ] All locking is RAII; multiple mutexes are taken together or in one documented order.
- [ ] No lock held across a callback, virtual call, or blocking I/O.
- [ ] Every condition variable wait has a predicate.
- [ ] Every thread is joined and has a stop path; none is detached.
- [ ] Every non-default memory order carries its justification.
- [ ] Concurrent tests pass under ThreadSanitizer with no sleeps for synchronisation.
