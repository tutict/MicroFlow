# Dependency Upgrade Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task. Steps use checkboxes for tracking. The user's request authorizes local upgrades and compatibility repairs; retain all existing uncommitted frontend work.

**Goal:** Upgrade frontend, backend, and project build dependencies to compatible stable releases and verify the application.

**Architecture:** Migrate the frontend to the standalone Material / Cupertino libraries required by FlexColorScheme 9 and upgrade Quarkus to 4 while retaining Java 21. Resolve Dart transitives through Pub and Java transitives through the Quarkus BOM. Handle storage, localization, and picker migration explicitly.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, Java 21 target, Maven, Android Gradle Plugin.

**Spec:** User requests on 2026-11-26: “然后请帮我升级依赖”, “还能继续升级依赖吗？”, and “请继续”.

## Global Constraints

- Preserve the preceding frontend improvements and `.workbuddy/`.
- Upgrade stable releases; do not install or replace global SDKs.
- The user's 2026-11-26 follow-up authorizes functional commits and push to the current origin/main. No release, deployment, or use of the real application database.
- Stay on secure-storage 10.3.4: 11.x removes the migration path from existing 9.x storage. Pub resolution found newer 10.x fixes for migration from 9.2.4.
- Migrate app and test Material imports together; supply matching standalone localization delegates without editing the SDK generator.
- Verify the remaining stable Android versions (Gradle 9.9.2, AGP 9.5.3, Kotlin 2.4.21) using compilerOptions DSL and Flutter's AGP compatibility settings.

## Review Focus

- Existing login and connection data: enable storage migration with backup and prevent automatic data clearing on errors.
- File picking: preserve cancellation, one-file selection, and complete uploaded bytes.
- Loading screens: retain app-theme brightness after Skeletonizer 3 stops reading Material themes.
- SQLite and HTTP contracts: run the complete backend suite and package the application with Java 21.
- Reproducibility: update the Pub lockfile and Maven / Gradle wrapper checksums; document version holds and unavailable platform checks.

### Task 1: Frontend dependencies and compatibility

**Files:** `frontend/pubspec.yaml`, `frontend/pubspec.lock`, `frontend/l10n.yaml`, `frontend/lib/core/storage/local_store.dart`, `frontend/lib/features/workspace/presentation/pages/workspace_home_page.dart`, `frontend/lib/shared/widgets/app_skeletons.dart`, and regression tests for changed behavior.

**Interfaces:** Preserve `LocalStore` and workspace upload APIs; use `FilePicker.pickFile()` and `PlatformFile.readAsBytes()`.

- [x] Update file_picker to 13.4.1, flutter_riverpod to 3.5.0, flutter_secure_storage to 10.3.4, mobile_scanner to 7.5.0, shared_preferences to 2.5.6, skeletonizer to 3.0.0, and cupertino_icons to 2.0.0. Set http and intl constraints to their current stable releases; require Dart 3.13 / Flutter 3.47, matching the resolved dependencies.
- [x] Resolve and inspect the lockfile; record actual compatibility failures before fixing source.
- [x] Add meaningful migration regressions, repair picker / storage / skeleton calls, and remove the obsolete `synthetic-package` localization option.
- [x] Run the complete Flutter tests, analysis, release Web build, and the existing native rendering scenarios. Check a Wasm build now that the storage package supports it. Observed: 203 tests, clean analysis, Web / Wasm builds, and 15 rendering scenarios passed.

### Task 2: Backend and project build dependencies

**Files:** `backend/pom.xml`, `backend/.mvn/wrapper/maven-wrapper.properties`, `backend/mvnw`, `backend/mvnw.cmd`, `backend/Dockerfile`, `frontend/Dockerfile`, `frontend/android/settings.gradle.kts`, `frontend/android/app/build.gradle.kts`, `frontend/android/gradle.properties`, `frontend/android/gradle/wrapper/gradle-wrapper.properties`, and `README.md`.

**Interfaces:** Preserve Java 21, all REST / WebSocket contracts, and the SQLite schema.

- [x] Upgrade Quarkus BOM and plugin to 4.0.1, SQLite JDBC to 3.54.1.0, Spring test dependencies to 7.1.0, AssertJ to 3.27.7, Mockito to 5.24.0, ZXing to 3.5.4, compiler plugin to 3.16.0, and Surefire / Failsafe to 3.6.1. Use the current `quarkus-junit` artifact.
- [x] Upgrade the project Maven wrapper / build image to 3.10.2; use Nginx 1.30.8 Alpine. Remove the wrapper's global-Maven shortcut so the configured version is used. Retain the existing Flutter `stable` image because the installed SDK version's exact image tag does not exist.
- [x] Upgrade AGP to 9.5.3, Kotlin to 2.4.21, and Gradle to 9.9.2 with its official SHA-256 checksum; migrate the Kotlin JVM target configuration as shown by the installed Flutter template.
- [x] Verify the accounting DTO's element-level `@Valid` migration and repair the cancellation test's ineffective legacy-gateway delay with a test-only gate; retain all cancellation assertions. All four targeted backend tests passed.
- [x] Run Maven verification and packaging under the installed JDK 21. Validate wrapper versions and complete Android verification with a temporary SDK under the user's explicit license authorization. Observed: 241 backend tests and packaging passed; Android debug APK built successfully.

### Task 3: Further stable releases requested by the user

**Files:** frontend Material / Cupertino imports, `frontend/lib/l10n/app_localization_delegates.dart`, localization consumers and tests, `frontend/pubspec.yaml`, `frontend/pubspec.lock`, `backend/pom.xml`, and Android version configuration.

**Interfaces:** Retain application behavior, locales, palettes, Java 21, HTTP payloads, and existing storage key names.

- [x] Upgrade FlexColorScheme to 9.0.0, Material UI to 1.11.1, and Cupertino UI to 1.1.7. Verify a localization regression before replacing imports and using matching UI localization delegates.
- [x] Upgrade Quarkus to 4.0.1 and Spring test dependencies to 7.1.0; run the complete Java 21 suite and package the application. The Quarkus 4 runtime's observed class-file major version is 65 (Java 21).
- [x] Validate Gradle 9.9.2 / AGP 9.5.3 / Kotlin 2.4.21 with the temporary SDK. Native APK build passed; physical camera / keystore migration and iOS/macOS builds remain unverified.
- [x] Run complete frontend tests, analysis, Web / Wasm release builds, and native rendering after migration. Check direct dependencies for remaining compatible stable updates. Verify the actual Wasm application with packaged Quarkus 4: pairing/login, draft retention, message send, restored session after refresh, phone navigation, language and theme changes passed.

### Task 4: Final review and delivery

**Files:** `docs/dependency-upgrade.md`; command evidence in ignored `.codex-tmp/dependency-upgrade/`.

- [x] Review the final dependency diff, version convergence, migration choices, and preservation of the earlier changes. Independent four-axis review passed within the documented local targets; no Critical / Important findings. Record the nonblocking Quarkus / Surefire JVM-argument composition recommendation for later maintenance.
- [x] Record observed verification results, intentional version holds, and platform gaps. Restore the original Android local.properties, stop task-created services/browser, and archive generated untracked reports. Deliver a concise Chinese summary with the upgrade record and APK linked.

## Mode and Evidence

LoopPilot Lightweight, one implementation owner. Compatibility and persistent-storage risk require explicit migration review and tests, but do not require multiple implementation owners. Official Pub metadata, verified package archives, Maven Central metadata, the Android compatibility table, and Docker official-image tags are saved in ignored task scratch space.

### Task 5: Authorized functional commits and push

**Spec:** User asks whether four-axis review was performed and, if there are no blocking issues, requests commits split by function and push.

- [x] Compose Surefire's Mockito options with Quarkus's late-injected JVM options and verify the backend with Java 21. Refresh the final four-axis acceptance against the complete pending changes and current evidence. Observed: 241 tests and packaging passed; all four review axes pass, with no unresolved Critical / Important / Minor findings.
- [x] Prepare six functional boundaries using the saved pre-dependency patch and snapshots without rewriting working files. UX and UX/recovery snapshots passed 180 / 190 tests and clean analysis. The five code groups are committed with their tests; documentation is prepared as the final group. Unrelated `.workbuddy/` remains excluded.

Publication procedure: check each staged diff, commit the six functional groups, push origin/main without force, and confirm local/remote commit identity and working-tree state. Record execution outcomes in the existing ignored progress ledger and Git history, keeping the source plan independent of its own commit hash.
