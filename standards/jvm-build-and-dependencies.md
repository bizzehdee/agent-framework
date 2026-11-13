---
name: jvm-build-and-dependencies
description: Gradle and Maven discipline for Java, Kotlin, and Android projects - the committed wrapper as the only way to build, a declared JDK toolchain, versions in one place, exact dependency versions with no dynamic or snapshot ranges, the narrowest dependency scope, and build logic kept out of module scripts. USE FOR setting up or modifying a Gradle or Maven build, editing build.gradle, build.gradle.kts, settings.gradle, gradle.properties, libs.versions.toml, or pom.xml, adding or updating a JVM dependency or plugin, adding a module, or writing CI build steps for a JVM or Android project. DO NOT USE FOR licence and supply-chain vetting of a new dependency - see dependency-management. DO NOT USE FOR Android SDK levels, signing, and manifest settings - see android-project-files.
globs: **/build.gradle,**/build.gradle.kts,**/settings.gradle,**/settings.gradle.kts,**/gradle.properties,**/libs.versions.toml,**/pom.xml,**/gradle-wrapper.properties
stack: java,kotlin,android
---

# JVM build and dependencies

Use the build tool the repository already has
([[existing-project-conventions]]). Never add Gradle to a Maven project or
Maven to a Gradle project.

## The wrapper

- Build only through the committed wrapper: `./gradlew` or `./mvnw`. Never a
  globally installed `gradle` or `mvn`, in documentation, scripts, or CI.
- Commit the wrapper script, its properties file, and its jar. Never edit the
  jar. Change the build tool version with the wrapper task
  (`./gradlew wrapper --gradle-version X`), in its own change.
- Keep `distributionSha256Sum` where the repository sets it, and update it
  with the version.

## Toolchain

- Declare the JDK the code is built for: a Gradle Java toolchain, or
  `maven.compiler.release` in Maven. An undeclared version is whatever JDK the
  machine has.
- Use only language and library features of the declared version. Raising it
  is its own change, approved by the user.
- CI builds with the same wrapper and toolchain as a developer.

## Versions in one place

- Declare each dependency and plugin version once: the Gradle version catalog
  (`gradle/libs.versions.toml`) where the project has one, or
  `dependencyManagement` and `pluginManagement` in the Maven parent. A module
  never repeats a version literal.
- Every version is exact. No dynamic version (`1.+`, `latest.release`), no
  version range, and no `SNAPSHOT` in a committed build.
- Import a platform or BOM for a family of libraries that publishes one, and
  omit the versions it manages.
- Where the repository uses dependency locking or verification metadata,
  regenerate it in the same change as the dependency.

## Dependencies

- Use the narrowest scope. In Gradle: `implementation` by default, `api` only
  when the type appears in the module's public signatures, `compileOnly` and
  `runtimeOnly` where they apply, `testImplementation` for tests. In Maven:
  `test` and `provided` where they apply.
- Declare every dependency the code uses directly. Never rely on one that
  arrives transitively.
- Declare repositories once, in `settings.gradle` or the parent POM. Never add
  a repository to fetch one artifact without approval
  ([[dependency-management]]), and never `mavenLocal()` in a committed build.
- No credential, token, or signing password in a build file or a committed
  `gradle.properties` ([[no-hardcodes]]).

## Build logic

- Shared configuration lives in a convention plugin (`buildSrc` or an included
  build) or the Maven parent. Never copy a block between module scripts, and
  never configure other projects with `allprojects` or `subprojects`.
- A build script declares; it does not compute. No network call, file
  download, or shell command at configuration time.
- Register tasks lazily (`tasks.register`), and declare a custom task's inputs
  and outputs so it can be skipped and cached.
- Never disable a check to get a build through: no `-x test`, `-DskipTests`,
  `ignoreFailures`, or lint baseline update without approval
  ([[testing-standards]]).

## Checklist

- [ ] Every build command uses the committed wrapper.
- [ ] JDK version declared through a toolchain or release setting.
- [ ] Each version declared once and exact; no dynamic, range, or snapshot versions.
- [ ] Dependencies in the narrowest scope; nothing used transitively.
- [ ] No new repository, `mavenLocal()`, or secret in the build.
- [ ] Shared build logic in a convention plugin or parent, not copied.
- [ ] No test or check skipped to make the build pass.
