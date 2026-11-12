---
name: unreal-replication
description: Unreal Engine multiplayer replication - server authority over all gameplay state, replicated properties with lifetime registration and OnRep callbacks, server, client, and multicast RPCs with validation, ownership, and what never to trust from a client. USE FOR writing or reviewing Unreal C++ for a multiplayer game that replicates a property or actor, declares a Server, Client, or NetMulticast function, checks HasAuthority or a net role, spawns or destroys a replicated actor, or diagnosing state that differs between server and client. DO NOT USE FOR single-player projects with no networking. DO NOT USE FOR which framework class holds which state - see unreal-gameplay-architecture. DO NOT USE FOR pointer and object lifetime - see unreal-object-lifetime.
globs: **/Source/**/*.h,**/Source/**/*.cpp
stack: unreal
---

# Unreal replication

Applies only where the project is multiplayer. Do not add replication to a
single-player project.

## Authority

- The server owns gameplay state. Health, inventory, score, position of
  anything contested, and every rule decision change only on the server.
- Guard state changes with `HasAuthority()`. Code that runs on both sides and
  mutates gameplay state without that guard is a defect.
- A client may predict for responsiveness, and must accept the server's
  correction.
- Spawn and destroy replicated actors on the server only.

## Replicated properties

- A replicated member is `UPROPERTY(Replicated)` or
  `UPROPERTY(ReplicatedUsing=OnRep_Name)`, and is registered in
  `GetLifetimeReplicatedProps` with `DOREPLIFETIME` or a conditional form. A
  property missing from that function never replicates, with no error.
- The actor sets `bReplicates = true`; a replicated component calls
  `SetIsReplicatedByDefault(true)`.
- An `OnRep_` function is a `UFUNCTION()`. It runs on clients only: when the
  server needs the same reaction, call it explicitly after setting the value.
- State that a late-joining client must see is a replicated property, never a
  multicast RPC. An RPC reaches only the clients connected when it is sent.
- Do not assume the order in which two replicated properties, or two actors,
  arrive on a client. Handle each arriving first.
- Replicate the minimum: use `COND_OwnerOnly`, `COND_SkipOwner`, and the other
  conditions rather than sending everything to everyone
  ([[performance-discipline]]).

## RPCs

- `UFUNCTION(Server, Reliable)` runs on the server and can only be called by
  the client that owns the actor. A call from a non-owner is dropped silently.
- `UFUNCTION(Client, Reliable)` runs on the owning client.
  `UFUNCTION(NetMulticast, Unreliable)` runs everywhere when called on the
  server.
- Implement each as `Name_Implementation`.
- `Reliable` is for events that must arrive: a purchase, a death. Anything
  sent every frame or purely cosmetic is `Unreliable`. Reliable calls sent
  every tick overflow the buffer and disconnect the client.
- Use a multicast for a one-off cosmetic event, such as an effect or a sound,
  and nothing else.

## Never trust the client

- Every Server RPC validates its arguments on the server as hostile input:
  range, ownership, cooldown, distance, and whether the action is possible
  now ([[secure-engineering]]). Use `WithValidation` where the project does,
  and reject rather than clamp.
- A Server RPC carries intent ("fire", "use item 3"), never a result ("deal 40
  damage", "set health to 100"). The server computes the result.
- Never send a client state it must not know, such as another player's hidden
  information. Anything replicated to a client can be read there.

## Testing

- Test multiplayer code with a dedicated server and at least two clients, not
  only as a listen-server host, where authority and the local player are the
  same process and most replication bugs are invisible
  ([[testing-standards]]).

## Checklist

- [ ] Gameplay state changes only on the server, behind `HasAuthority()`.
- [ ] Every replicated property is registered in `GetLifetimeReplicatedProps`.
- [ ] Every `OnRep_` function is a `UFUNCTION()` and is called explicitly on the server where needed.
- [ ] Persistent state is a replicated property, never a multicast.
- [ ] Every Server RPC validates its arguments and carries intent, not results.
- [ ] Nothing sent per frame is `Reliable`.
- [ ] Tested with a dedicated server and two clients, or reported as untested.
