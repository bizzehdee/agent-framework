---
name: android-platform-safety
description: Android platform rules that crash, drain, or expose an app when broken - runtime permissions requested in context, exported components and intents treated as hostile input, immutable PendingIntents, WorkManager and typed foreground services for background work, scoped and encrypted storage, network security, and WebView hardening. USE FOR writing or reviewing Android code that requests a permission, handles an incoming Intent or deep link, declares an exported component, creates a PendingIntent or notification, runs work in the background, uses a service, alarm, or broadcast receiver, reads or writes files, preferences, or a ContentProvider, stores a credential or token, or configures a WebView or network client. DO NOT USE FOR app structure - see android-architecture. DO NOT USE FOR threats that are not Android-specific - see secure-engineering.
globs: **/AndroidManifest.xml,**/*Service.kt,**/*Service.java,**/*Receiver.kt,**/*Receiver.java,**/*Worker.kt,**/*Worker.java,**/*Provider.kt,**/*Provider.java
stack: android
---

# Android platform safety

## Permissions

- Request a dangerous permission at the moment the feature needs it, through
  the Activity Result API. Never at start-up, and never several at once
  without a reason for each.
- Check the permission before every use, not once. The user can revoke it at
  any time, and the system revokes it from unused apps.
- Handle denial: the feature degrades and says why. Never loop the request,
  and never block the whole app on an optional permission.
- Prefer an API that needs no permission: the photo picker over storage
  access, a system intent over direct camera or contact access.
- Background location, exact alarms, all-files access, and similar
  restricted permissions are a product and store-policy decision. Never add
  one without approval.

## Components and intents

- Every `Intent` an exported activity, service, receiver, or provider
  receives is hostile input. Validate the action, each extra, and each URI
  before use; never use one to choose a file path, a class to launch, or a
  URL to load without an allowlist ([[secure-engineering]]).
- A deep link is exported by definition. It must not perform a
  state-changing action without the user confirming it inside the app.
- Start a component inside the app with an explicit intent. Never forward an
  intent received from another app.
- Every `PendingIntent` has `FLAG_IMMUTABLE` unless a platform feature
  requires it to be mutable, and wraps an explicit intent.
- Register a runtime receiver with `RECEIVER_NOT_EXPORTED` unless another app
  must send to it, and unregister it in the matching lifecycle callback.
- A `ContentProvider` is not exported unless it must be. Share a file with
  `FileProvider` and a per-URI grant, never a `file://` URI.

## Background work

- Deferrable work that must finish, such as a sync or an upload, is a
  `WorkManager` job with constraints. Not a service, a thread, or an alarm.
- A foreground service is only for work the user is aware of right now. It
  declares its `foregroundServiceType` and matching permission, shows its
  notification, and stops itself when done.
- Never start a background service or an activity from the background. The
  system blocks both.
- A `BroadcastReceiver.onReceive` runs on the main thread with a deadline of
  seconds. Hand off to `WorkManager`; do not start long work there.
- An exact alarm is only for something the user set a time for. Use an
  inexact one, or `WorkManager`, otherwise.
- Hold no wake lock where `WorkManager` would do, and release every one
  acquired, with a timeout.
- A worker is idempotent: the system can run it twice or stop it part way.

## Main thread

- No disk, network, or database call on the main thread. A blocked main
  thread for a few seconds is an "application not responding" kill.
- Enable `StrictMode` in debug builds where the project already does, and
  fix what it reports rather than suppressing it.

## Storage

- Private data goes in the app's internal storage. Nothing sensitive goes to
  external or shared storage, and nothing sensitive is written to the log
  ([[observability-standards]]).
- A token, key, or credential is stored encrypted with a key held in the
  Android Keystore, or not stored. Never in plain `SharedPreferences`, a
  file, or a database column.
- Use `DataStore` or the project's existing mechanism for preferences in new
  code. Never do preference or file I/O on the main thread.
- Access shared media through `MediaStore` or the Storage Access Framework.
  Never a hardcoded `/sdcard` path ([[no-hardcodes]]).
- Exclude secrets from backup with the backup rules, where the app allows
  backup.

## Network and WebView

- All traffic is HTTPS. Cleartext is never enabled in a release build, and
  the network security configuration never trusts user-installed
  certificates outside debug.
- Never disable certificate or hostname verification, in any build.
- A `WebView` loads only allowlisted origins. JavaScript is off unless the
  page needs it, file access is off, and `addJavascriptInterface` is never
  exposed to content the app does not control.

## Checklist

- [ ] Each permission requested in context, rechecked before use, and its denial handled.
- [ ] Every incoming intent, extra, and URI validated before use.
- [ ] Every `PendingIntent` immutable and explicit; receivers and providers not exported unless required.
- [ ] Deferrable work uses `WorkManager`; every foreground service declares its type and stops itself.
- [ ] No long work in a receiver; workers are idempotent.
- [ ] No disk, network, or database call on the main thread.
- [ ] Credentials encrypted with a Keystore key; nothing sensitive in shared storage or logs.
- [ ] No cleartext traffic or disabled certificate checks; WebViews restricted to known origins.
