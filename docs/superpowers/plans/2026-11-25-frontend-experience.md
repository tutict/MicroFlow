# Frontend Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Improve the desktop and mobile collaboration workbench with visible navigation, usable composition, and reliable task switching.

**Architecture:** Keep the existing Riverpod repositories and window classes. Put navigation presentation into shell widgets, keep transient drafts in the workspace page keyed by user, workspace and conversation, and reuse the existing task queues.

**Tech Stack:** Flutter, Dart, Riverpod, gen-l10n, flutter_test.

**Spec:** [Frontend experience and references](../../frontend-experience.md).

## Global Constraints

- Desktop and phone have equal priority; Chinese, English, light and dark themes remain supported.
- No new package dependencies or backend contract changes.
- Touch targets are at least 44×44; check widths 320, 390, 820, 1280 and 1600 and text scale 1.8.
- Drafts belong to one workspace/conversation; failed sends preserve them; composing IME text must not be sent by a shortcut.
- Implementation was retained uncommitted until the user's 2026-11-26 follow-up authorized functional commits and push.

## Review Focus

- Task navigation must identify the selected destination when opened from either the tools list or bottom navigation.
- A channel switch and a workspace switch must never reveal another conversation's draft.
- Repeated keyboard sends must issue one request while the first request is pending.
- Small windows, English labels and large text must leave every filter and preference reachable.
- Focusing search must work after returning from a different destination without recreating the workspace state.

## Task 1: Navigation and conversation access

**Files:** workspace_home_page.dart; workspace_destination_rail.dart; new workspace_bottom_navigation.dart; workspace_panel.dart; workspace_tools_list.dart; app_en.arb/app_zh.arb; workspace_home_page_test.dart.

**Interfaces:** WorkspacePanel receives an optional search FocusNode, initial query and ValueChanged<String> callback; shell navigation continues to use ShellDestination.

- [x] Write and observe failing tests for direct phone navigation, desktop labels, task canvas width, local filtering and search focus.
- [x] Implement grouped desktop navigation, accurate phone selection, conversation filtering and Ctrl/⌘+K focus.
- [x] Group tools and preferences without changing their callbacks; remove the duplicated task header.
- [x] Run workspace regressions and render both navigation forms.

## Task 2: Message composition and draft ownership

**Files:** input_box.dart; chat_panel.dart; workspace_home_page.dart; input_box_test.dart; workspace_home_page_test.dart; localizations.

**Interfaces:** InputBox and ChatPanel receive initialDraft and onDraftChanged; ChatPanel receives optional onOpenConversations. WorkspaceHomePage owns a Map<(String, String, String), String> of transient drafts.

- [x] Write and observe failures for draft restoration/isolation, empty sends, keyboard sending, duplicate sends and narrow composer width.
- [x] Implement full-width multiline input with a separate toolbar, localized shortcut hints and on-demand mentions.
- [x] Preserve drafts on navigation and failure; reset the composer for a different conversation; guard in-flight requests and IME composition.
- [x] Run composer and workspace interaction regressions, including workspace switching.

## Task 3: Task filters and final validation

**Files:** my_work_page.dart; my_work_test.dart; frontend render evidence; docs/frontend-experience.md.

**Interfaces:** Preserve MyWorkLane, task queue providers and all existing task actions.

- [x] Write and observe a failure for selecting any lane on a 320 pixel window at 1.8 text scale.
- [x] Use a compact lane menu on small canvases, visible tabs on wide canvases and wrapping scope controls.
- [x] Run the complete frontend test suite, static analysis, a web build and git diff checks.
- [x] Inspect current render captures in both themes/languages and run a local browser smoke test.
- [x] Record four review axes: Spec, Standards, Implementation Quality, Verification & Evidence; report the exact remaining verification boundaries.

## Task 4: Connection failure recovery found during browser validation

**Evidence:** The local browser pairing flow remained on the loading scaffold. A preflight request from the preview origin returned `403 CORS Rejected - Invalid origin`; connection mutations never restore their previous catalog on failure, and SessionGate unmounts the form as soon as loading starts.

**Scope:** Recover frontend connection state and keep the pending form mounted. Configure the isolated test backend with its exact preview origin; no backend source or permission-policy changes.

- [x] Reproduce failure recovery and form disposal with controller/widget tests.
- [x] Restore connection state on failed mutations and preserve the existing form while pending.
- [x] Repeat the authorized local pairing/login and desktop/phone smoke checks; rerun frontend verification.

## Task 5: Server error envelope compatibility found in final console checks

**Evidence:** The actual browser console traced payload cast failures to RealtimeSocketEvent.fromJson. ChatWebSocketHandler sends ERROR payloads as strings, while the frontend decoder assumes every payload is a map. The client itself sends structured disconnection errors, which must continue working.

**Scope:** Normalize only the server's string ERROR payload into the existing message field; preserve object event payloads and backend authorization. No backend or protocol change.

- [x] Reproduce the string error decoder failure and protect structured errors/message payloads with wire-level tests.
- [x] Normalize the supported server error shape, rerun frontend checks and rebuild Web.
- [x] Reload the final browser app and verify console/startup results; retain any harness/device limits explicitly.
