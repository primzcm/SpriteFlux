# SpriteFlux Agent Guide

## What This Repo Is
SpriteFlux is a native macOS menu bar overlay app that displays an animated character (video or GIF) above all windows using AppKit.

## How An AI Agent Should Contribute
- Prefer small, focused changes that compile.
- Keep AppKit window behavior in Swift; SwiftUI is only allowed for optional settings UI.
- Update docs and checklists alongside code changes.
- Validate menu bar, hotkey, click-through, and persistence behavior when you change related code.

## Rules
- Keep changes small.
- Always update docs.
- Always update `CHANGELOG.md`.
- Always update `TASK_CHECKLIST.md`.
- Ensure the app builds.
- No unfinished TODOs in code.
