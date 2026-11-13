---
name: android-ui
description: Android UI discipline for Jetpack Compose and Views - stateless composables with hoisted state, remember and side-effect APIs used correctly, stable parameters and keyed lists, view binding and fragment view lifecycle, theming, accessibility, and screens that work across sizes, font scales, and dark mode. USE FOR writing or reviewing a composable, an XML layout, a fragment or activity's view code, a custom view, a list or lazy list, a theme, or navigation between screens, and for diagnosing excess recomposition, a leaked view, or a layout that breaks on another device. DO NOT USE FOR where state and logic live - see android-architecture. DO NOT USE FOR strings and resource files - see android-project-files.
globs: **/ui/**/*.kt,**/res/layout/**/*.xml,**/*Screen.kt,**/*Fragment.kt
stack: android
---

# Android UI

Use the toolkit the screen already uses. Do not introduce Compose into a View
project, or Views into a Compose project, without approval
([[existing-project-conventions]]).

## Compose: state

- A composable is a function of its parameters. It takes state in and sends
  events out through lambdas; it does not own business state or call a
  repository ([[android-architecture]]).
- Hoist state to the lowest common owner. Provide a stateless composable that
  takes values and callbacks, and keep the stateful wrapper thin.
- Pass a composable the values it needs, not a ViewModel. A composable that
  takes a ViewModel cannot be previewed or reused.
- State created in a composable is wrapped in `remember`, or
  `rememberSaveable` when it must survive rotation and process death. A
  `mutableStateOf` without `remember` resets on every recomposition.
- Never write to state during composition. Composition can run many times,
  in any order, and be discarded.

## Compose: side effects

- Anything that is not building UI runs in an effect: `LaunchedEffect` for
  suspending work, `DisposableEffect` for something that needs cleanup,
  `rememberCoroutineScope` for work started by an event.
- An effect's keys are every value it reads that can change. `Unit` or `true`
  as a key means "run once, and never see a newer value"; use it only when
  that is intended, with `rememberUpdatedState` for a callback.
- Collect a flow with `collectAsStateWithLifecycle`.

## Compose: performance and structure

- Every item in a lazy list has a stable, unique `key`. Never the index.
- Pass immutable or stable types as parameters. A plain `List` or a class
  with `var` properties makes a composable recompose every time; use the
  project's immutable collections or a stable wrapper.
- Read fast-changing state as late as possible: a lambda modifier
  (`Modifier.offset { }`) or `derivedStateOf`, not a parameter at the top of
  the screen.
- No sorting, filtering, or allocation of large objects in a composable body
  without `remember` ([[performance-discipline]]).
- Every reusable composable takes a `modifier: Modifier = Modifier` as its
  first optional parameter and applies it to its root element once.
- Every screen-level composable has a `@Preview` with sample data.
- Colours, type, and shapes come from the theme (`MaterialTheme`), never
  literals.

## Views

- Access views through view binding. Never `findViewById` in new code, and
  never Kotlin synthetics.
- A fragment's view dies before the fragment does. Clear the binding in
  `onDestroyView`, and observe with `viewLifecycleOwner`, never the fragment
  itself.
- A `RecyclerView` adapter uses `ListAdapter` with a `DiffUtil` callback, or
  the project's equivalent. Never `notifyDataSetChanged` for a partial
  change.
- Never hold a `View`, `Activity`, or `Fragment` in a static field, a
  singleton, or a callback that outlives it.
- Keep layouts shallow. Use `ConstraintLayout` rather than nesting.

## Every screen

- Nothing that blocks runs on the main thread: no disk, network, or database
  call. The frame budget is a few milliseconds.
- Every interactive element is at least 48dp in each dimension and has a
  label a screen reader can speak: `contentDescription` for a meaningful
  image, `null` for a decorative one. Never convey state by colour alone.
- The screen works at 200% font scale, in dark theme, in landscape, and on a
  narrow phone and a tablet. No fixed height on a container of text.
- Respect system bars and the keyboard with window insets, not fixed
  padding.
- Handle back through the back-handling API the project uses, never by
  overriding a deprecated callback.
- Loading, empty, and error states are designed, not left blank.

## Checklist

- [ ] Composables take state and callbacks, not a ViewModel; state is hoisted.
- [ ] Composable state is in `remember` or `rememberSaveable`; nothing writes state during composition.
- [ ] Side effects run in effect APIs with complete keys.
- [ ] Lazy list items have stable unique keys; parameters are stable types.
- [ ] Fragment bindings cleared in `onDestroyView`; observers use `viewLifecycleOwner`.
- [ ] Nothing blocking on the main thread.
- [ ] Touch targets at least 48dp; meaningful images labelled.
- [ ] Screen checked at large font scale, dark theme, and another size, or reported as unchecked.
