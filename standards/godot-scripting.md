---
name: godot-scripting
description: Writing Godot 4 scripts in GDScript and C# - static typing, the official naming and member order, signals declared and connected in Godot 4 syntax, exported and onready members, the C# partial class and generated name rules, and choosing between Godot and .NET collections. USE FOR writing, reviewing, or refactoring a .gd file or a C# script in a Godot project. USE FOR declaring, emitting, or connecting a signal. USE FOR exposing a value to the inspector or caching a node reference. USE FOR configuring GDScript warnings. DO NOT USE FOR how nodes and scenes divide responsibility or communicate - see godot-scene-architecture. DO NOT USE FOR editing .tscn or .tres files or confirming the engine version - see godot-project-files.
globs: **/*.gd,**/*.cs
stack: godot
---

# Godot scripting

Use only the API of the project's Godot 4 minor version ([[godot-project-files]]).
Follow the official GDScript style guide or the C# style guide for Godot; where
one conflicts with another standard, the style guide wins, with the reason stated
([[existing-project-conventions]]).

## GDScript

### Static typing

- Type every variable, parameter, and return value: `var speed: float = 4.0`,
  `func damage(amount: int) -> void:`. Use `:=` only when the type is obvious from
  the right-hand side.
- Type collections: `Array[Enemy]`, not `Array`.
- Set `debug/gdscript/warnings/untyped_declaration` to Error in `project.godot`, so
  an untyped declaration fails to compile. In an existing project, propose it; do
  not change it uninvited.
- Give every reusable script a `class_name`, and refer to it by type, not by path
  or string.
- Never call a method or read a property by name: `call("…")`, `get("…")`,
  `has_method("…")`. Use the type, cast with `as`, and check for `null`.

### Naming and order

| Item | Case | Example |
|---|---|---|
| File | snake_case | `player_controller.gd` |
| `class_name`, node name | PascalCase | `PlayerController` |
| Function, variable | snake_case | `apply_damage`, `max_health` |
| Private member | leading underscore | `_velocity` |
| Signal | snake_case, past tense | `health_changed` |
| Constant, enum member | CONSTANT_CASE | `MAX_SPEED`, `State.IDLE` |
| Enum name | PascalCase | `State` |

Order members as the official GDScript style guide lists them: annotations,
`class_name`, `extends`, doc comment, signals, enums, constants, `@export`
variables, other variables, `@onready` variables, built-in virtual methods,
public methods, private methods, inner classes.

### Signals, exports, and node references

- Declare signals typed: `signal health_changed(new_value: int)`. Emit with
  `health_changed.emit(value)`. Connect with a callable:
  `button.pressed.connect(_on_button_pressed)`. Never pass a method name as a
  string.
- Wait with `await`: `await get_tree().create_timer(1.0).timeout`.
- Expose a tunable value with a typed `@export` instead of a constant a designer
  must edit code to change ([[no-hardcodes]]).
- Cache node references in typed `@onready` variables:
  `@onready var _label: Label = %ScoreLabel`. Never look a node up by path inside
  `_process` or `_physics_process`.

## C#

- A script class is `partial`, inherits a Godot type, and has the same name as its
  file: `public partial class PlayerController : CharacterBody3D` in
  `PlayerController.cs`. Godot cannot attach it otherwise.
- Follow .NET naming. Godot's own API is PascalCase in C#: `_Ready`,
  `_PhysicsProcess`, `GetNode<T>()`.
- Declare a signal as `[Signal] public delegate void HealthChangedEventHandler(int newValue);`.
  The delegate name ends in `EventHandler`.
- Use the generated name classes, never string literals: `SignalName.HealthChanged`,
  `MethodName.Die`, `PropertyName.Speed`.
- Expose a tunable value with `[Export]`. Cache node references in `_Ready`, typed:
  `_label = GetNode<Label>("%ScoreLabel");`.
- Use .NET collections inside your own code. Use `Godot.Collections.Array` and
  `Godot.Collections.Dictionary` only where a Godot API or an `[Export]` requires
  them; each crossing of the engine boundary marshals.
- A lambda that captures variables is not disconnected when its node is freed.
  Connect to a method of the receiving node instead, or store the delegate and
  disconnect it with `-=` in `_ExitTree`.

## Checklist

- [ ] Every GDScript declaration typed; no untyped `Array`.
- [ ] No method or property accessed by string name, in either language.
- [ ] Names and member order follow the official style guide.
- [ ] Signals declared, emitted, and connected in Godot 4 syntax.
- [ ] No node lookup by path inside a per-frame callback.
- [ ] Every C# script class is `partial` and named after its file.
- [ ] No capturing lambda connected to a signal without a matching disconnect.
