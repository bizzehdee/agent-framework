---
name: godot-scene-architecture
description: How a Godot 4 project divides responsibility between scenes, nodes, autoloads, and resources, and how its code behaves at runtime - call down and signal up, no hard-coded node paths, autoloads only for global services, duplicating shared resources before mutating them, the frame loop, the main-thread rule for the scene tree, freeing nodes safely, and server authority in multiplayer. USE FOR designing or reviewing a scene, a node hierarchy, or communication between nodes. USE FOR adding an autoload or a custom Resource. USE FOR writing _process or _physics_process code, threading or async work in a Godot project, or freeing a node. USE FOR writing an RPC or multiplayer authority check. DO NOT USE FOR script syntax, typing, or naming - see godot-scripting. DO NOT USE FOR editing .tscn or .tres text - see godot-project-files.
globs: **/*.gd,**/*.cs,**/*.tscn
stack: godot
---

# Godot scene architecture

## Scenes are components

- A scene is a self-contained component with one purpose ([[code-quality]]). It
  works when instanced alone, given only what its exported members supply.
- One script per scene root. A child node gets its own script only when it has
  behaviour of its own.
- Compose behaviour from child scenes before reaching for inheritance
  ([[architecture-principles]]).

## Call down, signal up

- A node calls methods on its own children, and only its children.
- A node tells its parent or siblings something by emitting a signal. The parent,
  or the scene that instances both, connects it.
- Never walk up the tree: no `get_parent()` chains and no `../` paths. Never use an
  absolute path such as `/root/Main/Player`.
- Reach a child through a scene-unique name (`%Name`) or an exported node
  reference. A path string that breaks when a node is renamed is a defect.
- Broadcast to many unrelated nodes through a group:
  `get_tree().call_group("enemies", "alert")`.

## Autoloads

An autoload is a global, and the rules for catch-all units apply
([[code-quality]]).

- Add an autoload only for a service the whole game needs for its whole lifetime:
  save data, audio, scene transitions, settings. Name it for that one service.
- Never create `Global`, `Game`, or `Utils` autoloads that hold whatever has no
  other home.
- Never keep per-scene state in an autoload. It survives the scene and leaks into
  the next one.

## Resources

- Hold data in a custom `Resource` with typed exported fields, not in a node with
  no behaviour.
- A loaded resource is shared by every user of it. Mutating one changes it
  everywhere: damaging one enemy damages all of them. Before mutating per-instance
  state, call `duplicate()`, or set `resource_local_to_scene`.
- Load a resource used at startup with `preload`. Load a large one off the frame
  with `ResourceLoader.load_threaded_request`.

## The frame loop

- Movement and physics go in `_physics_process`. Everything else per-frame goes in
  `_process`. Scale every rate by `delta`.
- Allocate nothing and look up no node inside a per-frame callback.
- Turn off processing a node does not need: `set_process(false)`,
  `set_physics_process(false)`. Prefer a signal or a `Timer` to polling.
- Measure with the profiler before optimising ([[performance-discipline]]).

## Threads and async

The active scene tree is not thread-safe. Only the main thread may touch a node in
the tree.

- Work on another thread uses only plain data. Hand results back with
  `call_deferred` or `set_deferred`, or `CallDeferred` and
  `Callable.From(...).CallDeferred()` in C#.
- In GDScript, run background work with `WorkerThreadPool`.
- In C#, `await` resumes on the main thread through Godot's synchronisation
  context. Never use `ConfigureAwait(false)` in code that touches a Godot object,
  and never touch a node from inside `Task.Run`. This overrides
  [[concurrency-and-async]] where they conflict.
- Wait for an engine event with `await` on the signal, or `ToSignal` in C#. Never
  block the main thread waiting for anything.

## Freeing nodes

- Free a node with `queue_free()`, never `free()`, unless it is outside the tree.
- A reference to a node can outlive the node. Before using one that may have been
  freed, check `is_instance_valid()`, or `GodotObject.IsInstanceValid()` in C#.

## Multiplayer

- The server holds authority. Never trust a client's position, inventory, score,
  or damage; the client requests and the server decides ([[secure-engineering]]).
- An RPC callable by any peer validates its sender, from
  `multiplayer.get_remote_sender_id()`, and every argument before acting.
- Set authority explicitly with `set_multiplayer_authority()`; never assume it.

## Checklist

- [ ] Every scene runs when instanced alone.
- [ ] No `get_parent()` chain, `../` path, or absolute `/root/` path.
- [ ] Children are called; parents are signalled.
- [ ] Every autoload is one named global service.
- [ ] No shared resource mutated without `duplicate()` or `resource_local_to_scene`.
- [ ] No allocation or node lookup inside a per-frame callback.
- [ ] No node touched off the main thread; no `ConfigureAwait(false)` near Godot objects.
- [ ] Every possibly freed reference checked before use.
- [ ] Every RPC validates its sender and arguments.
