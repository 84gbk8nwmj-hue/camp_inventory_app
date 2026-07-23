# GEAR BASE Development Rules

This file defines the development rules for all AI coding agents
(OpenCode, Antigravity, Claude Code, Gemini CLI successors, etc.).

These rules always take priority unless the user explicitly instructs otherwise.

---

# Project Goal

GEAR BASE is a gear management application for campers.

Development priorities are:

1. Stability
2. MVP completion
3. Readability
4. Performance
5. New features

Never sacrifice stability for unnecessary improvements.

---

# MVP First

- MVP is always the highest priority.
- Implement only the requested feature.
- Do not improve unrelated code.
- Do not refactor unless explicitly requested.
- Do not redesign the UI.
- Do not introduce new architecture.

---

# Investigation Before Coding

Before making any changes:

- Read only the files related to the task.
- Search for existing implementations.
- Understand current behavior.
- Identify the minimum required changes.

Never start implementing based on assumptions.

---

# Implementation Rules

- Make the smallest possible change.
- Respect the existing code style.
- Reuse existing code whenever possible.
- Replace an entire function instead of inserting complex logic into the middle of existing control flow.
- Do not leave duplicated code after editing.
- Do not rename files without permission.
- Do not move files without permission.
- Do not add unnecessary dependencies.

---

# UI Rules

GEAR BASE targets campers who prefer a rugged, military-inspired design.

Maintain the existing design philosophy.

Do NOT:

- redesign screens
- change layouts unnecessarily
- make the app look like a generic Material sample
- replace existing UI without permission

Light themes currently allowed:

- Sakura
- Sand Beige

Dark themes should remain the default.

---

# Dependency Rules

If pubspec.yaml must be changed:

- Explain why.
- Do not upgrade packages automatically.
- Do not replace packages without permission.
- Keep existing versions whenever possible.

---

# Git Rules

Do NOT perform any of the following unless the user explicitly requests it:

- commit
- push
- create tags
- merge
- rebase
- checkout another branch
- delete branches

Always wait for user confirmation.

---

# Token Efficiency

- Read only the files required for the task.
- Read only the relevant functions or code blocks when possible.
- Do not reread files unless necessary.
- Keep the edit scope as small as possible.
- Avoid unnecessary searches.

---

# Verification

After implementation:

1. Run `flutter analyze`.
2. If Android code or Android UI changed, run `flutter build apk --release`.
3. Fix all compile and build errors.
4. Report any remaining warnings.
5. Do not report completion until verification succeeds.
6. Never claim verification succeeded unless it actually did.
7. Wait for the user's instruction before committing.

---

# Restore Rules

When restoring previous work:

- Search Git history.
- Identify the correct commit.
- Restore only the required changes.
- Do not recreate functionality from memory.
- Do not guess missing implementations.

Git history is the source of truth.

---

# Safety Rules

The following changes are prohibited unless explicitly requested:

- Large refactoring
- app_database.dart redesign
- Riverpod architecture changes
- Directory restructuring
- Database schema redesign
- Theme architecture redesign

---

# If Unsure

If requirements are unclear:

STOP.

Ask the user.

Never guess.

---

# Completion Report

At the end of every task, report:

## Files changed

- file1
- file2

## Summary

- What was implemented

## Verification

- flutter analyze result
- flutter build result (if executed)

## Remaining issues

- Any unresolved problems

---

# Known Project Notes

- MVP first.
- Stability is more important than perfection.
- Existing behavior should not change unless requested.
- Preserve the rugged camping atmosphere of the application.
- Avoid unnecessary code churn.

---

# Response Language

Always communicate with the user in Japanese.

Explain your reasoning, summaries, reports, and error messages in Japanese unless the user explicitly requests another language.

Source code, comments, commit messages, and documentation should follow the language already used in the project.

---

# Communication Style

- Always communicate with the user in Japanese.
- Be concise and practical.
- Do not use excessive apologies.
- If uncertain, ask before implementing.
- Never pretend something was verified if it was not.


## Debugging Rules

### Analyze First
- Always run `flutter analyze` (or `dart analyze`) before making any fix.
- Read the full error message before determining the cause.
- Never guess the cause of an error without verifying the analyzer output.

### One Fix Per Cycle
- Apply only one logical fix at a time.
- Follow the cycle: Analyze → Fix → Analyze.
- Do not make multiple unrelated changes in a single debugging step.

### Preserve Existing Code
- Modify only the code required to fix the reported issue.
- Never duplicate existing code when editing.
- After editing, verify that removed code was actually removed and not accidentally duplicated.

### Verify After Editing
- Re-read the edited section before continuing.
- Confirm there are no duplicated widgets, arguments, methods, or blocks.
- Ensure that edits have not introduced syntax errors or changed unrelated behavior.

### If the Error Persists
- Do not repeat the same fix multiple times.
- Re-run `flutter analyze` and base the next action on the new analyzer output.
- Explain the actual error before attempting another fix.
- If the same issue cannot be resolved after two attempts, stop making changes and report the current analyzer output instead of guessing.

### Completion Criteria
- Do not report the issue as fixed unless `flutter analyze` reports:
  ```
  No issues found!
  ```
- If any errors remain, clearly state that the fix is incomplete and provide the remaining analyzer output.

### Widget Tree Verification
- For Flutter syntax errors, trace the widget tree from the opening widget to the corresponding closing widget.
- Do not count parentheses alone. Verify which widget each closing parenthesis belongs to.
- When adding or removing `)`, explicitly identify which widget is being closed.
- Do not determine the cause of a syntax error based only on the reported line number.
- Before editing, verify the complete widget hierarchy around the reported error.
- If the widget hierarchy cannot be confidently determined, stop and report the uncertainty instead of guessing.