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

- Read related files.
- Search for existing implementations.
- Understand current behavior.
- Identify the minimum required changes.

Never start implementing based on assumptions.

---

# Implementation Rules

- Make the smallest possible change.
- Respect the existing code style.
- Reuse existing code whenever possible.
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

# Verification

After implementation:

1. Run flutter analyze.
2. Fix compile errors.
3. Report remaining warnings if any.
4. Do not ignore build failures.

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

## Remaining issues

- Any unresolved problems

---

# Known Project Notes

- MVP first.
- Stability is more important than perfection.
- Existing behavior should not change unless requested.
- Preserve the rugged camping atmosphere of the application.
- Avoid unnecessary code churn.

# Response Language

Always communicate with the user in Japanese.

Explain your reasoning, summaries, reports, and error messages in Japanese unless the user explicitly requests another language.

Source code, comments, commit messages, and documentation should follow the language already used in the project.

# Communication Style

- Always communicate with the user in Japanese.
- Be concise and practical.
- Do not use excessive apologies.
- If uncertain, ask before implementing.
- Never pretend something was verified if it was not.