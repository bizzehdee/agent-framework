---
name: android-architecture
description: Android app structure - a UI layer and a data layer with an optional domain layer, ViewModels that expose one immutable UI state and hold no Android UI references, unidirectional data flow, repositories as the single source of truth, dependency injection, lifecycle-aware collection, and surviving configuration change and process death. USE FOR designing or reviewing where Android app logic lives, adding a screen, ViewModel, repository, data source, use case, or module, wiring dependency injection or navigation, holding or restoring state, or loading and caching data. DO NOT USE FOR composables, layouts, and accessibility - see android-ui. DO NOT USE FOR permissions, background work, and component security - see android-platform-safety. DO NOT USE FOR layering outside Android - see architecture-principles.
globs: **/*ViewModel.kt,**/*ViewModel.java,**/*Repository.kt,**/*Repository.java,**/*Activity.kt,**/*Activity.java,**/*Fragment.kt,**/*Fragment.java
stack: android
---

# Android architecture

Follow the architecture the project already has
([[existing-project-conventions]]). The rules below are the default where it
has none, and the invariants either way.

## Layers

- The UI layer shows state and reports events. The data layer owns
  application data and business rules. Add a domain layer of use cases only
  where logic is reused across ViewModels or is complex enough to need a
  name.
- Dependencies point one way: UI to domain to data. The data layer never
  imports a UI or ViewModel type ([[architecture-principles]]).
- An activity or fragment holds no business logic and no data access. It is
  the place the system creates and destroys at will.

## ViewModel

- A screen's state lives in a ViewModel, exposed as one immutable UI state
  object through an observable holder: a `StateFlow`, or the type the project
  already uses. The mutable holder is private.
- State flows down and events flow up. The UI calls a ViewModel function; it
  never mutates state itself, and the ViewModel never calls the UI.
- A ViewModel holds no `Activity`, `Fragment`, `View`, `Context`, or
  lifecycle reference. It outlives all of them, so holding one leaks it. Use
  an injected dependency for what needs a `Context`, and
  `AndroidViewModel` only where the project already does.
- Work started by a ViewModel runs in `viewModelScope`, or the project's
  equivalent, so it is cancelled when the screen is finished.
- Model loading, content, and error as explicit states of the UI state, not
  as separate flags that can disagree.
- A one-off effect such as navigation or a message is state the UI consumes
  and acknowledges, or follows the event mechanism the project already uses.

## Data layer

- A repository is the only way the rest of the app reads or changes a kind
  of data, and it exposes a single source of truth, normally the local
  database, updated from the network.
- Repository functions are main-safe: they move blocking work off the main
  thread themselves.
- Repositories return domain models. A network DTO or database entity never
  reaches the UI layer.
- Data that changes is exposed as an observable stream; a one-shot read is a
  suspend function or the project's asynchronous type.

## Dependency injection

- A class receives its dependencies through its constructor. It does not
  construct a repository, a database, or an HTTP client, and it does not
  reach for a singleton.
- Use the injection framework the project has. Do not add one, and do not
  mix two ([[dependency-management]]).
- Scope an object to the shortest lifetime that works. An
  application-scoped object must never hold an activity or a view.

## Lifecycle and state survival

- Collect a stream in the UI only while the lifecycle is at least `STARTED`
  (`repeatOnLifecycle`, `collectAsStateWithLifecycle`). A collector that runs
  in the background wastes work and can crash on a dead view.
- Rotation and other configuration changes destroy the activity. State that
  must survive them is in the ViewModel.
- The system can kill the process in the background. State the user would
  expect back, such as form input, a selection, or a scroll target, goes
  through `SavedStateHandle` or `rememberSaveable`. Keep it small: an ID,
  not the object.
- Never pass a large object between screens. Pass an ID and load from the
  repository.
- Never assume another screen, the application object's in-memory state, or
  a static field still holds data after the process was recreated.

## Checklist

- [ ] No business logic or data access in an activity, fragment, or composable.
- [ ] Each screen exposes one immutable UI state from a ViewModel; the mutable holder is private.
- [ ] No ViewModel holds a `Context`, view, or lifecycle reference.
- [ ] All reads and writes of a kind of data go through one repository.
- [ ] No DTO or database entity reaches the UI layer.
- [ ] Dependencies are constructor-injected through the project's existing framework.
- [ ] UI collection is lifecycle-aware.
- [ ] State the user expects back survives rotation and process death.
