---
name: unreal-gameplay-architecture
description: Unreal Engine gameplay structure - the split between C++ and Blueprints, what belongs in GameMode, GameState, PlayerState, PlayerController, and Pawn, components over inheritance, subsystems over singletons, tick off by default, data assets instead of hardcoded values, and the actor lifecycle. USE FOR designing or reviewing where Unreal gameplay logic lives, adding an actor, component, subsystem, game mode, controller, or data asset, deciding between C++ and Blueprint, enabling Tick, handling input, or wiring communication between actors. DO NOT USE FOR pointer and object lifetime - see unreal-object-lifetime. DO NOT USE FOR server authority and RPCs - see unreal-replication. DO NOT USE FOR layering outside the engine - see architecture-principles.
globs: **/Source/**/*.h,**/Source/**/*.cpp
stack: unreal
---

# Unreal gameplay architecture

## C++ and Blueprints

- Follow the split the project already has ([[existing-project-conventions]]).
  Absent one: systems, base classes, and anything performance-sensitive are
  C++; content, tuning values, and asset references live in a Blueprint
  subclass or a data asset.
- A C++ class meant to be configured in the editor is `Abstract` or
  `Blueprintable`, and exposes its hooks as `BlueprintImplementableEvent` or
  `BlueprintNativeEvent`. It never names a Blueprint subclass.
- C++ never references an asset by a path string. No `ConstructorHelpers`
  lookup and no `LoadObject` with a literal path: expose a `UPROPERTY` and
  assign the asset in the editor ([[no-hardcodes]]). A renamed asset breaks a
  path string with no compile error.
- Tuning values are `UPROPERTY(EditDefaultsOnly)` members, a `UDataAsset`, or
  a data table, never literals in code.

## Framework roles

Put each responsibility in the class the engine built for it:

| Class | Holds | Exists on |
|---|---|---|
| `AGameModeBase` | Rules, spawning, match flow | Server only |
| `AGameStateBase` | Match state every player sees | Server and all clients |
| `APlayerState` | One player's state others see: name, score | Server and all clients |
| `APlayerController` | One player's input, camera, and UI | Server and the owning client |
| `APawn`, `ACharacter` | The body in the world | Server and all clients |
| `UGameInstance` | State that survives level travel | Each process |

- Never read the game mode on a client; it is null there.
- State that must survive the pawn's death lives in the player state or the
  controller, not the pawn.
- UI reads state and sends requests. It holds no gameplay state and no rules.

## Composition

- Add behaviour with an `UActorComponent` before adding a subclass. A deep
  actor hierarchy that exists to share code is a component that was not
  written.
- A global service is a subsystem (`UGameInstanceSubsystem`,
  `UWorldSubsystem`, `ULocalPlayerSubsystem`), whose lifetime the engine
  manages. Never a static singleton and never a manager actor found by
  searching the level.
- Actors talk to each other through an interface, a delegate, or a component
  lookup, not by casting to a concrete class. A cast to a Blueprint-heavy
  class pulls every asset it references into memory.
- Never find a collaborator with `GetAllActorsOfClass` in gameplay code that
  runs repeatedly. Register on `BeginPlay`, or hold a reference.

## Tick

- `PrimaryActorTick.bCanEverTick` is `false` unless the class does per-frame
  work. Use a timer, a delegate, or an event for anything that is not.
- Per-frame work scales by `DeltaTime`. Nothing in `Tick` allocates, loads,
  searches the world, or casts repeatedly ([[performance-discipline]]).

## Lifecycle

- The constructor sets defaults and creates default subobjects. It has no
  world.
- `BeginPlay` is where gameplay starts; `EndPlay` undoes what `BeginPlay`
  did: timers cleared, delegates unbound, registrations removed. Call `Super`
  in every lifecycle override.
- Do not assume the order in which two actors receive `BeginPlay`. Do not
  assume the pawn, controller, or player state exists yet when another one
  starts; use the engine's possession and replication callbacks.

## Input

- Use the input system the project uses. In Unreal 5 that is Enhanced Input:
  actions and mapping contexts are assets assigned through properties, bound
  in `SetupPlayerInputComponent`. Never read keys directly.

## Checklist

- [ ] No asset referenced by a path string in C++; no tuning value as a literal.
- [ ] Each responsibility sits in its framework class; no client code reads the game mode.
- [ ] Shared behaviour is a component, and global services are subsystems.
- [ ] No concrete-class cast or world search where an interface, delegate, or held reference works.
- [ ] Tick disabled unless per-frame work exists; per-frame work uses `DeltaTime`.
- [ ] Everything bound or registered in `BeginPlay` is released in `EndPlay`; `Super` called.
