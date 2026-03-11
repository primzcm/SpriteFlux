# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
