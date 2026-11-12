---
name: unreal-cpp-conventions
description: Unreal Engine C++ conventions - confirming the engine version, type prefixes, the reflection macros and generated header, Unreal containers and string types instead of the standard library, no exceptions or RTTI, log categories, check and ensure, and module dependencies in Build.cs. USE FOR any first change in an Unreal project. USE FOR writing or reviewing Unreal C++ that declares a class, struct, enum, or interface, adds a UCLASS, USTRUCT, UENUM, UPROPERTY, or UFUNCTION, uses a string, name, text, or container, logs or asserts, includes an engine header, or edits a Build.cs or Target.cs file. DO NOT USE FOR pointer and object lifetime - see unreal-object-lifetime. DO NOT USE FOR assets, config, and what to commit - see unreal-project-files.
globs: **/Source/**/*.h,**/Source/**/*.cpp,**/*.Build.cs,**/*.Target.cs
stack: unreal
---

# Unreal C++ conventions

## Engine version

- Before your first change, read `EngineAssociation` in the `.uproject`. Use
  only the API of that engine version, and check each engine class, function,
  and macro you write against it. Most published examples are for another
  version; Unreal 4 and Unreal 5 differ in input, object pointers, and
  rendering.
- Never change the engine version or enable a plugin as a side effect. Both
  are the user's decision.

## Naming

- Prefix every type: `U` for `UObject` classes, `A` for actors, `F` for
  structs and plain classes, `E` for enums, `I` for interface classes with a
  matching `U` class, `T` for templates, `S` for Slate widgets. The build
  rejects a reflected type with the wrong prefix.
- Booleans are prefixed `b`. Types, functions, and variables are PascalCase.
- The file is named after the type it declares, without the prefix.

## Reflection

- A reflected header includes `"Name.generated.h"` as its last include, and
  each reflected type has `GENERATED_BODY()` as the first line of its body.
- A type, member, or function the editor, Blueprints, serialisation,
  replication, or the garbage collector must see carries `UCLASS`, `USTRUCT`,
  `UENUM`, `UPROPERTY`, or `UFUNCTION`. Anything without one is invisible to
  all of them.
- Give each specifier a reason. Expose to Blueprints only what Blueprints
  need: prefer `BlueprintReadOnly` over `BlueprintReadWrite`, and
  `EditDefaultsOnly` over `EditAnywhere`.
- A reflected enum is `UENUM() enum class E... : uint8`.
- A function bound to a dynamic delegate or a replication callback is a
  `UFUNCTION()`. Without it the binding fails silently at run time.

## Engine types, not the standard library

- Containers are `TArray`, `TMap`, `TSet`, and strings are `FString`. Do not
  use `std::vector`, `std::map`, `std::string`, or standard smart pointers in
  gameplay code. Standard algorithms and type traits are fine.
- `FName` for identifiers that are compared, `FText` for anything a player
  reads, `FString` for manipulation. Player-facing text is never an `FString`
  literal: it goes through `LOCTEXT` or `NSLOCTEXT`.
- Wrap string literals in `TEXT()`.
- Use the engine integer types (`int32`, `uint8`, `int64`) in reflected and
  serialised code.
- No exceptions and no RTTI: never `throw`, `try`, `dynamic_cast`, or
  `typeid`. Use `Cast<T>`, which returns null on failure, and report failure
  through the return value ([[error-handling]]).

## Logging and assertions

- Log through `UE_LOG` with a category declared for the module
  (`DECLARE_LOG_CATEGORY_EXTERN` and `DEFINE_LOG_CATEGORY`), never `LogTemp`
  in committed code, and never `printf` or `std::cout`
  ([[observability-standards]]).
- `check` is for a condition that can only fail through a programming error;
  it halts. `ensure` reports and continues; use it where the code can recover,
  and handle the failed branch. Neither validates data from a player, a file,
  or the network.
- An expression with a side effect never goes inside `check`, which is
  compiled out of shipping builds. Use `verify`.

## Modules

- A module lists every module whose headers it includes in its `Build.cs`:
  `PublicDependencyModuleNames` when its own public headers use them,
  `PrivateDependencyModuleNames` otherwise. A missing entry is a link error,
  not an include error.
- Public headers go in `Public/`, everything else in `Private/`. Mark a class
  or function used from another module with the module's `_API` macro.
- Include what you use, by the specific header. Never include `Engine.h` or
  `UnrealEd.h` wholesale, and forward-declare in headers where a pointer or
  reference is all that is needed.
- Editor-only code lives in an editor module or inside `#if WITH_EDITOR`. A
  runtime module must not depend on an editor module.

## Checklist

- [ ] Engine version read from the `.uproject`; every engine API used exists in it.
- [ ] Every type carries the correct prefix; booleans start with `b`.
- [ ] `.generated.h` is the last include; every reflected type has `GENERATED_BODY()`.
- [ ] Delegate-bound and replication callbacks are `UFUNCTION()`.
- [ ] Engine containers and strings throughout; player-facing text is `FText`.
- [ ] No exceptions, `dynamic_cast`, or `typeid`.
- [ ] Logs use a declared category; no side effects inside `check`.
- [ ] Every included module is listed in `Build.cs`; no runtime dependency on an editor module.
