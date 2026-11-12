---
name: unreal-object-lifetime
description: Unreal Engine object lifetime under garbage collection - UPROPERTY on every stored UObject pointer, TObjectPtr, weak and soft references, NewObject and CreateDefaultSubobject instead of new, validity checks, and smart pointers for non-UObject types only. USE FOR writing or reviewing Unreal C++ that declares a member pointing at a UObject, actor, or component, creates, spawns, or destroys an object or actor, stores an object in a container, struct, delegate, lambda, or timer, references an asset, or diagnosing a crash on a stale or garbage-collected pointer. DO NOT USE FOR naming, containers, strings, and logging - see unreal-cpp-conventions. DO NOT USE FOR which class owns which gameplay responsibility - see unreal-gameplay-architecture.
globs: **/Source/**/*.h,**/Source/**/*.cpp
stack: unreal
---

# Unreal object lifetime

Unreal garbage-collects every `UObject`. General C++ ownership rules (RAII,
`std::unique_ptr`) do not apply to them, and applying them is a defect.

## Keeping an object alive

- Every member that stores a `UObject` pointer is a `UPROPERTY()`. The
  collector cannot see a pointer without it, frees the object, and leaves the
  member dangling.
- Declare such members as `TObjectPtr<T>` in headers. Use raw `T*` for
  function parameters, return values, and locals.
- A container of objects is a `UPROPERTY()` too: `TArray<TObjectPtr<T>>`,
  `TMap`, `TSet`. A `USTRUCT` holding object pointers marks each one
  `UPROPERTY()`, and every member that stores the struct is one as well.
- A non-`UObject` class that must hold a `UObject` derives from
  `FGCObject` and reports it in `AddReferencedObjects`, or holds a
  `TStrongObjectPtr`. Never a bare pointer.
- A reference that must not keep its target alive is a `TWeakObjectPtr`. Use
  it for anything captured by a lambda, timer, delegate, or async task that
  can run after the target is destroyed.

## Creating and destroying

- Create objects with `NewObject<T>(Outer)`. Create a component or subobject
  in a constructor with `CreateDefaultSubobject<T>(TEXT("Name"))`, and only in
  a constructor. Spawn actors with `UWorld::SpawnActor`.
- Never `new`, `delete`, `malloc`, or `free` a `UObject`, and never put one in
  a `TUniquePtr`, `TSharedPtr`, or a standard smart pointer.
- Destroy an actor with `Destroy()` and a component with
  `DestroyComponent()`. To release any other object, clear the references to
  it; the collector frees it.
- A constructor runs for the class default object, with no world. It sets
  defaults and creates subobjects, nothing else. Gameplay setup belongs in
  `BeginPlay` or later.

## Checking validity

- A destroyed object stays non-null until collected. Check with
  `IsValid(Object)`, not a null test, before using any object that another
  system can destroy.
- Check a `TWeakObjectPtr` with `IsValid()` or take `Get()` once and test the
  result. Do not test and then dereference separately across a call that can
  destroy it.
- `GetWorld()`, `GetOwner()`, and every `Cast<T>` result can be null. Check
  before use.

## Non-UObject types

- Plain C++ types and `F` structs that are not reflected use `TUniquePtr`,
  `TSharedPtr`, and `TSharedRef`, created with `MakeUnique` and `MakeShared`.
  One owner by default; shared only when ownership is shared.
- Bind a delegate or timer to a `UObject` with the object-aware forms
  (`AddUObject`, `AddDynamic`, `BindUObject`, `CreateWeakLambda`), never a raw
  lambda capturing `this`. Unbind in `EndPlay` what was bound in `BeginPlay`.

## Assets

- A hard object reference loads its target whenever the referencing object
  loads. Reference an asset that is not always needed with `TSoftObjectPtr`
  or `TSoftClassPtr`, and load it asynchronously through the streamable
  manager or asset manager.
- Never block the game thread on a synchronous load during gameplay
  ([[performance-discipline]]).

## Checklist

- [ ] Every stored `UObject` pointer, and every container or struct of them, is a `UPROPERTY()`.
- [ ] No `new`, `delete`, or smart pointer on a `UObject`.
- [ ] Constructors only set defaults and create default subobjects.
- [ ] Objects another system can destroy are checked with `IsValid` before use.
- [ ] Lambdas, timers, and delegates hold objects weakly and are unbound in `EndPlay`.
- [ ] Optional assets are soft references loaded asynchronously.
