# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Added a `.gitignore` to keep local Xcode user state and build artifacts out of version control.
- Added dashboard drag-and-drop loading for supported asset files.
- Added a file-backed asset library stored in Application Support with copied media files and generated thumbnails.
- Added multi-companion scene support with one overlay window per active asset and persisted selection/position state.

### Changed
- Polished the dashboard with a visible loaded-file label, slider value readouts, and clearer labeled actions.
- Expanded SpriteFlux asset support from video plus GIF to include PNG, JPG/JPEG, and WEBP files.
- Applied a reviewed subset of Xcode recommended project settings for warnings, debug build speed, and release dead code stripping.
- Replaced the temporary recent-assets list with a saved library that supports load, favorite, rename, and delete actions.
- Changed the dashboard controls to operate on the selected active companion and updated the library to add companions into the scene instead of replacing a single overlay.
- Reworked the dashboard into a wider two-column layout so active companions and the library use horizontal space instead of forcing an overly tall window.

## [0.2.1] - 2026-03-23
### Added
- Dashboard `Options` action that opens an AppKit keyboard shortcuts window.
- In-app Move Mode shortcut editor with live recording and a restore-default action.
- Back button in the shortcuts view that returns to the dashboard.

### Changed
- The Move Mode global hotkey now loads from persisted settings instead of being hard-coded to Cmd + Shift + M.
- Simplified the shortcut editor copy to better match the compact dashboard style.
- Restyled the shortcut editor into a form-style layout with a recorder field and subtle reset control.
- Centered the shortcuts heading and pushed the recorder control to the trailing side for a cleaner settings layout.
- Restored the recorder label to its earlier font size after switching to symbolic shortcut rendering.
- Switched the shortcut display to macOS-style modifier symbols rendered in a monospaced label inside the recorder field.

## [0.2.0] - 2026-03-22
### Added
- AppKit dashboard window that opens from the menu bar icon and can be hidden without quitting the app.
- Dashboard status summary for the active animation plus direct controls for loading media, toggling move mode, toggling click-through, resetting position, and quitting.
- Right-click quick menu on the menu bar icon for dashboard visibility, move mode, click-through, and other overlay actions.

### Changed
- The dashboard window now opens automatically when SpriteFlux launches and stays available until the user hides it.
- **Glassmorphic Dashboard**: Restructured the dashboard to provide a floating, translucent aesthetic including a live circular thumbnail preview, direct scale and opacity sliders, and simplified actions.

## [0.1.0] - 2026-02-07
### Added
- AppKit-based overlay window that stays on top of all spaces and windows.
- AVFoundation video playback with seamless looping for MP4 and MOV files.
- GIF playback fallback using `NSImageView` animation.
- Click-through mode with a Move Mode toggle and global hotkey (Cmd + Shift + M).
- Menu bar controls for loading media, toggling modes, resetting position, and quitting.
- Persistence for window position, selected file, and interaction modes.

### Fixed
- Menu bar controller initialization order so the project builds cleanly.
- Deprecated file type API usage by switching to Uniform Type Identifiers.
- Prevented non-key overlay window warnings by avoiding makeKey behavior.
- Restored the sparkles menu bar icon with a text fallback.
- Ensured the open file panel appears by activating the app before presenting it.
- Enabled reliable drag movement by handling mouse drag events in the overlay view.
- Prevented drag ghosting by disabling window background movement during manual dragging.
- Made drag tracking follow global mouse coordinates for smooth movement.
