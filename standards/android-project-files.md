---
name: android-project-files
description: Android project configuration handled without Android Studio - confirming SDK levels, the Android Gradle Plugin, and the UI toolkit before writing code, the manifest and exported components, resources instead of literals, signing keys and secrets kept out of the repository, R8 rules, and validating a change with Gradle build, lint, and tests. USE FOR any first change in an Android project. USE FOR editing AndroidManifest.xml, an Android module's build file, a resource file, a ProGuard or R8 rules file, or a signing or build-variant configuration. USE FOR adding an activity, service, receiver, provider, permission, or module, and for setting up Android CI. DO NOT USE FOR general Gradle rules - see jvm-build-and-dependencies. DO NOT USE FOR app structure - see android-architecture. DO NOT USE FOR screens and layouts - see android-ui.
globs: **/AndroidManifest.xml,**/res/**/*.xml,**/proguard-rules.pro,**/consumer-rules.pro,**/local.properties
stack: android
---

# Android project files

## Establish the project first

Before your first change, read the app module's build file and note:

- `minSdk`, `targetSdk`, and `compileSdk`, and the Android Gradle Plugin
  version. Use only platform APIs available at `minSdk`, or guard a newer one
  with a `Build.VERSION.SDK_INT` check or an AndroidX compat class.
- Whether the UI is Jetpack Compose, Views, or both, and whether the code is
  Kotlin, Java, or both. Follow what is there
  ([[existing-project-conventions]]).
- Never change `minSdk`, `targetSdk`, `compileSdk`, the plugin version, or
  the application ID as a side effect. Each changes who can install the app
  or how the platform treats it, and is the user's decision.
- Most published Android examples are years old. Check each platform and
  library API you write against the versions the project uses, and never
  write against a deprecated one (`AsyncTask`, `startActivityForResult`,
  `onBackPressed`, the support library, Kotlin synthetics).

## Manifest

- Every activity, service, receiver, and provider is declared, with
  `android:exported` set explicitly. `exported="true"` only for a component
  another app must start, and then it validates everything it receives
  ([[android-platform-safety]]).
- Request the fewest permissions that work. Adding one is a user-visible
  change: say so in the report.
- Library modules declare only what they need; the app manifest is where
  conflicts are resolved.

## Resources

- No user-visible string in code or layout. It goes in `strings.xml`, with
  placeholders (`%1$s`) and `plurals` rather than concatenation
  ([[no-hardcodes]]).
- Colours, dimensions, and styles come from the theme and resource files,
  never literals at the use site. Sizes are `dp`, text is `sp`.
- A resource added to the default configuration is added to every qualified
  variant that overrides its siblings, or the app crashes or falls back
  inconsistently. Never delete a resource without searching for its uses in
  code, XML, and the manifest.
- Never edit generated code: `R`, `BuildConfig`, binding classes, or anything
  under `build/`.

## Secrets and signing

- Never commit a keystore, a signing password, `local.properties`, or a
  `google-services.json` or API key the repository does not already track
  ([[secure-engineering]]). Signing values come from environment variables or
  an untracked properties file.
- Anything compiled into the APK can be extracted, including `BuildConfig`
  fields and string resources. A secret the app must not reveal stays on a
  server.
- `debuggable`, cleartext traffic, and test-only endpoints never reach a
  release build type.

## Shrinking

- Release builds run R8. Code reached only by reflection, serialisation, or
  JNI needs a keep rule: add the narrowest one, in the module that owns the
  code, and prefer the library's own consumer rules.
- Never fix a release-only crash with a broad `-keep class **` or by turning
  shrinking off.

## Validate

Android Studio is how a human sees a broken project; without it, run Gradle.

- After any change, run the wrapper's build, lint, and unit tests for the
  affected variant (`./gradlew :app:assembleDebug`, `lint`, `test`) and read
  the output. A lint error is a failure; do not add to the lint baseline or
  suppress a check without approval ([[testing-standards]]).
- Instrumented and UI tests need a device or emulator. If none is available,
  say that the change was built but not run on a device. Do not describe it
  as working.
- A change that touches R8 rules, reflection, or a build type is verified
  against a release build, not only debug.

## Checklist

- [ ] SDK levels, plugin version, UI toolkit, and language read before the first change; none changed as a side effect.
- [ ] Every API used exists at `minSdk` or is guarded; none is deprecated.
- [ ] Every component declared with explicit `android:exported`.
- [ ] No user-visible string, colour, or dimension literal in code or layout.
- [ ] No keystore, password, or untracked key file committed; no secret compiled into the app.
- [ ] Keep rules are narrow; shrinking not disabled.
- [ ] Gradle build, lint, and unit tests pass, and the report says whether it ran on a device.
