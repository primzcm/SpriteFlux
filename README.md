# SpriteFlux

SpriteFlux is a native macOS menu bar overlay app that displays a floating animated character on top of all windows. It supports looping video (MP4/MOV) and GIF playback with click-through and move modes.

## Features
- Transparent, borderless overlay window that stays on top of all windows and spaces
- MP4/MOV playback via AVFoundation with smooth looping
- GIF playback fallback
- Click-through mode so the overlay never blocks your workflow
- Move mode to drag the overlay anywhere
- Global hotkey: Cmd + Shift + M
- Menu bar controls and persistence (position, file path, modes)

## Requirements
- macOS 12.0 or later
- Xcode 15 or later

## Run In Xcode
1. Open `SpriteFlux.xcodeproj` in Xcode.
2. Select the `SpriteFlux` scheme.
3. Build and run.

The app runs as a menu bar agent (no Dock icon). Use the sparkles icon in the menu bar to control it (falls back to `SF` if symbols are unavailable).

## Hotkeys
- Toggle Move Mode: Cmd + Shift + M

## Menu Bar Options
- `Open Animation File...` Choose an MP4, MOV, or GIF from disk.
- `Toggle Move Mode` Enable dragging the overlay.
- `Toggle Click-through` Enable or disable mouse passthrough.
- `Reset Position` Move the overlay to the default center-right position.
- `Quit` Exit SpriteFlux.

## Load GIF Or Video
Use the menu bar item `Open Animation File...` and select a `.gif`, `.mp4`, or `.mov` file. The overlay will resize to fit the media and loop automatically.
